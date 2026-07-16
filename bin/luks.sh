#!/bin/bash

# Verificar privilégios de root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Por favor, execute este script como root (sudo)."
  exit 1
fi

PARTICAO="/dev/nvme1n1p2"
MAPNAME="cryptroot"
KEY_DIR="/etc/cryptsetup-keys.d"
KEYFILE="${KEY_DIR}/${MAPNAME}.key"
MKINITCPIO_CONF="/etc/mkinitcpio.conf"

if ! cryptsetup isLuks "$PARTICAO"; then
  echo "❌ Erro: '$PARTICAO' não é uma partição LUKS válida."
  exit 1
fi

habilitar_auto_unlock() {
  # Força limpeza de tentativas passadas
  rm -f "$KEYFILE"
  rm -f /etc/crypttab.initramfs
  
  echo "📁 1. Criando diretório de chaves do systemd..."
  mkdir -p "$KEY_DIR"
  chmod 700 "$KEY_DIR"

  echo "🔑 2. Gerando arquivo de chave seguro..."
  dd if=/dev/urandom of="$KEYFILE" bs=512 count=1 status=none
  chmod 600 "$KEYFILE"

  echo "🔒 3. Vinculando o arquivo de chave ao LUKS..."
  echo "⚠️ Digite sua SENHA ATUAL para autorizar o script:"
  if ! cryptsetup luksAddKey "$PARTICAO" "$KEYFILE"; then
    echo "❌ Falha ao adicionar chave. Abortando."
    rm -f "$KEYFILE"
    exit 1
  fi

  echo "📝 4. Configurando tabela crypttab específica do initramfs..."
  # O sd-encrypt do systemd requer o caminho relativo/interno à imagem de boot
  echo "${MAPNAME} ${PARTICAO} ${KEYFILE} luks" > /etc/crypttab.initramfs

  echo "🛠️ 5. Atualizando a linha FILES do mkinitcpio..."
  cp "$MKINITCPIO_CONF" "${MKINITCPIO_CONF}.bak"

  # mkinitcpio >=34 só lê a variável em maiúsculas FILES=(...); a variante
  # antiga em minúsculas "files=(...)" é ignorada silenciosamente.
  sed -i 's|^FILES=(.*)|FILES=()|' "$MKINITCPIO_CONF"
  sed -i "s|^FILES=()|FILES=(\"/etc/crypttab.initramfs\" \"${KEYFILE}\")|" "$MKINITCPIO_CONF"
  # Remove qualquer linha órfã "files=(...)" deixada por execuções antigas deste script
  sed -i '/^files=(/d' "$MKINITCPIO_CONF"

  echo "🔄 6. Reconstruindo imagens de boot (mkinitcpio)..."
  mkinitcpio -P

  echo ""
  echo "✅ CONCLUÍDO COM SUCESSO!"
  echo "🚀 O initramfs agora carrega sua chave localmente."
}

desabilitar_auto_unlock() {
  if [ ! -f "$KEYFILE" ] && [ ! -f "/etc/crypttab.initramfs" ]; then
    echo "❌ O auto-desbloqueio já parece desativado."
    exit 1
  fi

  echo "🗑️ 1. Removendo a chave do LUKS..."
  echo "⚠️ Digite sua SENHA MANUAL para autorizar a remoção:"
  cryptsetup luksRemoveKey "$PARTICAO" "$KEYFILE" 2>/dev/null || true

  echo "🧹 2. Limpando os arquivos do sistema..."
  rm -rf "$KEY_DIR"
  rm -f /etc/crypttab.initramfs
  
  # Limpa a linha FILES=() no mkinitcpio.conf
  sed -i 's|^FILES=(.*)|FILES=()|' "$MKINITCPIO_CONF"
  sed -i '/^files=(/d' "$MKINITCPIO_CONF"

  echo "🔄 3. Atualizando imagens de boot..."
  mkinitcpio -P

  echo ""
  echo "🔒 Auto-desbloqueio desativado! A senha manual voltou a ser obrigatória."
}

echo "=== GERENCIADOR AUTO-UNLOCK DEFINITIVO ==="
echo "1) Habilitar Auto-Unlock"
echo "2) Desabilitar Auto-Unlock"
echo "3) Sair"
read -p "Escolha uma opção [1-3]: " OPCAO

case $OPCAO in
  1) habilitar_auto_unlock ;;
  2) desabilitar_auto_unlock ;;
  3) exit 0 ;;
  *) echo "Opção inválida."; exit 1 ;;
esac

