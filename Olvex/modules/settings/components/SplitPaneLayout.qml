import ".."
import "../ui"
import "."
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import Olvex.Config
import qs.services

Item {
    id: root

    property Session session: null
    property Component leftContent: null
    property Component rightContent: null
    property real leftWidthRatio: 0.24
    property int leftMinimumWidth: 260
    property int leftMaximumWidth: 320
    property var leftLoaderProperties: ({})
    property var rightLoaderProperties: ({})
    property alias leftLoader: leftLoader
    property alias rightLoader: rightLoader

    property bool collapsed: false
    property real collapsedWidth: 64
    signal toggleCollapsed()

    readonly property real dynamicLeftMinWidth: (masterItem && masterItem.minExpandedWidth !== undefined && masterItem.minExpandedWidth > 0)
        ? Math.max(root.leftMinimumWidth, masterItem.minExpandedWidth)
        : root.leftMinimumWidth
    readonly property real _rawExpandedWidth: Math.max(root.dynamicLeftMinWidth, Math.min(root.leftMaximumWidth, Math.floor(root.width * root.leftWidthRatio)))
    readonly property real computedExpandedWidth: root.width > 0
        ? Math.min(_rawExpandedWidth, Math.max(200, Math.floor(root.width * 0.36)))
        : _rawExpandedWidth

    // ── Active Master Item Geometry for Fluid Bridge / Joint ──
    readonly property Item masterItem: leftLoader.item
    readonly property bool hasBridge: masterItem !== null
        && masterItem.highlightY !== undefined
        && masterItem.highlightHeight !== undefined
        && masterItem.activeItem !== null

    // Balanced M3 translucency applied at the unified FBO layer level so overlapping
    // Master pane + Bridge Collar never double-blend or create a vertical seam at lx2.
    readonly property real surfaceGroupOpacity: Colours.transparencyEnabled
        ? Math.min(0.90, Math.max(0.78, Colours.transparencyLayers + 0.30))
        : 1.0

    readonly property color masterPaneColor: Colours.palette.m3surfaceContainerHigh
    readonly property color detailsPaneColor: Colours.palette.m3surfaceContainerLow

    // ── Unified Surface Group (Master Pane + Sliding Bridge Joint + Details Pane) ──
    Item {
        id: unifiedSurfaceGroup
        anchors.fill: parent
        z: 1
        opacity: root.surfaceGroupOpacity
        layer.enabled: Colours.transparencyEnabled
        layer.smooth: true

        // 1. Master Pane Background Card
        Rectangle {
            id: leftCardBg
            x: leftPane.x + leftCard.x
            y: leftPane.y + leftCard.y
            width: leftCard.width
            height: leftCard.height
            radius: leftCard.radius
            color: root.masterPaneColor
            border.width: 0

            Behavior on color { CAnim {} }
        }

        // 2. Unified Details Pane + Protruding Bridge Collar & Concave Fillets
        Shape {
            id: unifiedPaneShape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Colours.palette.m3shadow
                shadowOpacity: Colours.light ? 0.18 : 0.38
                shadowBlur: 0.35
                shadowVerticalOffset: 2
                shadowHorizontalOffset: 0
            }

            readonly property real lx1: leftPane.x + leftCard.x
            readonly property real lx2: lx1 + leftCard.width

            readonly property real rx1: rightPane.x + rightCard.x
            readonly property real ry1: rightPane.y + rightCard.y
            readonly property real rx2: rx1 + rightCard.width
            readonly property real ry2: ry1 + rightCard.height
            readonly property real r: rightCard.radius

            readonly property real pillH: root.hasBridge ? masterItem.highlightHeight : 40
            readonly property real pad: 7
            readonly property real collarH: pillH + pad * 2
            readonly property real collarR: collarH / 2

            readonly property real rawPillX: root.hasBridge
                ? (lx1 + masterContentWrapper.x + leftLoader.x + (masterItem.highlightX !== undefined ? masterItem.highlightX : 8))
                : (lx1 + 12)
            readonly property real bx1: Math.max(lx1 + 4, rawPillX - pad)

            readonly property real rawCenterY: root.hasBridge
                ? (leftPane.y + leftCard.y + masterContentWrapper.y + leftLoader.y + masterItem.highlightY + pillH / 2)
                : (ry1 + 120)

            readonly property real bridgeCenterY: Math.max(ry1 + r + collarR + 4, Math.min(ry2 - r - collarR - 4, rawCenterY))
            readonly property real topNeckY: bridgeCenterY - collarR
            readonly property real bottomNeckY: bridgeCenterY + collarR

            readonly property real filletR: 18
            readonly property real topFilletR: Math.max(0, Math.min(filletR, topNeckY - (ry1 + r)))
            readonly property real bottomFilletR: Math.max(0, Math.min(filletR, (ry2 - r) - bottomNeckY))

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillColor: root.detailsPaneColor

                Behavior on fillColor { CAnim {} }

                startX: unifiedPaneShape.rx1 + unifiedPaneShape.r
                startY: unifiedPaneShape.ry1

                // Top edge of Details Pane
                PathLine {
                    x: unifiedPaneShape.rx2 - unifiedPaneShape.r
                    y: unifiedPaneShape.ry1
                }
                PathArc {
                    x: unifiedPaneShape.rx2
                    y: unifiedPaneShape.ry1 + unifiedPaneShape.r
                    radiusX: unifiedPaneShape.r
                    radiusY: unifiedPaneShape.r
                    direction: PathArc.Clockwise
                }

                // Right edge of Details Pane
                PathLine {
                    x: unifiedPaneShape.rx2
                    y: unifiedPaneShape.ry2 - unifiedPaneShape.r
                }
                PathArc {
                    x: unifiedPaneShape.rx2 - unifiedPaneShape.r
                    y: unifiedPaneShape.ry2
                    radiusX: unifiedPaneShape.r
                    radiusY: unifiedPaneShape.r
                    direction: PathArc.Clockwise
                }

                // Bottom edge of Details Pane
                PathLine {
                    x: unifiedPaneShape.rx1 + unifiedPaneShape.r
                    y: unifiedPaneShape.ry2
                }
                PathArc {
                    x: unifiedPaneShape.rx1
                    y: unifiedPaneShape.ry2 - unifiedPaneShape.r
                    radiusX: unifiedPaneShape.r
                    radiusY: unifiedPaneShape.r
                    direction: PathArc.Clockwise
                }

                // Left edge of Details Pane up to bottom concave fillet of Bridge
                PathLine {
                    x: unifiedPaneShape.rx1
                    y: root.hasBridge
                        ? (unifiedPaneShape.bottomNeckY + unifiedPaneShape.bottomFilletR)
                        : (unifiedPaneShape.ry1 + unifiedPaneShape.r)
                }

                // Bottom concave fillet curving into the Bridge
                PathArc {
                    x: root.hasBridge ? (unifiedPaneShape.rx1 - unifiedPaneShape.bottomFilletR) : unifiedPaneShape.rx1
                    y: root.hasBridge ? unifiedPaneShape.bottomNeckY : (unifiedPaneShape.ry1 + unifiedPaneShape.r)
                    radiusX: root.hasBridge ? unifiedPaneShape.bottomFilletR : 0
                    radiusY: root.hasBridge ? unifiedPaneShape.bottomFilletR : 0
                    direction: PathArc.Counterclockwise
                }

                // Bottom horizontal edge of Bridge Collar into Master Pane
                PathLine {
                    x: root.hasBridge ? (unifiedPaneShape.bx1 + unifiedPaneShape.collarR) : unifiedPaneShape.rx1
                    y: root.hasBridge ? unifiedPaneShape.bottomNeckY : (unifiedPaneShape.ry1 + unifiedPaneShape.r)
                }

                // Left rounded cap of Bridge Collar (bottom-left quadrant)
                PathArc {
                    x: root.hasBridge ? unifiedPaneShape.bx1 : unifiedPaneShape.rx1
                    y: root.hasBridge ? unifiedPaneShape.bridgeCenterY : (unifiedPaneShape.ry1 + unifiedPaneShape.r)
                    radiusX: root.hasBridge ? unifiedPaneShape.collarR : 0
                    radiusY: root.hasBridge ? unifiedPaneShape.collarR : 0
                    direction: PathArc.Clockwise
                }

                // Left rounded cap of Bridge Collar (top-left quadrant)
                PathArc {
                    x: root.hasBridge ? (unifiedPaneShape.bx1 + unifiedPaneShape.collarR) : unifiedPaneShape.rx1
                    y: root.hasBridge ? unifiedPaneShape.topNeckY : (unifiedPaneShape.ry1 + unifiedPaneShape.r)
                    radiusX: root.hasBridge ? unifiedPaneShape.collarR : 0
                    radiusY: root.hasBridge ? unifiedPaneShape.collarR : 0
                    direction: PathArc.Clockwise
                }

                // Top horizontal edge of Bridge Collar back to Details Pane fillet
                PathLine {
                    x: root.hasBridge ? (unifiedPaneShape.rx1 - unifiedPaneShape.topFilletR) : unifiedPaneShape.rx1
                    y: root.hasBridge ? unifiedPaneShape.topNeckY : (unifiedPaneShape.ry1 + unifiedPaneShape.r)
                }

                // Top concave fillet curving up into Details Pane left edge
                PathArc {
                    x: unifiedPaneShape.rx1
                    y: root.hasBridge
                        ? (unifiedPaneShape.topNeckY - unifiedPaneShape.topFilletR)
                        : (unifiedPaneShape.ry1 + unifiedPaneShape.r)
                    radiusX: root.hasBridge ? unifiedPaneShape.topFilletR : 0
                    radiusY: root.hasBridge ? unifiedPaneShape.topFilletR : 0
                    direction: PathArc.Counterclockwise
                }

                // Remaining upper-left edge of Details Pane
                PathLine {
                    x: unifiedPaneShape.rx1
                    y: unifiedPaneShape.ry1 + unifiedPaneShape.r
                }

                // Top-left corner of Details Pane
                PathArc {
                    x: unifiedPaneShape.rx1 + unifiedPaneShape.r
                    y: unifiedPaneShape.ry1
                    radiusX: unifiedPaneShape.r
                    radiusY: unifiedPaneShape.r
                    direction: PathArc.Clockwise
                }
            }
        }
    }

    Item {
        id: leftPane
        z: 100

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.collapsed ? root.collapsedWidth : root.computedExpandedWidth

        Behavior on width {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveDefaultSpatial
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }

        Rectangle {
            id: leftCard
            anchors.fill: parent
            anchors.margins: Tokens.padding.normal
            anchors.leftMargin: Tokens.padding.normal
            anchors.rightMargin: 9
            radius: Tokens.rounding.large
            color: "transparent"
            border.color: "transparent"
            border.width: 0
            clip: false

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── Top Header Row (Collapse / Expand Control — Windows 10 style) ──
                Item {
                    id: topHeaderItem
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    Layout.leftMargin: root.collapsed ? 0 : Tokens.padding.normal
                    Layout.rightMargin: root.collapsed ? 0 : Tokens.padding.small
                    Layout.topMargin: 4
                    Layout.bottomMargin: 2

                    Item {
                        id: toggleBtnContainer
                        width: 40
                        height: 40
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: root.collapsed ? undefined : parent.left
                        anchors.horizontalCenter: root.collapsed ? parent.horizontalCenter : undefined
                        anchors.leftMargin: root.collapsed ? 0 : Tokens.padding.small

                        StyledRect {
                            id: toggleBtnBg
                            anchors.fill: parent
                            radius: height / 2
                            color: toggleMa.pressed ? Qt.alpha(Colours.palette.m3onSurface, 0.12) :
                                   toggleMa.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : "transparent"

                            Behavior on color { CAnim {} }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "menu"
                                color: Colours.palette.m3onSurface
                                iconPointSize: Tokens.font.size.large
                            }

                            MouseArea {
                                id: toggleMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.collapsed = !root.collapsed;
                                    root.toggleCollapsed();
                                }
                            }

                            // Floating Tooltip
                            Item {
                                z: 300
                                visible: toggleMa.containsMouse
                                opacity: toggleMa.containsMouse ? 1.0 : 0.0
                                x: parent.width + Tokens.spacing.normal
                                anchors.verticalCenter: parent.verticalCenter

                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                StyledRect {
                                    id: toggleTipBg
                                    anchors.fill: parent
                                    radius: Tokens.rounding.small
                                    color: Colours.palette.m3surfaceContainerHighest
                                    border.width: 0
                                    border.color: "transparent"

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: Colours.palette.m3shadow
                                        shadowOpacity: 0.35
                                        shadowBlur: 0.3
                                    }
                                }

                                StyledText {
                                    id: toggleTipTxt
                                    anchors.centerIn: parent
                                    anchors.leftMargin: Tokens.padding.normal
                                    anchors.rightMargin: Tokens.padding.normal
                                    text: root.collapsed ? qsTr("Expand navigation") : qsTr("Collapse navigation")
                                    color: Colours.palette.m3onSurface
                                    font.weight: Font.Medium
                                    textPointSize: Tokens.font.size.small
                                }

                                implicitWidth: Math.max(48, toggleTipTxt.implicitWidth + (Tokens.padding.normal * 2))
                                implicitHeight: 32
                            }
                        }
                    }
                }

                // ── Top Divider Line ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: root.collapsed ? 8 : Tokens.padding.normal
                    Layout.rightMargin: root.collapsed ? 8 : Tokens.padding.normal
                    Layout.bottomMargin: 4
                    height: 1
                    color: Colours.palette.m3outlineVariant
                    opacity: 0.35
                }

                // ── Master Content / Tab List ──
                Item {
                    id: masterContentWrapper
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: false

                    Loader {
                        id: leftLoader
                        anchors.fill: parent
                        anchors.margins: root.collapsed ? 4 : Tokens.padding.normal
                        anchors.topMargin: 4
                        asynchronous: true
                        sourceComponent: root.leftContent

                        Behavior on anchors.margins {
                            NumberAnimation {
                                duration: Tokens.anim.durations.expressiveDefaultSpatial
                                easing: Tokens.anim.expressiveDefaultSpatial
                            }
                        }

                        Component.onCompleted: {
                            for (const key in root.leftLoaderProperties) {
                                leftLoader[key] = root.leftLoaderProperties[key];
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: rightPane
        z: 50

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftPane.right
        anchors.right: parent.right

        StyledClippingRect {
            id: rightCard
            anchors.fill: parent
            anchors.margins: Tokens.padding.normal
            anchors.leftMargin: 9
            anchors.rightMargin: Tokens.padding.normal
            radius: Tokens.rounding.large
            color: "transparent"
            border.color: "transparent"
            border.width: 0

            Loader {
                id: rightLoader
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.normal
                anchors.rightMargin: Tokens.padding.normal
                anchors.topMargin: 0
                anchors.bottomMargin: 0
                asynchronous: true
                sourceComponent: root.rightContent

                Component.onCompleted: {
                    for (const key in root.rightLoaderProperties) {
                        rightLoader[key] = root.rightLoaderProperties[key];
                    }
                }
            }
        }
    }
}
