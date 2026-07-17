#!/usr/bin/env bash
# Mostra as entradas do `pass` num menu do rofi e copia a senha escolhida
# para a área de transferência (some sozinha depois de 45s, como `pass -c`).
# Também permite gerar uma senha nova via `pass generate`.
set -euo pipefail

STORE="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
THEME="$HOME/.config/rofi/tokyonight.rasi"
GENERATE_LABEL="» Gerar nova senha"
DEFAULT_LENGTH=20

notify() {
  notify-send -u "$1" "pass" "$2" 2>/dev/null || true
}

rofi_dmenu() {
  # $1 = prompt; lê as opções do stdin
  local args=(-dmenu -i -p "$1")
  [ -f "$THEME" ] && args+=(-theme "$THEME")
  rofi "${args[@]}"
}

if [ ! -d "$STORE" ]; then
  notify critical "Cofre não encontrado em $STORE"
  exit 1
fi

mapfile -t entries < <(
  find "$STORE" -type f -name '*.gpg' \
    | sed -e "s#^$STORE/##" -e 's#\.gpg$##' \
    | sort
)

selection=$(printf '%s\n%s\n' "$GENERATE_LABEL" "$(printf '%s\n' "${entries[@]}")" | rofi_dmenu "pass")
[ -n "$selection" ] || exit 0

if [ "$selection" = "$GENERATE_LABEL" ]; then
  name=$(rofi_dmenu "Nome da entrada" </dev/null)
  [ -n "$name" ] || exit 0

  length=$(rofi_dmenu "Tamanho [$DEFAULT_LENGTH]" </dev/null)
  length="${length:-$DEFAULT_LENGTH}"
  if ! [[ "$length" =~ ^[0-9]+$ ]]; then
    notify critical "Tamanho inválido: '$length'."
    exit 1
  fi

  gen_args=(-c "$name" "$length")
  if pass show "$name" >/dev/null 2>&1; then
    choice=$(printf 'Sim\nNão' | rofi_dmenu "Sobrescrever '$name'?")
    [ "$choice" = "Sim" ] || exit 0
    gen_args=(-f "${gen_args[@]}")
  fi

  if ! pass generate "${gen_args[@]}" >/dev/null 2>&1; then
    notify critical "Falha ao gerar senha para '$name'."
    exit 1
  fi

  notify normal "'$name' gerada e copiada (limpa em 45s)."
  exit 0
fi

if [ "${#entries[@]}" -eq 0 ]; then
  notify normal "Nenhuma senha cadastrada."
  exit 0
fi

if ! pass show -c "$selection" >/dev/null 2>&1; then
  notify critical "Falha ao descriptografar '$selection'."
  exit 1
fi

notify normal "'$selection' copiada (limpa em 45s)."
