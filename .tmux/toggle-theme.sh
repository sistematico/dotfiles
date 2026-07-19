#!/usr/bin/env bash
# Alterna entre os temas do tmux (tokyonight <-> gruvbox)
state_file="$HOME/.tmux/theme"
mkdir -p "$(dirname "$state_file")"

current="tokyonight"
[ -f "$state_file" ] && current="$(cat "$state_file")"

if [ "$current" = "tokyonight" ]; then
  next="gruvbox"
else
  next="tokyonight"
fi

echo "$next" > "$state_file"
tmux source-file "$HOME/.tmux.conf"
tmux display-message " Tema: $next"
