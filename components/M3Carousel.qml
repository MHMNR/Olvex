import QtQuick
import QtQuick.Controls
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    // ---- Public API ----
    property var model: []
    property string layout: "heroCenter"
    property real largeSize: 370
    property real mediumSize: 220
    property real smallSize: 60
    property real itemSpacing: Tokens.spacing.normal || 12
    property real itemHeight: 220
    property real cornerRadius: Tokens.rounding.large || 20
    property int  currentIndex: 0
    property real animatedIndex: currentIndex

    Behavior on animatedIndex {
        id: animBehavior
        enabled: true
        NumberAnimation {
            duration: Tokens.anim.durations.normal || 350
            easing.type: Easing.OutQuint
        }
    }

    onCurrentIndexChanged: {
        animatedIndex = currentIndex
    }

    property Component delegate

    signal itemClicked(int index, var itemData)

    implicitHeight: itemHeight
    implicitWidth: parent ? parent.width : 800
    clip: false

    function decrementCurrentIndex() {
        if (currentIndex > 0) currentIndex--
    }

    function incrementCurrentIndex() {
        if (model && currentIndex < model.length - 1) currentIndex++
    }

    function snapTo(index) {
        if (model && index >= 0 && index < model.length) {
            currentIndex = index
        }
    }

    function jumpTo(index) {
        if (model && index >= 0 && index < model.length) {
            animBehavior.enabled = false
            currentIndex = index
            animatedIndex = index
            animBehavior.enabled = true
        }
    }

    function lerp(a, b, t) { return a + (b - a) * t }

    function smoothstep(a, b, t) {
        t = Math.max(0, Math.min(1, t))
        t = t * t * (3 - 2 * t)
        return a + (b - a) * t
    }

    function widthForDiff(d) {
        var absD = Math.abs(d)
        if (absD <= 1.0) {
            return smoothstep(root.largeSize, root.mediumSize, absD)
        } else if (absD <= 2.0) {
            return smoothstep(root.mediumSize, root.smallSize, absD - 1.0)
        } else if (absD <= 3.0) {
            return smoothstep(root.smallSize, 0, absD - 2.0)
        }
        return 0
    }

    function opacityForDiff(d) {
        var absD = Math.abs(d)
        if (absD <= 1.0) {
            return smoothstep(1.0, 0.82, absD)
        } else if (absD <= 2.0) {
            return smoothstep(0.82, 0.50, absD - 1.0)
        } else if (absD <= 3.0) {
            return smoothstep(0.50, 0.0, absD - 2.0)
        }
        return 0.0
    }

    // 7-item virtualized window around animatedIndex
    readonly property var visibleWindow: {
        const arr = [];
        if (!model || model.length === 0) return arr;
        const total = model.length;
        const centerIdx = Math.round(animatedIndex);
        for (let offset = -3; offset <= 3; offset++) {
            const idx = centerIdx + offset;
            if (idx >= 0 && idx < total) {
                arr.push({ modelIndex: idx, data: model[idx] });
            }
        }
        return arr;
    }

    // Centered container for the visible cards
    Item {
        anchors.fill: parent

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: root.itemSpacing

            Repeater {
                id: repeater
                model: root.visibleWindow

                delegate: Item {
                    id: cell
                    required property int index
                    required property var modelData

                    readonly property int modelIdx: cell.modelData ? cell.modelData.modelIndex : 0
                    readonly property real diff: cell.modelIdx - root.animatedIndex

                    height: root.itemHeight
                    width: root.widthForDiff(cell.diff)
                    opacity: root.opacityForDiff(cell.diff)
                    visible: cell.width > 0.5

                    StyledClippingRect {
                        id: cardBg
                        anchors.fill: parent
                        radius: root.cornerRadius
                        color: Colours.tPalette.m3surfaceContainer

                        Loader {
                            id: contentLoader
                            anchors.fill: parent
                            sourceComponent: root.delegate
                            onLoaded: {
                                if (item) {
                                    item.width = Qt.binding(() => contentLoader.width)
                                    item.height = Qt.binding(() => contentLoader.height)
                                    if ("modelData" in item) item.modelData = Qt.binding(() => cell.modelData ? cell.modelData.data : null)
                                    if ("index" in item) item.index = Qt.binding(() => cell.modelIdx)
                                    if ("itemWidth" in item) item.itemWidth = Qt.binding(() => cell.width)
                                    if ("isCurrent" in item) item.isCurrent = Qt.binding(() => Math.abs(cell.diff) < 0.5)
                                }
                            }
                        }
                    }

                    // Click handler lives here — on cell directly — NOT inside the Loader,
                    // because the Loader item has undefined geometry at event time.
                    TapHandler {
                        onTapped: {
                            if (cell.modelData && cell.modelData.data) {
                                root.currentIndex = cell.modelIdx;
                                root.itemClicked(cell.modelIdx, cell.modelData.data);
                            }
                        }
                        // Swipe gestures can be handled by a separate handler or by the user dragging
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
    }
}
