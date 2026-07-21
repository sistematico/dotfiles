#!/usr/bin/env bash
# Thunar Custom Action: desbloqueia (unlock) um diretório encriptado com fscrypt,
# tornando o conteúdo legível na sessão atual até o "lock" ou o logout/reboot.
set -euo pipefail

notify() {
  notify-send -u "${1:-normal}" "fscrypt" "$2" 2>/dev/null || true
}

fail() {
  echo "❌ $1" >&2
  notify critical "$1"
  exit 1
}

pause() {
  echo ""
  read -r -p "Pressione Enter para fechar..." _
}
trap pause EXIT

if ! command -v fscrypt >/dev/null 2>&1; then
  fail "fscrypt não está instalado. Instale com: sudo pacman -S fscrypt"
fi

if [ "$#" -eq 0 ]; then
  fail "Nenhum diretório selecionado."
fi

for dir in "$@"; do
  dir=$(realpath -s -- "$dir")

  if [ ! -d "$dir" ]; then
    echo "⚠️  '$dir' não é um diretório, pulando."
    continue
  fi

  if ! fscrypt status "$dir" >/dev/null 2>&1; then
    echo "⚠️  '$dir' não parece estar encriptado com fscrypt, pulando."
    continue
  fi

  echo "=== Desbloqueando: $dir ==="
  if fscrypt unlock "$dir"; then
    notify normal "Diretório desbloqueado: $dir"
    echo "✅ '$dir' desbloqueado."
    echo "   Pra trancar de novo: fscrypt lock \"$dir\""
  else
    notify critical "Falha ao desbloquear $dir"
    echo "❌ Falha ao desbloquear '$dir'."
  fi
done
