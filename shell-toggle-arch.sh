#!/bin/bash
CONFIG=~/.config/niri/config.kdl

NOCTALIA_BINDS=(
    'Mod+L { spawn "sh" "-c" "noctalia msg session lock"; }'
    'Alt+Space { spawn "sh" "-c" "noctalia msg panel-toggle launcher"; }'
    'Alt+Escape { spawn "sh" "-c" "noctalia msg panel-toggle session"; }'
    'Mod+Shift+B { spawn "noctalia" "msg" "bar-toggle"; }'
)

switch_to_dms() {
    pkill -x noctalia
    sleep 1
    sed -i 's/^spawn-at-startup "noctalia"/\/\/ spawn-at-startup "noctalia"/' "$CONFIG"
    for line in "${NOCTALIA_BINDS[@]}"; do
        esc=$(printf '%s\n' "$line" | sed 's/[&/\]/\\&/g')
        sed -i "s|^    $esc|    // $esc|" "$CONFIG"
    done
    sed -i 's|^//include "dms/binds.kdl"|include "dms/binds.kdl"|' "$CONFIG"
    niri msg action load-config-file
    setsid dms run > /tmp/dms.log 2>&1 &
    disown
    sleep 1
    notify-send "Switched to DMS"
}

switch_to_noctalia() {
    pkill -f "dms run"
    sleep 1
    sed -i 's/^\/\/ spawn-at-startup "noctalia"/spawn-at-startup "noctalia"/' "$CONFIG"
    for line in "${NOCTALIA_BINDS[@]}"; do
        esc=$(printf '%s\n' "$line" | sed 's/[&/\]/\\&/g')
        sed -i "s|^    // $esc|    $esc|" "$CONFIG"
    done
    sed -i 's|^include "dms/binds.kdl"|//include "dms/binds.kdl"|' "$CONFIG"
    niri msg action load-config-file
    setsid noctalia > /tmp/noctalia.log 2>&1 &
    disown
    sleep 1
    notify-send "Switched to Noctalia"
}

CURRENT="DMS"
pgrep -x noctalia > /dev/null && CURRENT="Noctalia"

CHOICE=$(printf "Noctalia\nDMS" | fzf --prompt="Switch shell (current: $CURRENT) > " --height=10 --border --reverse)

if [ -z "$CHOICE" ]; then
    exit 0
fi

if [ "$CHOICE" = "Noctalia" ] && [ "$CURRENT" != "Noctalia" ]; then
    switch_to_noctalia
elif [ "$CHOICE" = "DMS" ] && [ "$CURRENT" != "DMS" ]; then
    switch_to_dms
fi
