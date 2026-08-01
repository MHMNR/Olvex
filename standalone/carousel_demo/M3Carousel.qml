import QtQuick
import QtQuick.Controls

Item {
    id: root

    // ---- Public API ----
    property var model: []
    property string layout: "multiBrowse" // multiBrowse | uncontained | heroStart | heroCenter | fullscreen
    property real largeSize: 280          // max width of focal item
    property real mediumSize: 150
    property real smallSize: 64           // M3 spec: 40-64dp small item width
    property real itemSpacing: 12
    property real itemHeight: 220
    property real cornerRadius: 24        // M3 shape.extraLarge
    property int  currentIndex: 0
    property bool snapEnabled: true

    property Component delegate

    signal itemClicked(int index, var itemData)

    implicitHeight: itemHeight
    implicitWidth: parent ? parent.width : 800
    clip: false

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: contentRow.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: true

        // ---- Keyline Math ----
        function focalStart() { return width * 0.5 - root.largeSize * 0.5 }
        function focalEnd()   { return width * 0.5 + root.largeSize * 0.5 }

        function widthForItem(itemCenterX) {
            if (root.layout === "uncontained")
                return root.largeSize
            if (root.layout === "fullscreen")
                return width

            var fStart = focalStart()
            var fEnd = focalEnd()

            if (itemCenterX >= fStart && itemCenterX <= fEnd)
                return root.largeSize

            var falloffZone = root.mediumSize * 1.4
            var dist = itemCenterX < fStart ? fStart - itemCenterX : itemCenterX - fEnd

            var t = Math.min(1.0, dist / falloffZone)
            var floor = (root.layout === "heroCenter" || root.layout === "heroStart")
                ? root.smallSize
                : root.mediumSize

            if (root.layout === "multiBrowse" && dist > falloffZone) {
                var edgeDist = dist - falloffZone
                var edgeZone = root.mediumSize
                var t2 = Math.min(1.0, edgeDist / edgeZone)
                return lerp(root.mediumSize, root.smallSize, t2)
            }

            return lerp(root.largeSize, floor, t)
        }

        function lerp(a, b, t) { return a + (b - a) * t }

        Row {
            id: contentRow
            height: flick.height
            spacing: root.itemSpacing

            // Leading padding
            Item { 
                width: root.layout === "uncontained" 
                    ? 16 
                    : (root.layout === "heroStart" ? 24 : flick.width / 2 - root.largeSize / 2)
                height: 1 
            }

            Repeater {
                id: repeater
                model: root.model

                delegate: Item {
                    id: cell
                    required property int index
                    required property var modelData

                    height: root.itemHeight
                    width: flick.widthForItem(cellCenterX())

                    function cellCenterX() {
                        return x + width / 2 - flick.contentX
                    }

                    Connections {
                        target: flick
                        function onContentXChanged() { cell.width = flick.widthForItem(cell.cellCenterX()) }
                    }

                    property real parallaxOffset: (flick.contentX - cell.x) * 0.15

                    // Outer Card Mask & Surface
                    Rectangle {
                        id: cardBg
                        anchors.fill: parent
                        radius: root.cornerRadius
                        color: "#2B2930"
                        clip: true

                        // Delegate Content
                        Loader {
                            id: contentLoader
                            anchors.fill: parent
                            sourceComponent: root.delegate
                            onLoaded: {
                                if (item) {
                                    if ("parallaxOffset" in item) item.parallaxOffset = cell.parallaxOffset
                                    if ("modelData" in item) item.modelData = cell.modelData
                                    if ("index" in item) item.index = cell.index
                                    if ("itemWidth" in item) item.itemWidth = cell.width
                                    if ("isCurrent" in item) item.isCurrent = Qt.binding(() => root.currentIndex === cell.index)
                                }
                            }
                        }

                        // Border highlight when active
                        Rectangle {
                            anchors.fill: parent
                            radius: root.cornerRadius
                            color: "transparent"
                            border.color: root.currentIndex === cell.index ? "#D0BCFF" : "transparent"
                            border.width: 3
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentIndex = cell.index
                            root.itemClicked(cell.index, cell.modelData)
                            if (root.snapEnabled) root.snapTo(cell.index)
                        }
                    }
                }
            }

            // Trailing padding
            Item { 
                width: flick.width / 2 - root.largeSize / 2
                height: 1 
            }
        }

        onMovementEnded: if (root.snapEnabled) root.snapToNearest()
        onFlickEnded: if (root.snapEnabled) root.snapToNearest()
    }

    function snapToNearest() {
        var target = flick.width / 2
        var best = 0
        var bestDist = Number.MAX_VALUE
        for (var i = 0; i < repeater.count; i++) {
            var it = repeater.itemAt(i)
            if (!it) continue
            var c = it.x + it.width / 2 - flick.contentX
            var d = Math.abs(c - target)
            if (d < bestDist) { bestDist = d; best = i }
        }
        snapTo(best)
    }

    function snapTo(index) {
        var it = repeater.itemAt(index)
        if (!it) return
        var destContentX = it.x + it.width / 2 - flick.width / 2
        destContentX = Math.max(0, Math.min(destContentX, flick.contentWidth - flick.width))
        snapAnim.to = destContentX
        snapAnim.restart()
        root.currentIndex = index
    }

    NumberAnimation {
        id: snapAnim
        target: flick
        property: "contentX"
        duration: 350
        easing.type: Easing.OutCubic
    }
}
