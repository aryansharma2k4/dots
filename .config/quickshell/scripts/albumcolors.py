#!/usr/bin/env python3
"""Extract a small palette from an MPRIS album-art URL.

Called by services/Media.qml on every track change. Prints one line of JSON:

    {"primary":"#rrggbb","secondary":"#rrggbb","glow":"#rrggbb","ok":true}

Strategy (see MediaCard.qml for how the three are used):
  1. Resolve the art to a local file. file:// is used in place; http(s) is
     fetched once into a content-addressed cache so scrubbing back and forth
     between two tracks never re-downloads.
  2. Downscale hard (64x64). We want the *impression* of the cover, not detail,
     and quantising 4k pixels is ~50x faster than quantising the original.
  3. Median-cut quantise to 8 buckets, then score each bucket by
     population * saturation * mid-bias. Population alone picks the black
     letterboxing on a lot of covers; saturation alone picks a single
     8-pixel highlight. The product picks the colour a human would name.
  4. Force the result into a usable range for a glowing border: clamp
     saturation up and lightness into [0.42, 0.72] so a near-black cover still
     produces a visible rim instead of an invisible dark smear.
"""

import colorsys
import hashlib
import json
import os
import sys
import urllib.parse
import urllib.request

CACHE = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "quickshell", "albumart",
)

FALLBACK = {"primary": "#7AA2F7", "secondary": "#BB9AF7", "glow": "#7AA2F7", "ok": False}


def resolve(url: str) -> str | None:
    """Return a local path for an art URL, downloading http(s) art if needed."""
    if url.startswith("file://"):
        return urllib.parse.unquote(urllib.parse.urlparse(url).path)
    if url.startswith("/"):
        return url
    if url.startswith(("http://", "https://")):
        os.makedirs(CACHE, exist_ok=True)
        path = os.path.join(CACHE, hashlib.sha1(url.encode()).hexdigest())
        if not os.path.exists(path) or os.path.getsize(path) == 0:
            req = urllib.request.Request(url, headers={"User-Agent": "quickshell"})
            with urllib.request.urlopen(req, timeout=6) as resp, open(path, "wb") as fh:
                fh.write(resp.read())
        return path
    return None


def score(rgb, count):
    r, g, b = (c / 255 for c in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    # Mid-bias: a bucket at l=0.5 is worth twice one at l=0.0 or l=1.0.
    mid = 1.0 - abs(l - 0.5) * 2.0
    return count * (s + 0.12) * (mid + 0.15)


def normalise(rgb, lo=0.42, hi=0.72, min_sat=0.55):
    """Push a colour into a range that reads as a glow rather than a smudge."""
    r, g, b = (c / 255 for c in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    s = max(s, min_sat)
    l = min(max(l, lo), hi)
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def main() -> int:
    if len(sys.argv) < 2 or not sys.argv[1]:
        print(json.dumps(FALLBACK))
        return 0
    try:
        from PIL import Image

        path = resolve(sys.argv[1])
        if not path or not os.path.exists(path):
            print(json.dumps(FALLBACK))
            return 0

        img = Image.open(path).convert("RGB").resize((64, 64), Image.Resampling.BILINEAR)
        quantised = img.quantize(colors=8, method=Image.Quantize.MEDIANCUT)
        palette = quantised.getpalette()
        buckets = [
            (cnt, tuple(palette[idx * 3: idx * 3 + 3]))
            for cnt, idx in quantised.getcolors(64 * 64) or []
        ]
        if not buckets:
            print(json.dumps(FALLBACK))
            return 0

        buckets.sort(key=lambda item: score(item[1], item[0]), reverse=True)
        primary = buckets[0][1]

        # Secondary: the best-scoring bucket that is not a near-duplicate of the
        # primary, so the gradient border actually has two ends.
        secondary = primary
        for _, rgb in buckets[1:]:
            if sum(abs(a - b) for a, b in zip(rgb, primary)) > 90:
                secondary = rgb
                break

        print(json.dumps({
            "primary": normalise(primary),
            "secondary": normalise(secondary),
            # The glow runs brighter and more saturated than the border ends.
            "glow": normalise(primary, lo=0.52, hi=0.78, min_sat=0.7),
            "ok": True,
        }))
    except Exception:
        print(json.dumps(FALLBACK))
    return 0


if __name__ == "__main__":
    sys.exit(main())
