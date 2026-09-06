#!/bin/bash
set -euo pipefail

# Color picker: click a point on screen, get the HEX color, copy to clipboard.
# Uses grim + slurp + imagemagick (convert) + wl-copy.

# Use slurp to get a single pixel region under the cursor (1x1 area).
# slurp with -r 1 gives a 1x1 selection at the clicked point.
REGION=$(slurp -r 1 -f "%x %y %w %h" 2>/dev/null)

if [ -z "$REGION" ]; then
    # User cancelled
    exit 0
fi

# Parse region: "x y w h"
read -r X Y W H <<< "$REGION"

# Capture that exact pixel with grim
TMPIMG=$(mktemp --suffix=.png)
grim -g "${W}x${H}+${X}+${Y}" "$TMPIMG"

# Extract the hex color from the image using python + PIL
COLOR=$(python3 -c "
from PIL import Image
img = Image.open('$TMPIMG').convert('RGB')
r, g, b = img.getpixel((0, 0))
print('#{:02X}{:02X}{:02X}'.format(r, g, b))
")

rm -f "$TMPIMG"

# Copy to clipboard (both CLIPBOARD and PRIMARY)
echo -n "$COLOR" | wl-copy --type text/plain
echo -n "$COLOR" | wl-copy --primary --type text/plain

# Notify
notify-send --app-name="Color Picker" --urgency=low "$COLOR" "Copied to clipboard" --expire-time=2000
