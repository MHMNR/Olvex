import QtQuick
import Quickshell
import Olvex.Internal
import qs.utils

Image {
    id: root

    property alias path: manager.path

    function reload() {
        manager.updateSource();
    }

    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    smooth: true
    mipmap: true

    Connections {
        function onDevicePixelRatioChanged(): void {
            manager.updateSource();
        }

        target: QsWindow.window
    }

    CachingImageManager {
        id: manager

        item: root
        cacheDir: Qt.resolvedUrl(Paths.imagecache)
    }
}
