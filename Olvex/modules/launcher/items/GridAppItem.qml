import M3Shapes
import Olvex.Config
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.components.effects
import qs.modules.launcher.services
import qs.services
import qs.utils

Item {
    id: root

    required property DesktopEntry modelData
    required property DrawerVisibilities visibilities
    required property var panels
    required property GridView gridView
    required property int revealEpoch
    required property bool revealPending
    required property int index

    signal contextMenuRequested(sourceItem: Item)
    signal mouseActivated(item: Item)

    // Called by Content.qml on Enter key press when this item is selected
    function select() {
        if (!root.modelData) return;
        iconClickAnim.start();
        Apps.launch(root.modelData);
        root.visibilities.launcher = false;
    }

    // GridView delegate sizing
    implicitWidth: 110
    implicitHeight: 120
    width: 110
    height: 120

    readonly property bool isSelected: gridView.currentIndex === index
    readonly property bool isHovered: mouseArea.containsMouse
    readonly property bool isFavourite: root.modelData && Strings.testRegexList(GlobalConfig.launcher.favouriteApps, root.modelData.id)

    onIsSelectedChanged: {
        if (isSelected && !revealPending)
            scaleBounce.restart();
    }

    SequentialAnimation {
        id: scaleBounce
        NumberAnimation { target: tile; property: "scale"; to: 1.05; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: tile; property: "scale"; to: 1.0; duration: 130; easing.type: Easing.OutQuad }
    }

    // Material 3 Expressive Stagger Pop & Viewport Entry Animation
    readonly property int openStaggerMs: Math.min(index * 14, 220)
    readonly property real openYOffset: 18

    // Viewport visibility relative to GridView scrolling position
    readonly property real itemViewportY: y - (root.gridView ? root.gridView.contentY : 0)
    readonly property real itemViewportBottom: itemViewportY + height
    readonly property bool isInView: !root.gridView || (itemViewportBottom > -4 && itemViewportY < root.gridView.height + 4)

    // The entire interactive tile — styled container
    Item {
        id: tile
        anchors.centerIn: parent
        width: 104
        height: 112

        opacity: (root.revealPending || !root.isInView) ? 0.0 : 1.0
        scale: (root.revealPending || !root.isInView) ? 0.80 : 1.0

        Behavior on opacity {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutBack
                easing.overshoot: 1.12
            }
        }

        transform: Translate {
            y: root.revealPending ? root.openYOffset : (!root.isInView ? (root.itemViewportY < 0 ? -12 : 12) : 0)

            Behavior on y {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutQuad
                }
            }
        }

        StateLayer {
            id: stateLayer
            radius: Tokens.rounding.normal
            color: Colours.palette.m3onSurface
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.contextMenuRequested(stateLayer);
                } else {
                    root.select();
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            onEntered: {
                root.mouseActivated(root);
            }
        }

        // Selected / Focused / Hovered background pill
        StyledRect {
            id: focusPill
            anchors.fill: parent
            radius: Tokens.rounding.normal
            color: "transparent"
        }

        Item {
            id: icon

            width: 52
            height: 52
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            scale: mouseArea.containsMouse ? 1.06 : 1

            SequentialAnimation {
                id: iconClickAnim

                NumberAnimation {
                    target: icon
                    property: "scale"
                    from: 1
                    to: 1.4
                    duration: 150
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.5
                }

                NumberAnimation {
                    target: icon
                    property: "scale"
                    from: 1.4
                    to: 1
                    duration: 250
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.5
                }

            }

            MaterialShape {
                anchors.fill: parent
                implicitSize: parent.width
                shape: MaterialShape.Square
                color: Colours.layer(Colours.palette.m3surfaceVariant, 0.4)
            }

            IconImage {
                id: appIcon

                asynchronous: true
                smooth: true
                mipmap: true
                source: root.modelData ? Icons.resolveApp(root.modelData) : ""
                anchors.fill: parent
                anchors.margins: 7
            }

            StyledText {
                anchors.centerIn: parent
                visible: !appIcon.source || appIcon.status === Image.Error || appIcon.status === Image.Null
                text: root.modelData && root.modelData.name ? root.modelData.name.charAt(0).toUpperCase() : "?"
                font.weight: Font.DemiBold
                textPointSize: Tokens.font.size.large
                color: Colours.palette.m3primary
            }
        }

        StyledText {
            id: name

            text: root.modelData && root.modelData.name ? root.modelData.name : ""
            font.weight: Font.Normal
            color: mouseArea.containsMouse ? (Colours.light ? "#000000" : "#ffffff") : Qt.alpha(Colours.light ? "#000000" : "#ffffff", 0.7)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            anchors.top: icon.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 4
            anchors.rightMargin: 4
        }

        Rectangle {
            visible: root.isFavourite
            width: 14
            height: 14
            radius: 7
            color: Colours.palette.m3primaryContainer
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 4
            anchors.rightMargin: 4

            MaterialIcon {
                text: "favorite"
                fill: 1
                color: Colours.palette.m3primary
                iconPointSize: 7
                anchors.centerIn: parent
            }

        }

    }

    // Context menu is handled by the shared menu in AppList

}
