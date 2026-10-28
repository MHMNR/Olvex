
import QtQuick
import Quickshell.Widgets
import qs.utils

Item {
    id: root

    // Easier (and more efficient) to ignore it than to check type and cast
    readonly property int status: loader.item?.status ?? Image.Null // qmllint disable missing-property
    readonly property real actualSize: Math.min(width, height)
    property real implicitSize
    property url source
    property real margins: 0

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    readonly property string effectiveSource: {
        const _ = Icons.iconEpoch;
        const s = root.source ? root.source.toString() : "";
        if (!s) return "";
        if (s.startsWith("image://icon/")) {
            const iconName = s.slice("image://icon/".length).split("?")[0];
            return Icons.resolveIcon(iconName, "");
        }
        return s;
    }

    Loader {
        id: loader

        asynchronous: false
        anchors.fill: parent
        sourceComponent: root.effectiveSource ? (root.effectiveSource.startsWith("image://icon/") ? iconImage : cachingImage) : null
    }

    Component {
        id: cachingImage

        CachingImage {
            path: Paths.toLocalFile(root.effectiveSource)
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
        }
    }

    Component {
        id: iconImage

        IconImage {
            anchors.fill: parent
            anchors.margins: root.margins
            source: root.actualSize >= 8 ? root.source : ""
            smooth: true
            mipmap: true
        }
    }
}
