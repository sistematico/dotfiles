#!/usr/bin/env bash

mkdir -p "$HOME/Pictures"

dateTime=$(date +%m-%d-%Y-%H:%M:%S)
file="$HOME/Pictures/screenshot-$dateTime.png"

grim "$file" && \
  wl-copy < "$file" && \
  notify-send -h string:grim:screenshot -t 2000 "Screenshot saved" "$file"
