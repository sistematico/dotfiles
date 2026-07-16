#!/usr/bin/env bash
# Thunar Custom Action: move a file/folder into ~/dotfiles and replace it
# with a symlink, keeping ~/dotfiles/README.md's "Symlinks" table in sync.
set -euo pipefail

DOTFILES="$HOME/dotfiles"
README="$DOTFILES/README.md"

notify() {
  # $1=urgency (low|normal|critical) $2=title $3=body
  notify-send -u "$1" "$2" "$3" 2>/dev/null || true
}

rofi_msg() {
  rofi -e "$1"
}

rofi_confirm() {
  # $1 = prompt text, returns 0 if user picked "Sim"
  local choice
  choice=$(printf 'Sim\nNão' | rofi -dmenu -p "$1" -l 2 -no-custom)
  [ "$choice" = "Sim" ]
}

fail() {
  notify critical "Dotfile track" "$1"
  rofi_msg "$1"
  exit 1
}

if [ "$#" -eq 0 ]; then
  fail "Nenhum arquivo selecionado."
fi

# Ensure destination table section exists, insert a row if missing.
ensure_readme_row() {
  local origin_display="$1" target_display="$2"

  if [ ! -f "$README" ]; then
    printf '# Dotfiles\n\n## Symlinks\n\n| Origem | Aponta para |\n| --- | --- |\n' >"$README"
  fi

  if ! grep -q "^## Symlinks" "$README"; then
    printf '\n## Symlinks\n\n| Origem | Aponta para |\n| --- | --- |\n' >>"$README"
  fi

  # Already tracked? (match exact row)
  if grep -qF "| \`$origin_display\` | \`$target_display\` |" "$README"; then
    return 0
  fi

  # Insert the new row right after the table header, keeping the table
  # contiguous even if other content follows it later in the file.
  awk -v origin="$origin_display" -v target="$target_display" '
        BEGIN { done=0 }
        {
            print
            if (!done && $0 ~ /^\| *--- *\| *--- *\|$/) {
                print "| `" origin "` | `" target "` |"
                done=1
            }
        }
    ' "$README" >"$README.tmp" && mv "$README.tmp" "$README"
}

to_display() {
  # Convert an absolute path under $HOME to a ~-relative display string.
  case "$1" in
    "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
    *) printf '%s' "$1" ;;
  esac
}

processed=()
skipped=()
errors=()

# First pass: validate every selected item before touching anything.
declare -a items=()
for raw in "$@"; do
  item=$(realpath -s -- "$raw")
  items+=("$item")

  if [ ! -e "$item" ] && [ ! -L "$item" ]; then
    errors+=("$(to_display "$item"): não existe")
    continue
  fi

  case "$item" in
    "$HOME"/*) : ;;
    *)
      errors+=("$(to_display "$item"): fora de \$HOME, ignorado")
      ;;
  esac
done

if [ "${#items[@]}" -eq 0 ]; then
  fail "Nenhum item válido selecionado."
fi

# Build confirmation summary.
summary="Mover para ~/dotfiles e criar symlink?\n"
for item in "${items[@]}"; do
  summary+="\n$(to_display "$item")"
done

if ! rofi_confirm "$(printf '%b' "$summary")"; then
  exit 0
fi

for item in "${items[@]}"; do
  display_origin=$(to_display "$item")

  if [ ! -e "$item" ] && [ ! -L "$item" ]; then
    continue # already reported above
  fi

  rel="${item#"$HOME"/}"
  dest="$DOTFILES/$rel"
  display_dest=$(to_display "$dest")

  if [ -L "$item" ]; then
    current_target=$(readlink -f -- "$item" || true)
    resolved_dest=$(realpath -m -- "$dest")
    if [ "$current_target" = "$resolved_dest" ]; then
      skipped+=("$display_origin já é um symlink para $display_dest")
      continue
    fi
    skipped+=("$display_origin já é um symlink (para $(to_display "${current_target:-?}")), não mexido")
    continue
  fi

  if [ -e "$dest" ]; then
    skipped+=("$display_origin: já existe algo em $display_dest, resolva manualmente")
    continue
  fi

  mkdir -p -- "$(dirname -- "$dest")"
  if ! mv -n -- "$item" "$dest"; then
    errors+=("$display_origin: falha ao mover para $display_dest")
    continue
  fi

  if ! ln -s -- "$dest" "$item"; then
    errors+=("$display_origin: falha ao criar symlink (arquivo já foi movido para $display_dest!)")
    continue
  fi

  ensure_readme_row "$display_origin" "$display_dest"
  processed+=("$display_origin -> $display_dest")
done

body=""
[ "${#processed[@]}" -gt 0 ] && body+="Movidos:\n$(printf '%s\n' "${processed[@]}")\n"
[ "${#skipped[@]}" -gt 0 ] && body+="\nIgnorados:\n$(printf '%s\n' "${skipped[@]}")\n"
[ "${#errors[@]}" -gt 0 ] && body+="\nErros:\n$(printf '%s\n' "${errors[@]}")\n"

if [ -z "$body" ]; then
  body="Nada a fazer."
fi

urgency=normal
[ "${#errors[@]}" -gt 0 ] && urgency=critical

notify "$urgency" "Dotfile track" "$(printf '%b' "$body")"
# rofi_msg "$(printf '%b' "$body")"
