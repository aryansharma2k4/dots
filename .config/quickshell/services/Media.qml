pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// MPRIS, plus the album-art colour extraction that drives the media card's
// border and glow.
Item {
    id: root

    // Prefer whatever is actually playing; fall back to the first player so a
    // paused Spotify still fills the pill.
    readonly property var player: {
        const list = Mpris.players?.values ?? []
        return list.find(p => p.isPlaying) ?? list[0] ?? null
    }

    readonly property bool available: player !== null
    readonly property bool playing: player?.isPlaying === true
    readonly property string title: player?.trackTitle || ""
    readonly property string artist: player?.trackArtist || ""
    readonly property string album: player?.trackAlbum || ""
    readonly property string artUrl: player?.trackArtUrl || ""
    readonly property string identity: player?.identity || ""

    readonly property bool canGoNext: player?.canGoNext === true
    readonly property bool canGoPrevious: player?.canGoPrevious === true
    readonly property bool canSeek: player?.canSeek === true && player?.lengthSupported === true

    readonly property real length: player?.lengthSupported ? (player.length ?? 0) : 0
    property real position: 0

    function play() { if (player?.canTogglePlaying) player.togglePlaying() }
    function next() { if (canGoNext) player.next() }
    function previous() { if (canGoPrevious) player.previous() }

    function seek(seconds) {
        if (!canSeek) return
        const target = Math.min(root.length, Math.max(0, seconds))
        player.position = target
        root.position = target
    }

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0) seconds = 0
        const total = Math.floor(seconds)
        return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0")
    }

    // Position ticks locally at 1Hz and is resynced from the player when it is
    // playing; polling DBus at animation rate would be wasteful.
    Timer {
        interval: 1000
        running: root.available
        repeat: true
        onTriggered: {
            if (!root.player) return
            if (root.player.positionSupported)
                root.position = root.player.position ?? 0
            else if (root.playing)
                root.position += 1
        }
    }

    Connections {
        target: root.player ?? null
        ignoreUnknownSignals: true
        function onPostTrackChanged() { root.position = 0 }
    }

    // ------------------------------------------------------- album colours --
    // Three colours per cover, extracted out-of-process by scripts/albumcolors.py
    // (median-cut quantise + saturation/mid-lightness scoring — the comments in
    // that file explain the scoring). The two gradient ends and a brighter glow.
    //
    // The extraction is async and can take a moment for remote art, so the
    // colours are plain (non-readonly) properties that the card animates toward
    // with a Behavior — the transition is a crossfade, never a snap.
    property color primary: "#7AA2F7"
    property color secondary: "#BB9AF7"
    property color glow: "#7AA2F7"
    property bool colorsResolved: false

    onArtUrlChanged: colorDebounce.restart()

    // Track changes often update artUrl twice in quick succession (metadata
    // arrives in pieces); wait for it to settle before spawning python.
    Timer {
        id: colorDebounce
        interval: 120
        onTriggered: {
            if (root.artUrl === "") {
                root.colorsResolved = false
                root.primary = "#7AA2F7"
                root.secondary = "#BB9AF7"
                root.glow = "#7AA2F7"
                return
            }
            colorProc.running = false
            colorProc.command = ["python3", root.scriptPath, root.artUrl]
            colorProc.running = true
        }
    }

    readonly property string scriptPath:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
        + "/quickshell/scripts/albumcolors.py"

    Process {
        id: colorProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(this.text.trim())
                    root.primary = c.primary
                    root.secondary = c.secondary
                    root.glow = c.glow
                    root.colorsResolved = c.ok === true
                } catch (e) {
                    root.colorsResolved = false
                }
            }
        }
    }

    // ------------------------------------------------------ level animation --
    // Real per-sink levels are not exposed by PipeWire's Quickshell binding, so
    // the waveform runs a plausible idle animation instead: four phase-offset
    // sine sums that never repeat visibly.
    //
    // ── WHY THIS IS GATED ──────────────────────────────────────────────────
    //
    // Left running whenever something plays, this one timer cost ~90% of the
    // shell's entire CPU: 14Hz of level changes, each smoothed by a 140ms
    // Behavior, means the media island repaints at full framerate forever — and
    // because its layer surface carries a backdrop-blur layerrule, every one of
    // those frames also makes the compositor re-blur it. Measured: 10% of a
    // core with it running, 1% with it stopped, for an animation that is not
    // reading anything real.
    //
    // It therefore runs whenever something is actually playing, and stops dead
    // when nothing is — a meter that holds still while music plays does not
    // read as thrifty, it reads as broken, which is the one thing a level
    // meter must never do.
    //
    // What `meterWanted` buys is the *rate*, not the running: 70ms while
    // something is being looked at closely (the hovered pill, the media card,
    // the seconds after a track change), 120ms otherwise. The bars are 3px
    // wide and 17px tall, so 8Hz costs no visible smoothness at a glance,
    // and it is the frame count that costs, not the arithmetic.
    property real levelPhase: 0
    property var levels: [0.3, 0.6, 0.45, 0.75]

    // Raised by whatever is showing a meter close up — see the HoverHandler in
    // MediaIsland and the media card in ControlCenter. It selects the fast
    // tick below; it no longer decides whether the meter moves at all.
    property bool meterWanted: false

    // The flourish on a track change. Keyed to the title rather than to
    // `playing`, so scrubbing or pausing does not retrigger it.
    onTitleChanged: flourish.restart()

    Timer {
        id: flourish
        interval: 4000
    }

    Timer {
        interval: (root.meterWanted || flourish.running) ? 70 : 120
        running: root.playing
        repeat: true
        onTriggered: {
            root.levelPhase += 0.35
            const p = root.levelPhase
            root.levels = [
                0.45 + 0.4 * Math.sin(p),
                0.45 + 0.4 * Math.sin(p * 1.7 + 1.1),
                0.45 + 0.4 * Math.sin(p * 1.3 + 2.3),
                0.45 + 0.4 * Math.sin(p * 2.1 + 0.4)
            ]
        }
    }

    // Settle to a low flat line when paused rather than freezing mid-spike.
    onPlayingChanged: if (!playing) levels = [0.18, 0.22, 0.2, 0.16]
}
