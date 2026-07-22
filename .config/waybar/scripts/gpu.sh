#!/usr/bin/env bash
#
# Módulo custom do waybar: uso de GPU (nvidia-smi) no "text" e detalhes
# (memória, temperatura, potência) no tooltip.

set -uo pipefail

ICON=$''

read -r util mem_used mem_total temp power <<<"$(nvidia-smi \
    --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw \
    --format=csv,noheader,nounits | tr -d ',' )"

text="$ICON ${util}%"

tooltip="GPU: ${util}%
VRAM: ${mem_used} / ${mem_total} MiB
Temp: ${temp}°C
Potência: ${power} W"

jq -cn --arg text "$text" --arg tooltip "$tooltip" \
    '{text: $text, tooltip: $tooltip}'
