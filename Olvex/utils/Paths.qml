pragma Singleton

import QtQuick
import Quickshell
import Olvex
import Olvex.Config

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string pictures: absolutePath(Quickshell.env("XDG_PICTURES_DIR") || `${home}/Pictures`)
    readonly property string videos: absolutePath(Quickshell.env("XDG_VIDEOS_DIR") || `${home}/Videos`)

    readonly property string data: `${Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`}/olvex`
    readonly property string state: `${Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`}/olvex`
    readonly property string cache: `${Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`}/olvex`
    readonly property string config: `${Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`}/olvex`

    readonly property string imagecache: `${cache}/imagecache`
    readonly property string notifimagecache: `${imagecache}/notifs`
    readonly property string wallsdir: Quickshell.env("OLVEX_WALLPAPERS_DIR") || absolutePath(GlobalConfig.paths.wallpaperDir)
    readonly property string recsdir: Quickshell.env("OLVEX_RECORDINGS_DIR") || `${videos}/Recordings`
    readonly property string libdir: Quickshell.env("OLVEX_LIB_DIR") || "/usr/lib/olvex"

    function toLocalFile(path: url): string {
        path = Qt.resolvedUrl(path);
        return path.toString() ? CUtils.toLocalFile(path) : "";
    }

    function absolutePath(path: string): string {
        return toLocalFile(path.replace(/~|(\$({?)HOME(}?))+/, home));
    }

    function shortenHome(path: string): string {
        return path.replace(home, "~");
    }
}
