#!/usr/bin/env bash
#
# top_ram.sh — mostra os 10 processos que mais consomem RAM,
# agrupando processos com o mesmo nome (ex: várias threads/instâncias do firefox).

set -euo pipefail

ps -eo comm,rss --no-headers \
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
    | awk '
        BEGIN {
            printf "%-8s %-10s %s\n", "RAM", "RAM(KB)", "PROCESSO"
        }
        {
            rss_kb = $1
            name = $2
            for (i = 3; i <= NF; i++) name = name " " $i

            if (rss_kb >= 1048576)
                hr = sprintf("%.2fG", rss_kb / 1048576)
            else
                hr = sprintf("%.1fM", rss_kb / 1024)

            printf "%-8s %-10d %s\n", hr, rss_kb, name
        }
    '
