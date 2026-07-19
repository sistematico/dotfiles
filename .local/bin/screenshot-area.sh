#!/usr/bin/env bash

mkdir -p "$HOME/images"

dateTime=$(date +%m-%d-%Y-%H:%M:%S)
file="$HOME/images/screenshot-$dateTime.png"

geometry=$(slurp) || exit 0

grim -g "$geometry" "$file" && \
  wl-copy < "$file" && \
  notify-send -h string:grim:screenshot -t 2000 "Screenshot saved" "$file"
