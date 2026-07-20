#!/bin/bash

TEMP_DOMAINS=($@)

for i in "${!TEMP_DOMAINS[@]}"; do
  DOMAINS="$DOMAINS -d $i"
done



curl https://get.acme.sh | sh -s email=my@example.com

cat > /etc/nginx/sites.d/50-achemeucarro.strangled.net.conf << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name achemeucarro.strangled.net;

    root /var/www/achemeucarro.strangled.net;

    location /.well-known/acme-challenge/ {
        allow all;
        default_type "text/plain";
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
EOF

mkdir -p /var/www/achemeucarro.strangled.net/.well-known/acme-challenge
acme.sh --issue -d achemeucarro.strangled.net -w /var/www/achemeucarro.strangled.net --force
acme.sh --install-cert -d achemeucarro.strangled.net --key-file /etc/certs/achemeucarro.strangled.net/key.pem --fullchain-file /etc/certs/achemeucarro.strangled.net/cert.pem --reloadcmd "service nginx force-reload"
