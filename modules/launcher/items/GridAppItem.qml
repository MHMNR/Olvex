import M3Shapes
import Olvex.Config
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
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
    required property real scrollVelocity
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

    readonly property int jellyRow: Math.floor(index / 5)
    readonly property real jellyY: {
        if (Math.abs(scrollVelocity) < 0.4)
            return 0;

        const factor = 0.62 - Math.min(jellyRow, 3) * 0.11;
        const raw = -scrollVelocity * factor;
        return Math.max(-26, Math.min(26, raw));
    }
    readonly property int openYOffset: 120
    property real tileYOffset: revealEpoch > 0 ? 0 : openYOffset
    readonly property int openStaggerMs: {
        const row = Math.floor(index / 5);
        const col = index % 5;
        return Math.min(row, 3) * 34 + col * 10;
    }
    readonly property var m3Emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]
    readonly property bool isCurrent: gridView.currentIndex === index
    readonly property bool isFavourite: modelData && Strings.testRegexList(GlobalConfig.launcher.favouriteApps, modelData.id)

    implicitWidth: 110
    implicitHeight: 120
    transform: Translate {
        y: root.tileYOffset
    }

    onRevealEpochChanged: {
        if (revealEpoch <= 0)
            return ;

        tileYOffset = openYOffset;
        openPop.restart();
    }
    onRevealPendingChanged: {
        if (!revealPending)
            return;

        openPop.stop();
        tileYOffset = openYOffset;
    }
    onModelDataChanged: {
        if (revealEpoch > 0 && !revealPending && !openPop.running) {
            tileYOffset = 0;
        }
    }

    SequentialAnimation {
        id: openPop

        PauseAnimation {
            duration: root.openStaggerMs
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "tileYOffset"
                to: 0
                duration: 400
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.m3Emphasized
            }

        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: {
            if (containsMouse) {
                root.mouseActivated(root);
                gridView.currentIndex = index;
                gridView.hoveredItem = root;
            } else if (gridView.hoveredItem === root) {
                gridView.hoveredItem = null;
            }
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.contextMenuRequested(mainContainer);
                return;
            }
            iconClickAnim.start();
            Apps.launch(root.modelData);
            root.visibilities.launcher = false;
        }
    }

    Item {
        id: mainContainer

        anchors.fill: parent
        anchors.margins: 4

        Rectangle {
            anchors.fill: parent
            radius: 16
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

            Item {
                id: iconClip

                anchors.fill: parent

                MaterialShape {
                    implicitSize: parent.width
                    shape: MaterialShape.Square
                    color: Colours.layer(Colours.palette.m3surfaceVariant, 0.5)
                }

                IconImage {
                    id: appIcon

                    asynchronous: true
                    source: Icons.resolveIcon(root.modelData?.icon || "", "image-missing")
                    anchors.fill: parent
                    anchors.margins: 7
                }

            }

        }

        StyledText {
            id: name

            text: root.modelData && root.modelData.name ? root.modelData.name : ""
            font.weight: mouseArea.containsMouse ? Font.DemiBold : Font.Normal
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

        transform: Translate {
            y: root.jellyY
        }

    }

    // Context menu is handled by the shared menu in AppList

}
