#!/usr/bin/env bash
# Build and run the component gallery, then capture it for the README.
#
#   ./scripts/capture-gallery.sh          macOS: click the window when prompted
#
# Writes docs/images/gallery.png and prints the markdown line to paste.
set -euo pipefail
cd "$(dirname "$0")/.."

PRESET="${PRESET:-host-debug}"
BIN="build/${PRESET}/bin/smarton_gallery"

[[ -x "$BIN" || -d "$BIN.app" ]] || {
    echo "Build first: cmake --preset $PRESET && cmake --build --preset $PRESET"
    exit 1
}

mkdir -p docs/images

if [[ "$(uname)" == "Darwin" ]]; then
    [[ -d "$BIN.app" ]] && open "$BIN.app" || "$BIN" &
    echo "Waiting for the gallery window..."
    sleep 3
    echo
    echo "Capture mode: press SPACE to switch to window capture, then click"
    echo "the gallery window. Or drag a region. Esc cancels."
    echo
    # -i is interactive: drag a region, or press Space for window mode.
    # -o omits the window shadow. Plain -w frequently fails with
    # "could not create image from window" when Terminal lacks Screen
    # Recording permission, or when the window is not frontmost.
    screencapture -i -o docs/images/gallery.png

    # A full-screen grab means Space/window-mode was not used and the
    # wallpaper was captured instead of the gallery. Refuse it: a wallpaper
    # posing as a component gallery is worse than no screenshot at all.
    if [[ -s docs/images/gallery.png ]]; then
        SCREEN_W=$(system_profiler SPDisplaysDataType 2>/dev/null \
                   | awk -F'[ x]+' '/Resolution/{print $3; exit}')
        SHOT_W=$(sips -g pixelWidth docs/images/gallery.png 2>/dev/null \
                 | awk '/pixelWidth/{print $2}')
        if [[ -n "$SCREEN_W" && -n "$SHOT_W" && "$SHOT_W" -ge "$SCREEN_W" ]]; then
            echo
            echo "That looks like a full-screen capture (${SHOT_W}px wide), not the"
            echo "gallery window. Re-run and press SPACE first, then click the window."
            rm -f docs/images/gallery.png
            exit 1
        fi
    fi

    if [[ ! -s docs/images/gallery.png ]]; then
        echo
        echo "Capture produced nothing. Two usual causes:"
        echo "  1. Screen Recording permission - System Settings > Privacy &"
        echo "     Security > Screen Recording, enable your terminal, restart it."
        echo "  2. You pressed Esc."
        echo
        echo "Manual fallback: Cmd+Shift+4, then Space, then click the window."
        echo "Save it as docs/images/gallery.png"
        exit 1
    fi
else
    "$BIN" &
    sleep 3
    command -v import >/dev/null \
        && import -window root docs/images/gallery.png \
        || { echo "Install ImageMagick, or screenshot manually to docs/images/gallery.png"; exit 1; }
fi

echo
echo "Saved docs/images/gallery.png"
echo "Paste this under the title in README.md:"
echo
echo "![SmarTon component gallery](docs/images/gallery.png)"
