#!/usr/bin/env bash
################################################################################
#                                                                              #
# Arquivo: ~/.dwm/scripts/vdown                                                #
#                                                                              #
# Autor: Lucas Saliés Brum a.k.a. sistematico <lucas@archlinux.com.br>         #
#                                                                              #
# Criado em: 2019-04-30 13:55:09                                               #
# Modificado em: 2025-01-09 (Hash-based Deduplication)                        #
#                                                                              #
# Este trabalho está licenciado com uma Licença Creative Commons               #
# Atribuição 4.0 Internacional                                                 #
# http://creativecommons.org/licenses/by/4.0/                                  #
#                                                                              #
################################################################################

# Importa variáveis do ambiente systemd user (necessário para GNOME/systemd-run)
eval "$(systemctl --user show-environment 2>/dev/null | \
    grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|DISPLAY)=' | \
    sed 's/^/export /')"

# Garante que o ambiente Wayland está disponível
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

[ -f $HOME/.config/user-dirs.dirs ] && source $HOME/.config/user-dirs.dirs

################
### SETTINGS ###
################
YTDLP_BIN="$HOME/.local/bin/yt-dlp"
RETRIES=25
PARAMS=(-R "$RETRIES" --cookies-from-browser firefox)
#PARAMS=(-R "$RETRIES")

# Limites de recursos
RATE_LIMIT="6M"           # Reduzido de 10M para 3M
BUFFER_SIZE="8K"          # Reduzido de 16K para 8K
MAX_PARALLEL_DOWNLOADS=1  # Reduzido de 3 para 1 (downloads sequenciais)
CPU_LIMIT=20              # Reduzido de 50% para 25%
USE_CPULIMIT=1
THERMAL_LIMIT=60          # Reduzido de 75°C para 65°C
CONCURRENT_FRAGMENTS=1    # Reduzido de 3 para 1
DOWNLOAD_PRIORITY=19      # 19 Nice level máximo (menor prioridade)
IO_PRIORITY=3             # ionice class (3 = idle)
SLEEP_BETWEEN_CHECKS=10   # Tempo de espera entre verificações (segundos)

NOME="VideoDown"
DIR="${XDG_DESKTOP_DIR:-${HOME}/desktop}"
TMP_DIR="$HOME/tmp"
ICONE="$HOME/.local/share/icons/Newaita-reborn-red-dark/places/64/folder-downloads.svg"
LOG_DIR="$HOME/.vdown/logs"
ERROR_LOG="$LOG_DIR/error.log"
DOWNLOAD_LOG="$LOG_DIR/downloads.log"
HASH_DB="$LOG_DIR/hashes.db"  # Banco de hashes
QUEUE_FILE="$HOME/.vdown/queue.txt"
TEMPLATE="%(title)s-%(id)s.%(ext)s"
PADRAO='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'

PASTE="$(wl-paste -n --type text/plain 2>/dev/null)"
if [ -z "$PASTE" ]; then
    PASTE="$(wl-paste -n 2>/dev/null)"
fi

if [ -z "$PASTE" ]; then
    PASTE="$(gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval 'St.Clipboard.get_default().get_text(St.ClipboardType.CLIPBOARD, (c,t) => print(t))' 2>/dev/null | sed -n "s/^(true, '\(.*\)')$/\1/p")"
fi

