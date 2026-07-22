#!/usr/bin/env bash
# Thunar Custom Action: desbloqueia (monta) um diretório encriptado com
# gocryptfs, pedindo a senha via rofi. Aceita tanto selecionar o cofre
# oculto (.<nome>.gocryptfs) quanto o próprio nome original.
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

ask_password() {
  rofi -dmenu -password -p "$1" -lines 0 2>/dev/null
}

if ! command -v gocryptfs >/dev/null 2>&1; then
  fail "gocryptfs não está instalado. Instale com: sudo pacman -S gocryptfs"
fi

if [ "$#" -eq 0 ]; then
  fail "Nenhum item selecionado."
fi

for item in "$@"; do
  item=$(realpath -s -- "$item")
  parent=$(dirname -- "$item")
  base=$(basename -- "$item")

  case "$base" in
  .*.gocryptfs)
    cipherdir="$item"
    name="${base#.}"
    name="${name%.gocryptfs}"
    mountdir="$parent/$name"
    ;;
  *)
    name="$base"
    cipherdir="$parent/.$base.gocryptfs"
    mountdir="$item"
    ;;
  esac

  if [ ! -d "$cipherdir" ]; then
    notify critical "Não encontrei um vault gocryptfs pra '$name' (esperava '$(basename -- "$cipherdir")')."
    continue
  fi

  if mountpoint -q -- "$mountdir" 2>/dev/null; then
    notify normal "'$name' já está desbloqueado."
    continue
  fi

  mkdir -p -- "$mountdir"

  if [ -n "$(ls -A -- "$mountdir" 2>/dev/null)" ]; then
    notify critical "'$mountdir' já existe e não está vazio — mova/renomeie antes de desbloquear '$name'."
    continue
  fi

  pass=$(ask_password "Senha para desbloquear $name")
  if [ -z "$pass" ]; then
    continue # cancelado
  fi

  passfile=$(mktemp)
  chmod 600 "$passfile"
  printf '%s\n' "$pass" >"$passfile"
  unset pass

  out=$(gocryptfs -passfile "$passfile" "$cipherdir" "$mountdir" 2>&1)
  rc=$?
  rm -f "$passfile"

  if [ "$rc" -eq 0 ]; then
    notify normal "'$name' desbloqueado em $mountdir"
  else
    notify critical "Falha ao desbloquear '$name'. Senha errada?"
    echo "$out" >&2
  fi
done
