#!/usr/bin/env bash
#
# clip-history.sh — histórico de área de transferência usando wl-clipboard + rofi
#
# Uso:
#   clip-history.sh watch   # roda em segundo plano, gravando o clipboard sempre que muda
#   clip-history.sh menu    # abre o rofi para selecionar uma entrada e recolocá-la no clipboard
#   clip-history.sh clear   # limpa todo o histórico

set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/clip-history"
HIST_FILE="$CACHE_DIR/history"     # uma entrada em base64 por linha (mais recente no topo)
MAX_ENTRIES=200

mkdir -p "$CACHE_DIR"
touch "$HIST_FILE"

die() { echo "clip-history: $*" >&2; exit 1; }

require() { command -v "$1" >/dev/null 2>&1 || die "comando necessário não encontrado: $1"; }

cmd_watch() {
    require wl-paste
    # wl-paste -w executa o comando a cada mudança do clipboard
    exec wl-paste --watch "$0" _on-change
}

cmd_on_change() {
    require wl-paste

    # só guarda texto; ignora clipboard vazio ou binário/imagem
    local mime
    mime="$(wl-paste --list-types 2>/dev/null | head -n1 || true)"
    case "$mime" in
        text/*|"") ;;
        *) exit 0 ;;
    esac

    local content
    content="$(wl-paste --no-newline 2>/dev/null || true)"
    [ -z "$content" ] && exit 0

    local encoded
    encoded="$(printf '%s' "$content" | base64 -w0)"

    # remove duplicata existente e insere no topo
    local tmp
    tmp="$(mktemp)"
    { printf '%s\n' "$encoded"; grep -Fxv "$encoded" "$HIST_FILE" 2>/dev/null || true; } \
        | head -n "$MAX_ENTRIES" > "$tmp"
    mv "$tmp" "$HIST_FILE"
}

cmd_menu() {
    require rofi
    require wl-copy

    [ -s "$HIST_FILE" ] || die "histórico vazio"

    local display line_idx exit_code encoded_line

    # cada linha exibida corresponde, por posição, à mesma linha em $HIST_FILE
    display="$(while IFS= read -r enc; do
        [ -z "$enc" ] && continue
        dec="$(printf '%s' "$enc" | base64 -d 2>/dev/null | tr '\n' ' ')"
        printf '%.200s\n' "$dec"
    done < "$HIST_FILE")"

    set +e
    line_idx="$(printf '%s\n' "$display" \
        | rofi -dmenu -i -p "Clipboard" -format i \
               -kb-custom-1 "Ctrl+x" \
               -mesg "Enter: copiar   |   Ctrl+x: limpar histórico")"
    exit_code=$?
    set -e

    if [ "$exit_code" -eq 10 ]; then
        cmd_clear
        exit 0
    fi

    [ -z "${line_idx:-}" ] && exit 0

    encoded_line="$(sed -n "$((line_idx + 1))p" "$HIST_FILE")"
    [ -z "$encoded_line" ] && exit 0

    # grava no clipboard normal (Ctrl+V) e também na seleção primária (clique do meio),
    # pois o rofi roda via XWayland e pode ter setado a primária sozinho com o texto
    # truncado da lista — sobrescrevemos as duas explicitamente com o conteúdo real.
    local content
    content="$(printf '%s' "$encoded_line" | base64 -d)"
    printf '%s' "$content" | wl-copy
    printf '%s' "$content" | wl-copy --primary
}

cmd_clear() {
    : > "$HIST_FILE"
    command -v notify-send >/dev/null 2>&1 && notify-send "Clipboard" "Histórico limpo"
}

case "${1:-}" in
    watch)       cmd_watch ;;
    _on-change)  cmd_on_change ;;
    menu)        cmd_menu ;;
    clear)       cmd_clear ;;
    *)
        cat <<EOF
Uso: $(basename "$0") {watch|menu|clear}

  watch   inicia o monitoramento do clipboard (rode em background, ex: no autostart)
  menu    abre o rofi para escolher uma entrada do histórico e copiá-la
  clear   apaga todo o histórico salvo
EOF
        exit 1
        ;;
esac
