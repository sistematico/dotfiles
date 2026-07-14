#!/usr/bin/env bash

# {
#   "text": "$text",
#   "tooltip": "$tooltip",
#   "class": "$class",
#   "percentage": $percentage,
#   "alt": "$alt"
# }

ICON=""
QUEUE_FILE="$HOME/.vdown/queue.txt"

# Conta downloads ativos
downloads=$(ps aux | grep 'yt-dlp' | grep -v 'grep' | wc -l)

# Conta itens na fila
if [ -f "$QUEUE_FILE" ]; then
    queued=$(wc -l < "$QUEUE_FILE" 2>/dev/null)
else
    queued=0
fi


# Determina o texto e tooltip
if [ "$downloads" -eq 0 ] && [ "$queued" -eq 0 ]; then
    # Nenhum download e fila vazia
    text="$ICON"
    tooltip="Nenhum download ativo"
    class="idle"
elif [ "$downloads" -gt 0 ]; then
    # Há downloads ativos
    if [ "$queued" -gt 0 ]; then
        # Downloads ativos + fila
        text="$ICON $downloads+$queued"
        if [ "$downloads" -eq 1 ]; then
            tooltip="1 download ativo • $queued na fila"
        else
            tooltip="$downloads downloads ativos • $queued na fila"
        fi
    else
        # Apenas downloads ativos
        text="$ICON $downloads"
        if [ "$downloads" -eq 1 ]; then
            tooltip="1 download ativo"
        else
            tooltip="$downloads downloads ativos"
        fi
    fi
    class="downloading"
else
    # Apenas itens na fila
    text="$ICON $queued"
    if [ "$queued" -eq 1 ]; then
        tooltip="1 vídeo na fila"
    else
        tooltip="$queued vídeos na fila"
    fi
    class="queued"
fi

printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' "$text" "$tooltip" "$class"
