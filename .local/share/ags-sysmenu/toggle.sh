#!/usr/bin/env bash
# Toggles the system menu, starting the AGS instance on first use.
DIR="$(cd "$(dirname "$0")" && pwd)"

if ags list 2>/dev/null | grep -qw sysmenu; then
    ags toggle sysmenu -i sysmenu
else
    ags run "$DIR" >/dev/null 2>&1 &
    disown
    for _ in $(seq 1 50); do
        ags toggle sysmenu -i sysmenu 2>/dev/null && exit 0
        sleep 0.1
    done
    ags toggle sysmenu -i sysmenu
fi
