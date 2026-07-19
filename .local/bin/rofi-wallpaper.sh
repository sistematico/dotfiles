#!/usr/bin/env bash
# Menu do rofi para escolher e trocar o papel de parede (com preview).
# A escolha é aplicada na hora (mata/relança o swaybg) e salva em
# ~/.config/mango/wallpaper/current, que o wallpaper.sh lê no exec-once
# do mango — ou seja, a troca é permanente entre reinícios.
set -euo pipefail

WALLPAPER_DIRS=(
  "$HOME/images/unsplash" 
  "$HOME/.config/mango/wallpaper"
  "$HOME/images/gruvbox"
  "$HOME/images/frenzyexists"
  "$HOME/images/angeljumbo"
)
STATE_FILE="$HOME/.config/mango/wallpaper/current"
LAST_INDEX_FILE="$HOME/.config/mango/wallpaper/last_index"
THEME="$HOME/.config/rofi/gruvbox-dark.rasi"

notify() {
  notify-send -i $HOME/.local/share/icons/Newaita-reborn/apps/48/org.gnome.eog.svg -u "$1" "Wallpaper" "$2" 2>/dev/null || true
}

mapfile -t files < <(
  find "${WALLPAPER_DIRS[@]}" -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null |
    sort
)

if [ "${#files[@]}" -eq 0 ]; then
  notify critical "Nenhum papel de parede encontrado."
  exit 1
fi

entries=""
for f in "${files[@]}"; do
  name="$(basename "$f")"
  entries+="${name}\x00icon\x1f${f}\n"
done

# Overrides só deste menu (grade com thumbnails maiores, sem nome do
# arquivo). Aplicado por cima do tema compartilhado via -theme-str, sem
# tocar nos arquivos .rasi usados pelos outros menus do rofi.
GRID_OVERRIDE='
window { height: 60%; }
listview { columns: 3; spacing: 10px; }
element { orientation: vertical; }
element-icon { size: 200px; }
element-text { enabled: false; }
'

rofi_args=(-dmenu -i -p "Wallpaper" -show-icons)
[ -f "$THEME" ] && rofi_args+=(-theme "$THEME")
rofi_args+=(-theme-str "$GRID_OVERRIDE")

# Reabre na última posição visitada (rolagem/página), salva em LAST_INDEX_FILE.
if [ -f "$LAST_INDEX_FILE" ]; then
  last_index="$(<"$LAST_INDEX_FILE")"
  if [[ "$last_index" =~ ^[0-9]+$ ]] && [ "$last_index" -lt "${#files[@]}" ]; then
    rofi_args+=(-selected-row "$last_index")
  fi
fi

selection="$(printf '%b' "$entries" | rofi "${rofi_args[@]}")"
[ -n "$selection" ] || exit 0

chosen=""
index=0
for f in "${files[@]}"; do
  if [ "$(basename "$f")" = "$selection" ]; then
    chosen="$f"
    break
  fi
  index=$((index + 1))
done

[ -n "$chosen" ] || exit 0

pkill -x swaybg 2>/dev/null || true
setsid -f swaybg -i "$chosen" -m fill >/dev/null 2>&1

mkdir -p "$(dirname "$STATE_FILE")"
printf '%s\n' "$chosen" >"$STATE_FILE"
printf '%s\n' "$index" >"$LAST_INDEX_FILE"

notify normal "Papel de parede alterado para '$selection'."
