#!/usr/bin/env bash
#
# manage-domain-cert.sh
#
# Automatiza a adição e remoção de domínios com certificado via acme.sh + nginx,
# seguindo o padrão descrito em GUIA-acme-troubleshooting.md:
#   - cria um vhost nginx dedicado servindo /.well-known/acme-challenge/
#   - emite o certificado via Let's Encrypt (webroot / HTTP-01)
#   - instala o certificado em /etc/certs/<dominio>/
#   - configura o auto-reload do nginx via --reloadcmd
#   - (opcional) remove tudo isso de volta
#
# Uso:
#   ./manage-domain-cert.sh add <dominio> [webroot]
#   ./manage-domain-cert.sh remove <dominio>
#   ./manage-domain-cert.sh renew <dominio>
#
# Exemplos:
#   ./manage-domain-cert.sh add achemeucarro.strangled.net
#   ./manage-domain-cert.sh add meusite.com /var/www/meusite.com
#   ./manage-domain-cert.sh remove achemeucarro.strangled.net
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configurações padrão (ajuste conforme seu ambiente)
# ---------------------------------------------------------------------------
NGINX_SITES_DIR="/etc/nginx/sites.d"
NGINX_SITE_PREFIX="50"          # prefixo numérico do arquivo de config (ordem de load)
WEBROOT_BASE="/var/www"
CERTS_BASE="/etc/certs"
ACME_SERVER="letsencrypt"       # letsencrypt | zerossl | buypass ...
RELOAD_CMD="service nginx force-reload"

# ---------------------------------------------------------------------------
# Funções auxiliares
# ---------------------------------------------------------------------------
log()  { echo -e "\033[1;34m[info]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[ok]\033[0m $*"; }
err()  { echo -e "\033[1;31m[erro]\033[0m $*" >&2; }
die()  { err "$*"; exit 1; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Este script precisa ser executado como root (use sudo)."
  fi
}

require_acme() {
  command -v acme.sh >/dev/null 2>&1 || die "acme.sh não encontrado no PATH. Verifique a instalação (~/.acme.sh/acme.sh.env)."
}

nginx_conf_path() {
  local domain="$1"
  echo "${NGINX_SITES_DIR}/${NGINX_SITE_PREFIX}-${domain}.conf"
}

# ---------------------------------------------------------------------------
# add: cria vhost, emite e instala o certificado
# ---------------------------------------------------------------------------
cmd_add() {
  local domain="$1"
  local webroot="${2:-${WEBROOT_BASE}/${domain}}"
  local conf_file
  conf_file="$(nginx_conf_path "$domain")"
  local cert_dir="${CERTS_BASE}/${domain}"

  [[ -z "$domain" ]] && die "Informe o domínio. Uso: $0 add <dominio> [webroot]"

  if [[ -f "$conf_file" ]]; then
    die "Já existe um vhost em ${conf_file}. Remova antes ou edite manualmente."
  fi

  log "Criando webroot em ${webroot}"
  mkdir -p "${webroot}/.well-known/acme-challenge"

  log "Criando vhost nginx em ${conf_file}"
  cat > "$conf_file" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};

    root ${webroot};

    location /.well-known/acme-challenge/ {
        allow all;
        default_type "text/plain";
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

  log "Testando configuração do nginx"
  nginx -t

  log "Recarregando nginx"
  systemctl reload nginx

  log "Verificando se a porta 80 responde para ${domain} (challenge de teste)"
  echo "ping-$$" > "${webroot}/.well-known/acme-challenge/ping-$$"
  if curl -fsS "http://${domain}/.well-known/acme-challenge/ping-$$" >/dev/null; then
    ok "Porta 80 respondendo corretamente para ${domain}"
  else
    rm -f "${webroot}/.well-known/acme-challenge/ping-$$"
    die "A porta 80 não respondeu como esperado para ${domain}. Confira DNS/firewall antes de continuar."
  fi
  rm -f "${webroot}/.well-known/acme-challenge/ping-$$"

  log "Emitindo certificado via acme.sh (server: ${ACME_SERVER})"
  acme.sh --issue -d "$domain" -w "$webroot" --server "$ACME_SERVER" --force

  log "Instalando certificado em ${cert_dir}"
  mkdir -p "$cert_dir"
  acme.sh --install-cert -d "$domain" \
    --key-file "${cert_dir}/key.pem" \
    --fullchain-file "${cert_dir}/cert.pem" \
    --reloadcmd "${RELOAD_CMD}"

  ok "Certificado emitido e instalado para ${domain}."
  echo
  log "Próximo passo manual: adicione um bloco 'server { listen 443 ssl; ... }' no arquivo"
  log "${conf_file} apontando para:"
  echo "    ssl_certificate     ${cert_dir}/cert.pem;"
  echo "    ssl_certificate_key ${cert_dir}/key.pem;"
}

