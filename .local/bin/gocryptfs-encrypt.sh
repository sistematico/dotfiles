#!/usr/bin/env bash
# Thunar Custom Action: encripta um diretório com gocryptfs (FUSE), pedindo a
# senha via rofi. Move o conteúdo do diretório selecionado pra dentro de um
# "cofre" oculto (.<nome>.gocryptfs) criado ao lado dele, e remove o
# diretório original em texto plano.
#
# Usado no lugar do fscrypt porque o kernel deste sistema não suporta
# encriptação nativa em btrfs (que é o filesystem de $HOME aqui) — gocryptfs
# roda em espaço de usuário via FUSE e funciona em cima de qualquer
# filesystem.
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
  fail "Nenhum diretório selecionado."
fi

for dir in "$@"; do
  dir=$(realpath -s -- "$dir")

  if [ ! -d "$dir" ]; then
    notify critical "'$dir' não é um diretório."
    continue
  fi

  parent=$(dirname -- "$dir")
  name=$(basename -- "$dir")
  cipherdir="$parent/.$name.gocryptfs"

  if [ -e "$cipherdir" ]; then
    notify critical "'$cipherdir' já existe — '$name' já parece estar encriptado."
    continue
  fi

  pass1=$(ask_password "Nova senha para encriptar $name")
  if [ -z "$pass1" ]; then
    continue # cancelado
  fi

  pass2=$(ask_password "Confirme a senha")
  if [ "$pass1" != "$pass2" ]; then
    notify critical "As senhas não coincidem, '$name' não foi encriptado."
    unset pass1 pass2
    continue
  fi

  passfile=$(mktemp)
  chmod 600 "$passfile"
  printf '%s\n' "$pass1" >"$passfile"
  unset pass1 pass2

  tmp_cipher="$parent/.$name.gocryptfs.tmp$$"
  mkdir -- "$tmp_cipher"

  if ! init_out=$(gocryptfs -q -init -passfile "$passfile" "$tmp_cipher" 2>&1); then
    rm -f "$passfile"
    rm -rf -- "$tmp_cipher"
    notify critical "Falha ao inicializar o vault de '$name'."
    echo "$init_out" >&2
    continue
  fi

  mountpoint_tmp=$(mktemp -d)
  if ! mount_out=$(gocryptfs -q -passfile "$passfile" "$tmp_cipher" "$mountpoint_tmp" 2>&1); then
    rm -f "$passfile"
    rm -rf -- "$tmp_cipher"
    rmdir -- "$mountpoint_tmp"
    notify critical "Falha ao montar o vault temporário de '$name'."
    echo "$mount_out" >&2
    continue
  fi
  rm -f "$passfile"

  if [ -n "$(ls -A -- "$dir" 2>/dev/null)" ]; then
    if ! cp -a -- "$dir"/. "$mountpoint_tmp"/; then
      fusermount3 -u -- "$mountpoint_tmp"
      rmdir -- "$mountpoint_tmp"
      rm -rf -- "$tmp_cipher"
      notify critical "Falha ao mover o conteúdo de '$name' pro vault. Nada foi apagado."
      continue
    fi
  fi

  fusermount3 -u -- "$mountpoint_tmp"
  rmdir -- "$mountpoint_tmp"

  rm -rf -- "$dir"
  mv -- "$tmp_cipher" "$cipherdir"

  notify normal "'$name' encriptado (dados em $(basename -- "$cipherdir"), diretório oculto)."
done
