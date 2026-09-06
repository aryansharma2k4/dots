#!/bin/bash

# @note prints a nerd-font battery glyph + percentage for hyprlock/quickshell

set -euo pipefail

BAT="/sys/class/power_supply/BAT0"

if [ ! -d "$BAT" ]; then
    exit 0
fi

capacity="$(cat "$BAT/capacity" 2>/dev/null || echo 0)"
status="$(cat "$BAT/status" 2>/dev/null || echo Unknown)"

if [ "$status" = "Charging" ]; then
    icon="󰂄"
elif [ "$capacity" -ge 90 ]; then
    icon="󰁹"
elif [ "$capacity" -ge 70 ]; then
    icon="󰂀"
elif [ "$capacity" -ge 50 ]; then
    icon="󰁾"
elif [ "$capacity" -ge 30 ]; then
    icon="󰁼"
elif [ "$capacity" -ge 15 ]; then
    icon="󰁺"
else
    icon="󰂎"
fi

printf '%s %s%%\n' "$icon" "$capacity"
