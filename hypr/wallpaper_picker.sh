#!/bin/bash

# Define where your wallpapers are stored
WALL_DIR="$HOME/Pictures/Wallpapers"

# Use rofi to select a file from the directory
SELECTED=$(ls "$WALL_DIR" | grep -E '\.(jpg|jpeg|png)$' | rofi -dmenu -i -p "Wallpaper")

# If you actually selected something (didn't just hit escape)
if [ -n "$SELECTED" ]; then
    # Create a hidden link to the chosen wallpaper so Hyprland remembers it
    ln -sf "$WALL_DIR/$SELECTED" "$HOME/Pictures/.current_wallpaper"

    # Kill the old background and apply the new one instantly
    killall swaybg
    swaybg -i "$HOME/Pictures/.current_wallpaper" -m fill &
fi
