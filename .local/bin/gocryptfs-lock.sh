#!/usr/bin/env bash
# Thunar Custom Action: bloqueia (desmonta) um cofre gocryptfs previamente
# desbloqueado. Aceita tanto a pasta montada (nome original, sem ponto)
# quanto o cofre oculto (.<nome>.gocryptfs) correspondente. Não apaga nada
# do cofre em si — só desfaz a montagem FUSE e remove a pasta-espelho
# vazia que o gocryptfs-decrypt.sh criou.
set -uo pipefail

notify() {
  notify-send -u "${1:-normal}" "gocryptfs" "$2" 2>/dev/null || true
}

rofi_msg() {
  rofi -e "$1" 2>/dev/null || true
}

fail() {
  echo "❌ $1" >&2
  notify critical "$1"
  rofi_msg "$1"
  exit 1
}

if [ "$#" -eq 0 ]; then
  fail "Nenhum item selecionado."
fi

for item in "$@"; do
  item=$(realpath -s -- "$item")
  parent=$(dirname -- "$item")
  base=$(basename -- "$item")

  case "$base" in
  .*.gocryptfs)
    name="${base#.}"
    name="${name%.gocryptfs}"
    mountdir="$parent/$name"
    ;;
  *)
    name="$base"
    mountdir="$item"
    ;;
  esac

  if ! mountpoint -q -- "$mountdir" 2>/dev/null; then
    notify normal "'$name' já está bloqueado (nada montado)."
    continue
  fi

  if ! out=$(fusermount3 -u -- "$mountdir" 2>&1); then
    notify critical "Falha ao bloquear '$name'. Feche arquivos/terminais abertos na pasta e tente de novo."
    echo "$out" >&2
    continue
  fi

  rmdir -- "$mountdir" 2>/dev/null || true
  notify normal "'$name' bloqueado."
done
