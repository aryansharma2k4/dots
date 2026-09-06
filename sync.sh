#!/usr/bin/env bash
# Commit and push whatever changed in the dotfiles.
# Usage: ./sync.sh [commit message]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
git add -A
git diff --cached --quiet && { echo "Nothing to sync."; exit 0; }
git commit -m "${*:-chore: sync dotfiles $(date +%Y-%m-%d)}"
git push
