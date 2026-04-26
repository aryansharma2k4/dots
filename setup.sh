#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BIN_DIR="$HOME/.local/bin"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
HOME_FILES=(
  .zshrc
)

managed=(
  ags
  btop
  cava
  fastfetch
  fish
  hypr
  hyprpaper
  kitty
  nvim
  quickshell
  rofi
  swaync
  waybar
  waypaper
  yazi
)

mkdir -p "$CONFIG_DIR" "$BIN_DIR"
backup_created=0

backup_path() {
  local target="$1"
  if [ $backup_created -eq 0 ]; then
    mkdir -p "$BACKUP_DIR"
    backup_created=1
  fi
  mv "$target" "$BACKUP_DIR/"
}

for item in "${managed[@]}"; do
  src="$REPO_DIR/.config/$item"
  dst="$CONFIG_DIR/$item"

  if [ ! -e "$src" ]; then
    echo "Skipping missing source: $src"
    continue
  fi

  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    backup_path "$dst"
  fi

  ln -s "$src" "$dst"
  echo "Linked $dst -> $src"
done

if [ -d "$REPO_DIR/.local/bin" ]; then
  find "$REPO_DIR/.local/bin" -maxdepth 1 -type f ! -name '.gitkeep' | while read -r file; do
    name="$(basename "$file")"
    dst="$BIN_DIR/$name"

    if [ -L "$dst" ]; then
      rm "$dst"
    elif [ -e "$dst" ]; then
      backup_path "$dst"
    fi

    ln -s "$file" "$dst"
    echo "Linked $dst -> $file"
  done
fi

for file in "${HOME_FILES[@]}"; do
  src="$REPO_DIR/$file"
  dst="$HOME/$file"

  if [ ! -e "$src" ]; then
    continue
  fi

  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    backup_path "$dst"
  fi

  ln -s "$src" "$dst"
  echo "Linked $dst -> $src"
done

if [ $backup_created -eq 1 ]; then
  echo "Backed up replaced files to $BACKUP_DIR"
fi
