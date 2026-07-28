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
