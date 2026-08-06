#!/bin/bash
# Toggle default audio sink between HDMI and headset (Astro A50), moving active streams along.

HDMI="alsa_output.pci-0000_02_00.1.hdmi-stereo"
HEADSET="alsa_output.usb-Astro_Gaming_Astro_A50-00.stereo-chat"

current="$(pactl get-default-sink)"

if [ "$current" = "$HDMI" ]; then
  target="$HEADSET"
  label="Headset"
else
  target="$HDMI"
  label="Audio HDMI"
fi

pactl set-default-sink "$target"

pactl list short sink-inputs | while read -r id _; do
  pactl move-sink-input "$id" "$target"
done

notify-send -t 1500 -i audio-volume-high "Saída de áudio" "$label" 2>/dev/null
