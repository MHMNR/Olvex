import QtQuick
import Quickshell
import Quickshell.Widgets
import M3Shapes
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils
import qs.components.controls as Controls
import qs.modules.launcher.services

Item {
    id: root

    required property DesktopEntry modelData
    required property DrawerVisibilities visibilities
    required property GridView gridView
    required property int revealEpoch
    required property real scrollVelocity
    required property int index

    readonly property int jellyRow: Math.floor(index / 5)
    readonly property real jellyY: {
        if (Math.abs(scrollVelocity) < 0.4)
            return 0;
        const factor = 0.62 - Math.min(jellyRow, 3) * 0.11;
        const raw = -scrollVelocity * factor;
        return Math.max(-26, Math.min(26, raw));
    }

    implicitWidth: 110
    implicitHeight: 120

    property real tileOpacity: revealEpoch > 0 ? 1 : 0
    property real tileScale: revealEpoch > 0 ? 1 : 0

    readonly property int openStaggerMs: {
        const row = Math.floor(index / 5);
        const col = index % 5;
        return Math.min(row, 3) * 35 + col * 10;
    }

    opacity: tileOpacity
    scale: tileScale

    onRevealEpochChanged: {
        if (revealEpoch <= 0)
            return;
        tileOpacity = 0;
        tileScale = 0;
        openPop.restart();
    }

    onModelDataChanged: {
        if (revealEpoch > 0 && !openPop.running) {
            tileOpacity = 1;
            tileScale = 1;
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
                property: "tileOpacity"
                to: 1
                duration: 200
                easing.type: Easing.OutBack
            }

            NumberAnimation {
                target: root
                property: "tileScale"
                to: 1
                duration: 200
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
        }
    }

    readonly property bool isCurrent: gridView.currentIndex === index
    readonly property bool isFavourite: modelData
        && Strings.testRegexList(GlobalConfig.launcher.favouriteApps, modelData.id)

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onContainsMouseChanged: {
            if (containsMouse)
                gridView.currentIndex = index;
        }

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.expanded = true;
                return;
            }
            Apps.launch(root.modelData);
            root.visibilities.launcher = false;
        }
    }

    Item {
        id: mainContainer
        anchors.fill: parent
        anchors.margins: 4

        transform: Translate {
            y: root.jellyY
        }

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: mouseArea.containsMouse || root.isCurrent
                ? Qt.alpha(Colours.palette.m3onSurface, 0.08)
                : "transparent"
        }

        Item {
            id: icon
            width: 52
            height: 52

            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter

            scale: mouseArea.containsMouse || root.isCurrent ? 1.06 : 1.0

            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                id: iconMaskWrap
                anchors.fill: parent
                visible: false
                layer.enabled: true

                MaterialShape {
                    implicitSize: parent.width
                    shape: MaterialShape.Square
                    color: "white"
                }
            }

            Item {
                id: iconClip
                anchors.fill: parent
                layer.enabled: true
                layer.effect: Mask {
                    maskSource: iconMaskWrap
                }

                MaterialShape {
                    implicitSize: parent.width
                    shape: MaterialShape.Square
                    color: Colours.layer(Colours.palette.m3surfaceVariant, 0.5)
                }

                IconImage {
                    id: appIcon
                    asynchronous: true
                    source: Quickshell.iconPath(root.modelData?.icon, "image-missing")
                    anchors.fill: parent
                    anchors.margins: 7
                }
            }

        }

        StyledText {
            id: name

            text: root.modelData?.name ?? ""
            font.weight: mouseArea.containsMouse || root.isCurrent ? Font.DemiBold : Font.Normal
            color: mouseArea.containsMouse || root.isCurrent
                ? (Colours.light ? "#000000" : "#ffffff")
                : Qt.alpha(Colours.light ? "#000000" : "#ffffff", 0.7)
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

    Controls.Menu {
        id: contextMenu
        attachTo: mainContainer

        items: [
            Controls.MenuItem {
                readonly property bool isPinned: {
                    if (!root.modelData)
                        return false;
                    const pApps = root.visibilities.pinnedApps || [];
                    for (let i = 0; i < pApps.length; i++) {
                        if (pApps[i] === root.modelData.id)
                            return true;
                    }
                    return false;
                }
                text: isPinned ? qsTr("Remove from Panel") : qsTr("Add to Panel")
                icon: isPinned ? "keep_off" : "push_pin"

                onClicked: {
                    if (!root.modelData)
                        return;
                    const id = root.modelData.id;
                    const rawPinned = root.visibilities.pinnedApps || [];
                    const pinned = [];
                    for (let i = 0; i < rawPinned.length; i++)
                        pinned.push(rawPinned[i]);

                    const idx = pinned.indexOf(id);
                    if (idx > -1)
                        pinned.splice(idx, 1);
                    else
                        pinned.push(id);
                    root.visibilities.pinnedApps = pinned;
                }
            }
        ]
    }
}