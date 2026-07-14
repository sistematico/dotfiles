#!/usr/bin/env sh

# Menu de energia via rofi: Desligar, Reiniciar, Suspender, Sair

shutdown="Desligar"
reboot="Reiniciar"
suspend="Suspender"
logout="Sair"

selected=$(printf '%s\n%s\n%s\n%s\n' "$shutdown" "$reboot" "$suspend" "$logout" | \
    rofi -dmenu -i -l 4 -p "Energia" -theme-str 'window {width: 320px;}')

case "$selected" in
    "$shutdown")
        systemctl poweroff
        ;;
    "$reboot")
        systemctl reboot
        ;;
    "$suspend")
        systemctl suspend
        ;;
    "$logout")
        loginctl terminate-session "$XDG_SESSION_ID"
        ;;
esac
