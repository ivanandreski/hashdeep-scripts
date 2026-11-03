
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    desktop)
        kscreen-doctor \
            output.HDMI-A-1.disable \
            output.DP-1.enable \
            output.DP-1.mode.2560x1440@144 \
            output.DP-1.position.0,239 \
            output.DP-1.rotation.normal \
            output.DP-1.priority.1 \
            output.DP-2.enable \
            output.DP-2.mode.1920x1080@60 \
            output.DP-2.position.2560,0 \
            output.DP-2.rotation.right \
            output.DP-2.priority.2
        echo "Desktop profile applied."
        ;;
    tv)
        kscreen-doctor \
            output.DP-2.disable \
            output.DP-1.disable \
            output.HDMI-A-1.enable \
            output.HDMI-A-1.mode.3840x2160@60 \
            output.HDMI-A-1.position.0,0 \
            output.HDMI-A-1.rotation.normal \
            output.HDMI-A-1.priority.1
        echo "TV profile applied."
        ;;
    *)
        echo "Usage: displays {desktop|tv}"
        exit 1
        ;;
esac
