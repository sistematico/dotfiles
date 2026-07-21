#!/usr/bin/env bash
#
# Módulo custom do waybar: uso de RAM no "text" e top 10 processos
# (agrupados por nome) no tooltip.

set -uo pipefail

ICON=$''

# Uso geral de RAM (via /proc/meminfo, mais preciso que free para % real)
read -r total_kb avail_kb <<<"$(awk '
    /^MemTotal:/     { total = $2 }
    /^MemAvailable:/ { avail = $2 }
    END              { print total, avail }
' /proc/meminfo)"

used_kb=$((total_kb - avail_kb))
percent=$((used_kb * 100 / total_kb))
used_gb=$(awk -v k="$used_kb" 'BEGIN { printf "%.1f", k / 1048576 }')
total_gb=$(awk -v k="$total_kb" 'BEGIN { printf "%.1f", k / 1048576 }')

text="$ICON ${percent}%"

# Top 10 processos por RAM, agrupando por nome (soma RSS de threads/instâncias)
top10=$(ps -eo comm,rss --no-headers \
    | awk '
        {
            rss = $NF
            $NF = ""
            name = $0
            gsub(/^[ \t]+|[ \t]+$/, "", name)
            total[name] += rss
        }
        END {
            for (name in total)
                printf "%d\t%s\n", total[name], name
        }
    ' \
    | sort -rn \
    | head -n 10 \
    | awk -F'\t' '
        {
            rss_kb = $1
            hr = (rss_kb >= 1048576) ? sprintf("%.2fG", rss_kb / 1048576) : sprintf("%.0fM", rss_kb / 1024)
            printf "%-7s %s\n", hr, $2
        }
    ')

tooltip="RAM: ${used_gb}G / ${total_gb}G (${percent}%)
─────────────────
${top10}"

jq -cn --arg text "$text" --arg tooltip "$tooltip" \
    '{text: $text, tooltip: $tooltip}'
