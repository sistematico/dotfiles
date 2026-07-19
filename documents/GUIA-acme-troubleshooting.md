# Guia: Diagnóstico e correção do acme.sh (achemeucarro.strangled.net)

## O que estava acontecendo

O erro original era:

```
cat: /root/.acme.sh/achemeucarro.strangled.net_ecc/fullchain.cer: No such file or directory
```

Isso significa que o `acme.sh` **achava** que já existia um certificado ECC emitido para o domínio, mas na verdade só existiam a chave privada (`.key`) e o CSR — o certificado nunca tinha sido baixado com sucesso. Ou seja, uma tentativa anterior de emissão tinha ficado pela metade.

## Causa raiz (passo a passo do diagnóstico)

1. **Pasta do certificado incompleta** — `ls -la /root/.acme.sh/achemeucarro.strangled.net_ecc/` mostrou apenas `.key` e `.csr`, sem nenhum `.cer`.
2. **Sem log padrão** — não existia `acme.sh.log` (o log não estava habilitado).
3. **Verificamos o método de validação** no `.conf` do domínio: HTTP-01 via webroot (`/var/www/achemeucarro.strangled.net`).
4. **DNS x IP da VPS batiam** (`dig` e `curl ifconfig.me` retornavam o mesmo IP).
5. **Mas a porta 80 recusava conexão** (`Connection refused`) no primeiro teste — o nginx não estava respondendo naquele domínio.
6. Depois que o nginx voltou a responder, percebemos que **não existia nenhum vhost (`server {}` block) configurado para esse domínio** em `/etc/nginx/sites.d/`. A requisição caía em um vhost padrão que forçava redirect para HTTPS — e como HTTPS ainda não existia para esse domínio, o desafio ACME nunca completava.
7. Criamos um vhost dedicado, escutando na porta 80, servindo `/.well-known/acme-challenge/` em texto puro (sem redirect) e mantendo o redirect para HTTPS em qualquer outro caminho.
8. Mesmo corrigindo o nginx, a emissão continuou falhando rápido — o motivo era que a **ZeroSSL (CA usada por padrão pelo acme.sh) tinha cacheado uma autorização (`authz`) "manchada"** da tentativa anterior (que falhou por causa da porta 80 fechada), e ficava reaproveitando esse resultado velho por até 24h (`retry-after: 86400`), sem tentar validar de novo.
9. **Solução final**: emitir o certificado usando **Let's Encrypt** em vez de ZeroSSL para essa emissão específica (`--server letsencrypt`), o que gerou uma ordem/autorização nova do zero — a validação passou em segundos.
10. Depois, `--install-cert` copiou a chave e o fullchain para `/etc/certs/achemeucarro.strangled.net/` e recarregou o nginx.

## Vhost criado

Arquivo: `/etc/nginx/sites.d/50-achemeucarro.strangled.net.conf`

```nginx
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
```

> Depois de ter o certificado, normalmente você adiciona um segundo `server { listen 443 ssl; ... }` nesse mesmo arquivo apontando para `/etc/certs/achemeucarro.strangled.net/cert.pem` e `key.pem`.

## Comandos finais que funcionaram

```bash
# Emitir usando Let's Encrypt em vez do ZeroSSL padrão
acme.sh --issue -d achemeucarro.strangled.net -w /var/www/achemeucarro.strangled.net --server letsencrypt --force

# Instalar (copiar chave/fullchain para o local usado pelo nginx) e recarregar
acme.sh --install-cert -d achemeucarro.strangled.net \
  --key-file /etc/certs/achemeucarro.strangled.net/key.pem \
  --fullchain-file /etc/certs/achemeucarro.strangled.net/cert.pem \
  --reloadcmd "service nginx force-reload"
```

## Pontos de atenção para o futuro

- **Domínios dinâmicos (afraid.org/strangled.net)**: confirme sempre que o registro DNS está atualizado antes de emitir/renovar. Se você usa um cliente de atualização dinâmica (ddclient, cron com curl, etc.), verifique se ele está rodando.
- **Sempre crie o vhost HTTP (porta 80) antes de rodar `acme.sh --issue`** — sem isso, o desafio HTTP-01 nunca terá onde responder.
- **Se uma emissão falhar por problema de infraestrutura (porta fechada, DNS errado, etc.), a CA pode cachear a autorização falha por até 24h.** Nesse caso, ou espere o cache expirar, ou troque de CA temporariamente (ex: `--server letsencrypt` ou `--server zerossl`) para forçar uma nova ordem.
- **Habilite log persistente** para facilitar diagnósticos futuros: `acme.sh --set-notify-hook ... ` não é necessário, mas rodar com `--log` ajuda:
  ```bash
  acme.sh --issue -d exemplo.com -w /var/www/exemplo.com --log
  ```
