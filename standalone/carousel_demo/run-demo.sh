#!/usr/bin/env bash
# Helper script to launch M3 Carousel Wallpaper Selector Demo

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

echo "Launching M3 Carousel Demo..."
if command -v qmlscene &>/dev/null; then
    qmlscene "${SCRIPT_DIR}/WallpaperCarouselDemo.qml"
elif command -v quickshell &>/dev/null; then
    quickshell -p "${SCRIPT_DIR}/WallpaperCarouselDemo.qml"
elif command -v qml &>/dev/null; then
    qml "${SCRIPT_DIR}/WallpaperCarouselDemo.qml"
else
    echo "[ERROR] No suitable QML runner (qmlscene, quickshell, qml) found in PATH."
    exit 1
fi
