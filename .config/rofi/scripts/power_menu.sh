#!/usr/bin/env bash

set -euo pipefail

lock_icon=""
suspend_icon="󰒲"
reboot_icon=""
shutdown_icon=""

choice=$(
  printf '%s\n' \
    "$lock_icon" \
    "$suspend_icon" \
    "$reboot_icon" \
    "$shutdown_icon" \
  | rofi -dmenu -i -p "" -theme-str '
    window {
      fullscreen: false;
      width: 280px;
      padding: 20px;
      location: center;
      anchor: center;
      x-offset: 0px;
      y-offset: 0px;
      border: 1px;
      border-radius: 20px;
      border-color: rgba(255, 255, 255, 0.08);
      background-color: rgba(17, 17, 27, 0.96);
    }
    mainbox {
      children: [ listview ];
    }
    listview {
      columns: 2;
      lines: 2;
      fixed-height: true;
      fixed-columns: true;
      cycle: false;
      dynamic: false;
      spacing: 12px;
      scrollbar: false;
      layout: vertical;
      padding: 0px;
    }
    element {
      orientation: vertical;
      padding: 16px;
      border-radius: 16px;
      background-color: transparent;
    }
    element selected.normal {
      background-color: rgba(212, 190, 152, 0.18);
    }
    element-text {
      horizontal-align: 0.5;
      vertical-align: 0.5;
      font: "JetBrainsMono Nerd Font 26";
    }
    inputbar {
      enabled: false;
    }
  '
)

case "${choice:-}" in
  "$lock_icon")
    hyprlock
    ;;
  "$suspend_icon")
    hyprlock &
    sleep 1
    systemctl suspend
    ;;
  "$reboot_icon")
    systemctl reboot
    ;;
  "$shutdown_icon")
    systemctl poweroff
    ;;
esac