# ---------------------------------------------------------------------------
# remove: revoga (opcional), remove certificado do acme.sh e vhost do nginx
# ---------------------------------------------------------------------------
cmd_remove() {
  local domain="$1"
  local conf_file
  conf_file="$(nginx_conf_path "$domain")"
  local cert_dir="${CERTS_BASE}/${domain}"

  [[ -z "$domain" ]] && die "Informe o domínio. Uso: $0 remove <dominio>"

  read -r -p "Confirma remoção completa do certificado e vhost de '${domain}'? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { log "Cancelado."; exit 0; }

  log "Parando renovação automática (acme.sh --remove)"
  acme.sh --remove -d "$domain" --ecc || log "Nada para remover no acme.sh (ou já removido)."

  log "Removendo diretório de certificado do acme.sh"
  rm -rf "/root/.acme.sh/${domain}_ecc"

  log "Removendo certificado instalado em ${cert_dir}"
  rm -rf "$cert_dir"

  if [[ -f "$conf_file" ]]; then
    log "Removendo vhost nginx ${conf_file}"
    rm -f "$conf_file"
  else
    log "Vhost ${conf_file} não encontrado, pulando."
  fi

  log "Testando configuração do nginx"
  nginx -t

  log "Recarregando nginx"
  systemctl reload nginx

  ok "Domínio ${domain} removido (certificado + vhost)."
  log "Obs: o webroot em ${WEBROOT_BASE}/${domain} NÃO foi apagado (pode conter o site). Remova manualmente se quiser."
}

# ---------------------------------------------------------------------------
# renew: força renovação de um domínio específico
# ---------------------------------------------------------------------------
cmd_renew() {
  local domain="$1"
  [[ -z "$domain" ]] && die "Informe o domínio. Uso: $0 renew <dominio>"

  log "Forçando renovação de ${domain}"
  acme.sh --renew -d "$domain" --ecc --force

  ok "Renovação concluída para ${domain} (reloadcmd configurado deve ter recarregado o nginx automaticamente)."
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  require_root
  require_acme

  local action="${1:-}"
  case "$action" in
    add)
      shift
      cmd_add "${1:-}" "${2:-}"
      ;;
    remove)
      shift
      cmd_remove "${1:-}"
      ;;
    renew)
      shift
      cmd_renew "${1:-}"
      ;;
    *)
      cat <<EOF
Uso: $0 <add|remove|renew> <dominio> [webroot]

  add <dominio> [webroot]   Cria vhost nginx, emite e instala certificado (Let's Encrypt)
  remove <dominio>          Remove certificado (acme.sh + instalado) e vhost nginx
  renew <dominio>           Força renovação de um domínio já emitido

Exemplos:
  $0 add achemeucarro.strangled.net
  $0 add meusite.com /var/www/meusite.com
  $0 remove achemeucarro.strangled.net
  $0 renew achemeucarro.strangled.net
EOF
      exit 1
      ;;
  esac
}

main "$@"
