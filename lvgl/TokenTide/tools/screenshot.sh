#!/usr/bin/env bash
# Grab the current LVGL screen from a device running the tokentide_screenshot
# component. Usage: tools/screenshot.sh <host-or-ip> [out.png]
set -euo pipefail

host="${1:?usage: screenshot.sh <host-or-ip> [out.png]}"
out="${2:-screenshot.png}"

tmp="$(mktemp --suffix=.bmp)"
trap 'rm -f "$tmp"' EXIT
curl -fsS --max-time 15 "http://${host}:8081/screenshot" -o "$tmp"

if command -v magick >/dev/null 2>&1; then
  magick "$tmp" "$out"
elif command -v convert >/dev/null 2>&1; then
  convert "$tmp" "$out"
else
  cp "$tmp" "${out%.png}.bmp"
  echo "imagemagick not found - saved ${out%.png}.bmp"
  exit 0
fi
echo "$out"
