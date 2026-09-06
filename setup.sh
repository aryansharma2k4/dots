#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

managed=(
  btop
  dunst
  fastfetch
  fish
  fuzzel
  hypr
  kitty
  mako
  micro
  nvim
  quickshell
  scripts
  starship
  vicinae
  zed
)

HOME_FILES=(
  .bash_profile
  .bashrc
  .tmux.conf
  .zshrc
)

mkdir -p "$CONFIG_DIR"
backup_created=0

backup_path() {
  local target="$1"
  if [ $backup_created -eq 0 ]; then
    mkdir -p "$BACKUP_DIR"
    backup_created=1
  fi
  mv "$target" "$BACKUP_DIR/"
}

link() {
  local src="$1" dst="$2"

  if [ ! -e "$src" ]; then
    echo "Skipping missing source: $src"
    return
  fi

  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    backup_path "$dst"
  fi

  ln -s "$src" "$dst"
  echo "Linked $dst -> $src"
}

for item in "${managed[@]}"; do
  link "$REPO_DIR/.config/$item" "$CONFIG_DIR/$item"
done

for file in "${HOME_FILES[@]}"; do
  link "$REPO_DIR/$file" "$HOME/$file"
done

# Materialise the theme symlinks that are gitignored.
if [ -x "$REPO_DIR/.config/scripts/theme-mode.sh" ]; then
  mode="$(cat "$CONFIG_DIR/quickshell/theme-mode" 2>/dev/null || echo dark)"
  "$REPO_DIR/.config/scripts/theme-mode.sh" "$mode" || true
fi

if [ $backup_created -eq 1 ]; then
  echo "Backed up replaced files to $BACKUP_DIR"
fi
