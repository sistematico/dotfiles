#!/usr/bin/env bash
# Menu do rofi para gravar a tela com wf-recorder: tela inteira ou uma área
# selecionada com slurp. Se já houver uma gravação em andamento, o rofi
# mostra só a opção de encerrá-la (rodar de novo com tudo selecionado não
# faz sentido, já que só cabe uma gravação por vez).
set -euo pipefail

modulesFile="/tmp/wf-recorder-mix-modules"
THEME="$HOME/.config/rofi/tokyonight.rasi"

FULL_LABEL="Tela inteira"
AREA_LABEL="Selecionar área"
STOP_LABEL="Parar gravação"

rofi_dmenu() {
  local args=(-dmenu -i -p "$1")
  [ -f "$THEME" ] && args+=(-theme "$THEME")
  rofi "${args[@]}"
}

stop_recording() {
  pkill -INT -x wf-recorder

  if [ -f "$modulesFile" ]; then
    while read -r moduleId; do
      pactl unload-module "$moduleId"
    done < "$modulesFile"
    rm -f "$modulesFile"
  fi

  notify-send -h string:wf-recorder:record -t 1000 "Finished Recording"
}

start_recording() {
  local geometry_args=()

  if [ "$1" = "area" ]; then
    local geometry
    geometry=$(slurp) || exit 0
    geometry_args=(-g "$geometry")
  fi

  notify-send -h string:wf-recorder:record -t 1000 "Recording in:" "<span color='#90a4f4' font='26px'><i><b>3</b></i></span>"
  sleep 1

  notify-send -h string:wf-recorder:record -t 1000 "Recording in:" "<span color='#90a4f4' font='26px'><i><b>2</b></i></span>"
  sleep 1

  notify-send -h string:wf-recorder:record -t 950 "Recording in:" "<span color='#90a4f4' font='26px'><i><b>1</b></i></span>"
  sleep 1

  dateTime=$(date +%m-%d-%Y-%H:%M:%S)

  defaultSink="$(pactl get-default-sink)"
  defaultSource="$(pactl get-default-source)"

  : > "$modulesFile"

  sinkModule=$(pactl load-module module-null-sink sink_name=RecordMix sink_properties=device.description=RecordMix)
  echo "$sinkModule" >> "$modulesFile"

  sysAudioModule=$(pactl load-module module-loopback source="${defaultSink}.monitor" sink=RecordMix latency_msec=50)
  echo "$sysAudioModule" >> "$modulesFile"

  micModule=$(pactl load-module module-loopback source="$defaultSource" sink=RecordMix latency_msec=50)
  echo "$micModule" >> "$modulesFile"

  # dá tempo do grafo de áudio (sink nulo + loopbacks) assentar antes de
  # começar a capturar, senão os primeiros instantes saem com estalos
  sleep 0.5

  wf-recorder --bframes 0 -a="RecordMix.monitor" "${geometry_args[@]}" -f "$HOME/videos/screencast-$dateTime.mp4"
}

if pgrep -x "wf-recorder" >/dev/null; then
  choice=$(printf '%s\n' "$STOP_LABEL" | rofi_dmenu "Gravação")
  [ "$choice" = "$STOP_LABEL" ] && stop_recording
  exit 0
fi

choice=$(printf '%s\n%s\n' "$FULL_LABEL" "$AREA_LABEL" | rofi_dmenu "Gravação")

case "$choice" in
  "$FULL_LABEL") start_recording full ;;
  "$AREA_LABEL") start_recording area ;;
  *) exit 0 ;;
esac
