#!/usr/bin/env bash
# Foreground dummy Xorg display for graphical validation in a Linux container.
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
display_number="${1:-:98}"
if [[ ! "$display_number" =~ ^:[0-9]+$ ]]; then
    printf '%s\n' 'Expected an X11 display number, for example :98.' >&2
    exit 2
fi
xorg_bin="${XORG_BIN:-/usr/lib/xorg/Xorg}"
if [[ ! -x "$xorg_bin" ]]; then
    printf '%s\n' 'Xorg and its dummy video driver are required for this helper.' >&2
    exit 1
fi
display_root="$XDG_CACHE_HOME/x11"
mkdir -p "$display_root"
cat > "$display_root/xorg.conf" <<'EOF'
Section "ServerFlags"
    Option "AutoAddDevices" "false"
    Option "AutoEnableDevices" "false"
EndSection
Section "Device"
    Identifier "Dummy"
    Driver "dummy"
    VideoRam 256000
EndSection
Section "Monitor"
    Identifier "Monitor"
    HorizSync 5.0 - 1000.0
    VertRefresh 5.0 - 200.0
    Modeline "1920x1920" 301.60 1920 2040 2248 2576 1920 1921 1924 1951
EndSection
Section "Screen"
    Identifier "Screen"
    Device "Dummy"
    Monitor "Monitor"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1920x1920"
    EndSubSection
EndSection
EOF
exec "$xorg_bin" "$display_number" -config "$display_root/xorg.conf" \
    -logfile "$display_root/Xorg.log" -nolisten tcp -noreset