[ ! -d "$DIR" ] && mkdir -p "$DIR"
[ ! -d "$TMP_DIR" ] && mkdir -p "$TMP_DIR"
[ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
[ ! -f "$QUEUE_FILE" ] && touch "$QUEUE_FILE"
[ ! -f "$DOWNLOAD_LOG" ] && touch "$DOWNLOAD_LOG"
[ ! -f "$HASH_DB" ] && touch "$HASH_DB"

LAST_NOTIFY=0
safe_notify() {
    local now=$(date +%s)
    if (( now - LAST_NOTIFY < 3 )); then
        return 0
    fi
    LAST_NOTIFY=$now
    notify-send -h int:transient:1 -t 3000 -i "${ICONE}" "${NOME}" "$1"
}

echo "$(date) URL='$url' WAYLAND='$WAYLAND_DISPLAY' XDG='$XDG_RUNTIME_DIR'" >> /tmp/video-down-debug.log

[ $1 ] && url="$1" || url="${PASTE//\'/}"

if [[ "$url" == *"youtube"* ]] || [[ "$url" == *"youtu"* ]]; then
    PARAMS=(-R "$RETRIES")
fi

# Conta downloads ativos
count_active() {
    pgrep -f "yt-dlp.*http" | wc -l
}

# Normaliza URL (remove parâmetros desnecessários)
normalize_url() {
    local url="$1"
    
    # Remove fragmentos (#)
    url="${url%%#*}"
    
    # YouTube: mantém apenas v= ou ID do youtu.be
    if [[ $url =~ youtube\.com ]]; then
        if [[ $url =~ [?\&]v=([a-zA-Z0-9_-]{11}) ]]; then
            echo "youtube:${BASH_REMATCH[1]}"
            return
        fi
    elif [[ $url =~ youtu\.be/([a-zA-Z0-9_-]{11}) ]]; then
        echo "youtube:${BASH_REMATCH[1]}"
        return
    fi
    
    # Vimeo
    if [[ $url =~ vimeo\.com/([0-9]+) ]]; then
        echo "vimeo:${BASH_REMATCH[1]}"
        return
    fi
    
    # Dailymotion
    if [[ $url =~ dailymotion\.com/video/([a-zA-Z0-9]+) ]]; then
        echo "dailymotion:${BASH_REMATCH[1]}"
        return
    fi
    
    # Twitter/X
    if [[ $url =~ (twitter|x)\.com/.*/status/([0-9]+) ]]; then
        echo "twitter:${BASH_REMATCH[2]}"
        return
    fi
    
    # Instagram
    if [[ $url =~ instagram\.com/(p|reel)/([a-zA-Z0-9_-]+) ]]; then
        echo "instagram:${BASH_REMATCH[2]}"
        return
    fi
    
    # TikTok
    if [[ $url =~ tiktok\.com/.*/video/([0-9]+) ]]; then
        echo "tiktok:${BASH_REMATCH[1]}"
        return
    fi
    
    # Pornhub
    if [[ $url =~ pornhub\.com/view_video\.php ]]; then
        if [[ $url =~ viewkey=([a-zA-Z0-9]+) ]]; then
            echo "pornhub:${BASH_REMATCH[1]}"
            return
        fi
    fi
    
    # XHamster
    if [[ $url =~ xhamster\.com/(videos|movies)/([a-zA-Z0-9_-]+) ]]; then
        echo "xhamster:${BASH_REMATCH[2]}"
        return
    fi
    
    # XVideos
    if [[ $url =~ xvideos\.com/video\.?([0-9]+) ]]; then
        echo "xvideos:${BASH_REMATCH[1]}"
        return
    elif [[ $url =~ xvideos\.com/video([0-9]+) ]]; then
        echo "xvideos:${BASH_REMATCH[1]}"
        return
    fi
    
    # Fallback: remove protocolo e www
    url="${url#http://}"
    url="${url#https://}"
    url="${url#www.}"
    echo "$url"
}

# Gera hash único da URL
get_url_hash() {
    local url="$1"
    local normalized=$(normalize_url "$url")
    echo -n "$normalized" | sha256sum | cut -d' ' -f1
}

# Verifica se URL já foi baixada
is_downloaded() {
    local url="$1"
    local hash=$(get_url_hash "$url")
    
    # Busca rápida com grep
    grep -q "^$hash" "$HASH_DB" 2>/dev/null
}

# Registra download bem-sucedido
register_download() {
    local url="$1"
    local arquivo="$2"
    local hash=$(get_url_hash "$url")
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Formato: HASH|TIMESTAMP|ARQUIVO|URL
    echo "$hash|$timestamp|$arquivo|$url" >> "$HASH_DB"
    
    # Remove duplicatas (mantém primeiro registro)
    awk -F'|' '!seen[$1]++' "$HASH_DB" > "$HASH_DB.tmp" && mv "$HASH_DB.tmp" "$HASH_DB"
    
    # Log legível
    echo "$timestamp|$arquivo|$url" >> "$DOWNLOAD_LOG"
}

# Obtém informações sobre download anterior
get_download_info() {
    local url="$1"
    local hash=$(get_url_hash "$url")
    
    grep "^$hash" "$HASH_DB" 2>/dev/null | tail -n1
}

# Adiciona URL à fila
add_queue() {
    local url="$1"
    
    # Verifica se já foi baixado
    if is_downloaded "$url"; then
        local info=$(get_download_info "$url")
        local timestamp=$(echo "$info" | cut -d'|' -f2)
        local arquivo=$(echo "$info" | cut -d'|' -f3)
        
        safe_notify "Vídeo já foi baixado!\n\n📁 $arquivo\n🕐 $timestamp"
        exit 0
    fi
    
    # Verifica se já existe na fila
    local hash=$(get_url_hash "$url")
    while IFS= read -r queued_url; do
        local queued_hash=$(get_url_hash "$queued_url")
        if [ "$hash" = "$queued_hash" ]; then
            safe_notify "URL já está na fila!"
            exit 0
        fi
    done < "$QUEUE_FILE"
    
    # Adiciona
    echo "$url" >> "$QUEUE_FILE"
    
    local pos=$(wc -l < "$QUEUE_FILE")
    safe_notify "Adicionado à fila!\n\nPosição: #$pos\nAtivos: $(count_active)/$MAX_PARALLEL_DOWNLOADS"
}

# Pega próxima URL
get_next() {
    if [ -s "$QUEUE_FILE" ]; then
        head -n1 "$QUEUE_FILE"
    fi
}

# Remove primeira URL
remove_first() {
    if [ -f "$QUEUE_FILE" ]; then
        sed -i '1d' "$QUEUE_FILE"
    fi
}

# Retorna referer apropriado para cada site
get_referer() {
    local url="$1"
    if [[ $url =~ pornhub\.com ]]; then
        echo "https://www.pornhub.com/"
    elif [[ $url =~ xhamster\.com ]]; then
        echo "https://xhamster.com/"
    elif [[ $url =~ xvideos\.com ]]; then
        echo "https://www.xvideos.com/"
    else
        echo "$url"
    fi
}

# Preenche array SITE_PARAMS com flags extras por site
set_site_params() {
    local url="$1"
    SITE_PARAMS=()
    if [[ $url =~ pornhub\.com ]]; then
        SITE_PARAMS=(--add-header "Accept-Language: pt-BR,pt;q=0.9,en;q=0.8" --impersonate chrome)
    elif [[ $url =~ xhamster\.com ]]; then
        SITE_PARAMS=(--impersonate chrome)
    fi
}

# Executa download
do_download() {
    local url="$1"

    cd "$TMP_DIR"
    
    # Verifica temperatura
    if command -v sensors &> /dev/null; then
        temp=$(sensors 2>/dev/null | grep -i 'Package id 0' | awk '{print $4}' | tr -d '+°C' | cut -d'.' -f1)
        if [ ! -z "$temp" ] && [ "$temp" -gt "$THERMAL_LIMIT" ]; then
            safe_notify "CPU muito quente! (${temp}°C) - Aguardando..."
            # Aguarda 30s para temperatura baixar
            sleep 30
            # Recoloca na fila
            echo "$url" >> "$QUEUE_FILE"
            return 1
        fi
    fi
    
    # Pequena pausa antes de iniciar download (reduz pico de CPU)
    sleep 3
    
    # Double-check antes de baixar
    if is_downloaded "$url"; then
        local info=$(get_download_info "$url")
        local arquivo=$(echo "$info" | cut -d'|' -f3)
        safe_notify "Vídeo já baixado (pulando)\n\n📁 $arquivo"
        return 0
    fi
    
    local referer
    referer="$(get_referer "$url")"
    set_site_params "$url"

    arquivo="$(nice -n $DOWNLOAD_PRIORITY ionice -c $IO_PRIORITY $YTDLP_BIN "${PARAMS[@]}" "${SITE_PARAMS[@]}" --referer "$referer" --get-filename -o "$TEMPLATE" "$url" 2>/dev/null)"

    if [ -z "$arquivo" ]; then
        safe_notify "Erro ao obter nome do arquivo"
        echo "$(date '+%Y-%m-%d %H:%M:%S')|ERROR|$url" >> "$ERROR_LOG"
        return 1
    fi

    startdate=$(date '+%H:%M:%S')
    start=$(date +%s)

    safe_notify "Baixando:\n<b>$arquivo</b>"

    # Download
    OPTS=(
        --concurrent-fragments "$CONCURRENT_FRAGMENTS"
        --buffer-size "${BUFFER_SIZE}"
        --no-part
        --limit-rate "${RATE_LIMIT}"
        --throttled-rate 100K
        --no-post-overwrites
        --no-playlist
        --no-check-certificate
        --sleep-interval 1
        --max-sleep-interval 3
    )

    if [ $USE_CPULIMIT -eq 1 ] && command -v cpulimit &> /dev/null && [[ "$url" != *"xhamster"* ]]; then
        nice -n $DOWNLOAD_PRIORITY ionice -c $IO_PRIORITY $YTDLP_BIN "${PARAMS[@]}" "${SITE_PARAMS[@]}" "${OPTS[@]}" --referer "$referer" -o "$TEMPLATE" "$url" >/dev/null 2>>"$ERROR_LOG" &
        PID=$!
        cpulimit -p $PID -l $CPU_LIMIT -b >/dev/null 2>&1
        wait $PID
        status=$?
    else
        nice -n $DOWNLOAD_PRIORITY ionice -c $IO_PRIORITY $YTDLP_BIN "${PARAMS[@]}" "${SITE_PARAMS[@]}" "${OPTS[@]}" --referer "$referer" -o "$TEMPLATE" "$url" >/dev/null 2>>"$ERROR_LOG"
        status=$?
    fi
    
    enddate=$(date '+%H:%M:%S')
    diff=$(($(date +%s) - start))
    
    if [[ $status -eq 0 ]]; then
        tamanho=$(du -h "$arquivo" 2>/dev/null | awk '{print $1}')
        [ -z "$tamanho" ] && tamanho="0"
        
        # Registra download
        register_download "$url" "$arquivo"
        
        [ -e "$arquivo" ] && mv "$arquivo" "$DIR/"
        
        safe_notify "✓ Concluído!\n<b>$arquivo</b>\n\n📦 $tamanho • ⏱️ $((diff/60))m $((diff%60))s"
    else
        safe_notify "✗ Erro ao baixar:\n$arquivo"
        echo "$(date '+%Y-%m-%d %H:%M:%S')|FAILED|$arquivo|$url" >> "$ERROR_LOG"
    fi
}

# Processa fila
process_queue() {
    while true; do
        # Verifica se há espaço
        active=$(count_active)
        
        if [ $active -lt $MAX_PARALLEL_DOWNLOADS ]; then
            # Pega próxima URL
            next=$(get_next)
            
            if [ ! -z "$next" ]; then
                # Remove da fila
                remove_first
                
                # Baixa em background
                do_download "$next" &
                
                # Aguarda mais tempo entre downloads
                sleep 5
            else
                # Fila vazia
                break
            fi
        else
            # Aguarda mais tempo quando fila está cheia
            sleep $SLEEP_BETWEEN_CHECKS
        fi
    done
}

# Validação
if [[ ! $url =~ $PADRAO ]] || [ -z "$url" ]; then 
    safe_notify "Link inválido!"
    exit 1
fi

# Adiciona à fila (com verificação de duplicados)
add_queue "$url"

# Processa fila
process_queue &

exit
