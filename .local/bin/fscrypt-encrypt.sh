#!/usr/bin/env bash
# Thunar Custom Action: encripta um diretório (vazio) com fscrypt.
# fscrypt faz criptografia por diretório em cima do filesystem (ext4/btrfs/f2fs),
# funciona normalmente dentro de uma partição já protegida por LUKS2 - são
# camadas independentes (LUKS protege o disco em repouso; fscrypt protege um
# diretório específico com sua própria senha, mesmo com o disco já montado).
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

if [ ! -f /etc/fscrypt.conf ]; then
  fail "fscrypt ainda não foi configurado neste sistema. Rode 'sudo fscrypt setup' primeiro (veja o README)."
fi

for dir in "$@"; do
  dir=$(realpath -s -- "$dir")

  if [ ! -d "$dir" ]; then
    echo "⚠️  '$dir' não é um diretório, pulando."
    continue
  fi

  if [ -n "$(ls -A -- "$dir" 2>/dev/null)" ]; then
    echo "⚠️  '$dir' não está vazio. O fscrypt só encripta diretórios vazios."
    echo "    Crie um diretório novo, mova o conteúdo pra dentro dele depois de encriptado."
    continue
  fi

  echo "=== Encriptando: $dir ==="
  echo "(escolha um protector - senha customizada é a opção mais simples)"
  if fscrypt encrypt "$dir"; then
    notify normal "Diretório encriptado: $dir"
    echo "✅ '$dir' encriptado."
  else
    notify critical "Falha ao encriptar $dir"
    echo "❌ Falha ao encriptar '$dir'."
  fi
done
