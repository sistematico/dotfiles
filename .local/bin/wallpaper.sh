#!/usr/bin/env bash
# Aplica o papel de parede salvo (usado no exec-once do mango).
set -euo pipefail

STATE_FILE="$HOME/.config/mango/wallpaper/current"
DEFAULT_WALLPAPER="$HOME/images/unsplash/vasilina-sirotina-fJQMGqFzgEU-unsplash.jpg"

wallpaper="$DEFAULT_WALLPAPER"
if [ -f "$STATE_FILE" ]; then
  saved="$(cat "$STATE_FILE")"
  [ -f "$saved" ] && wallpaper="$saved"
fi

exec swaybg -i "$wallpaper" -m fill
