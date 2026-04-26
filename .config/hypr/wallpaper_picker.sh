#!/bin/bash

set -euo pipefail

WALL_DIR="${WALL_DIR:-$HOME/Pictures/Wallpapers}"

if [ ! -d "$WALL_DIR" ]; then
    rofi -e "Wallpaper folder not found: $WALL_DIR"
    exit 1
fi

mapfile -d '' wallpapers < <(
    find "$WALL_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        -print0 | sort -z
)

if [ "${#wallpapers[@]}" -eq 0 ]; then
    rofi -e "No wallpapers found in $WALL_DIR"
    exit 1
fi

choices=()
for wallpaper in "${wallpapers[@]}"; do
    choices+=("$(basename "$wallpaper")")
done

selected_index="$(
    for i in "${!wallpapers[@]}"; do
        # Feed rofi an icon for each row so it can render the actual wallpaper.
        printf '%s\0icon\x1f%s\n' "${choices[$i]}" "${wallpapers[$i]}"
    done |
        rofi -dmenu -i -p "Wallpaper" -format i -show-icons \
            -theme-str 'listview { columns: 3; lines: 2; spacing: 18px; scrollbar: false; }' \
            -theme-str 'element { orientation: vertical; children: [ element-icon ]; padding: 8px; }' \
            -theme-str 'element-icon { size: 14em; border-radius: 10px; }' \
            -theme-str 'element-text { enabled: false; }' \
            -theme-str 'window { padding: 8% 6%; }'
)"

if [ -z "$selected_index" ]; then
    exit 0
fi

selected_wallpaper="${wallpapers[$selected_index]}"
waypaper --wallpaper "$selected_wallpaper"
