#!/usr/bin/env bash
# Thunar Custom Action: remove PERMANENTEMENTE a encriptação de um cofre
# gocryptfs. Copia o conteúdo do cofre pra uma pasta de verdade em texto
# plano, confere a cópia (diff -r) e só então apaga o cofre cifrado
# .<nome>.gocryptfs. Se qualquer etapa falhar, nada é apagado.
#
# Ação destrutiva e irreversível — pede confirmação explícita antes de
# apagar o cofre.
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
  fail "gocryptfs não está instalado."
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
    ;;
  *)
    name="$base"
    cipherdir="$parent/.$base.gocryptfs"
    ;;
  esac

  if [ ! -d "$cipherdir" ]; then
    notify critical "Não encontrei o cofre '$(basename -- "$cipherdir")' pra '$name'."
    continue
  fi

  destdir="$parent/$name"
  if [ -e "$destdir" ]; then
    notify critical "'$destdir' já existe — mova/renomeie antes de remover a encriptação de '$name'."
    continue
  fi

  if mountpoint -q -- "$destdir" 2>/dev/null; then
    notify critical "'$name' está desbloqueado agora — bloqueie primeiro antes de remover a encriptação."
    continue
  fi

  if ! zenity --question --title="gocryptfs" --text="Isso vai descriptografar '$name' de forma PERMANENTE:\n\n1. Copia todo o conteúdo pra '$destdir' em texto plano\n2. Confere se a cópia bateu certinho\n3. Apaga o cofre cifrado '$(basename -- "$cipherdir")' pra sempre\n\nOs dados deixarão de estar protegidos por senha. Continuar?" 2>/dev/null; then
    continue
  fi

  pass=$(ask_password "Senha do cofre $name")
  if [ -z "$pass" ]; then
    continue # cancelado
  fi

  passfile=$(mktemp)
  chmod 600 "$passfile"
  printf '%s\n' "$pass" >"$passfile"
  unset pass

  tmp_mount=$(mktemp -d)
  if ! mount_out=$(gocryptfs -q -passfile "$passfile" "$cipherdir" "$tmp_mount" 2>&1); then
    rm -f "$passfile"
    rmdir -- "$tmp_mount"
    notify critical "Falha ao montar '$name'. Senha errada?"
    echo "$mount_out" >&2
    continue
  fi
  rm -f "$passfile"

  mkdir -- "$destdir"
  if [ -n "$(ls -A -- "$tmp_mount" 2>/dev/null)" ]; then
    if ! cp -a -- "$tmp_mount"/. "$destdir"/; then
      fusermount3 -u -- "$tmp_mount"
      rmdir -- "$tmp_mount"
      rm -rf -- "$destdir"
      notify critical "Falha ao copiar '$name' pra fora do cofre. Nada foi apagado."
      continue
    fi
  fi

  diff_log=$(mktemp)
  if ! diff -rq -- "$tmp_mount" "$destdir" >"$diff_log" 2>&1; then
    fusermount3 -u -- "$tmp_mount"
    rmdir -- "$tmp_mount"
    rm -rf -- "$destdir"
    notify critical "A cópia de '$name' não bateu com o original — o cofre NÃO foi apagado. Detalhes em $diff_log"
    continue
  fi
  rm -f "$diff_log"

  fusermount3 -u -- "$tmp_mount"
  rmdir -- "$tmp_mount"

  rm -rf -- "$cipherdir"
  notify normal "'$name' descriptografado permanentemente em '$destdir'. Cofre removido."
done
