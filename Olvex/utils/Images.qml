pragma Singleton

import Quickshell

Singleton {
    readonly property list<string> validImageTypes: ["jpeg", "png", "webp", "tiff", "svg", "gif"]
    readonly property list<string> validImageExtensions: ["jpg", "jpeg", "png", "webp", "tif", "tiff", "svg", "gif"]
    readonly property list<string> validWallpaperExtensions: ["jpg", "jpeg", "png", "webp", "tif", "tiff", "svg", "gif", "mp4", "mkv", "webm", "mov", "avi", "m4v"]

    function isValidImageByName(name: string): bool {
        return validImageExtensions.some(t => name.endsWith(`.${t}`));
    }
}
