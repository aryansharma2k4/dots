#!/usr/bin/env bash

set -euo pipefail

panel="${1:-}"
instance="controlbar"
app_file="/home/aryan/.config/ags/app.ts"
log_file="/tmp/ags-controlbar.log"

if [[ -z "$panel" ]]; then
  echo "usage: $0 <panel-name>" >&2
  exit 1
fi

if ! ags request toggle "$panel" -i "$instance" >/dev/null 2>&1; then
  nohup ags run "$app_file" >"$log_file" 2>&1 &

  for _ in {1..20}; do
    sleep 0.15
    if ags request toggle "$panel" -i "$instance" >/dev/null 2>&1; then
      exit 0
    fi
  done

  echo "failed to start AGS instance '$instance' for panel '$panel'" >&2
  exit 1
fi
