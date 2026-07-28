import QtQuick
import Quickshell
import Quickshell.Widgets
import Olvex.Config
import qs.components
import qs.services
import qs.utils
import qs.components.controls as Controls
import qs.modules.launcher.services

Item {
    id: root

    required property DesktopEntry modelData
    required property DrawerVisibilities visibilities
    required property GridView gridView
    required property int index

    implicitWidth: 110
    implicitHeight: 120

    readonly property bool isCurrent: gridView.currentIndex === index

    // Smooth hover tracking
    property bool hovered: false

    // Cascading spring chain scroll physics mapping
    property real rowOffset: 0
    readonly property real scrollOffset: Math.max(-30, Math.min(30, rowOffset))

    onScrollOffsetChanged: {
        if (scrollOffset !== 0) {
            console.log("[GridAppItem Debug] index =", index, "rowOffset =", rowOffset, "scrollOffset =", scrollOffset);
        }
    }

    StateLayer {
        id: stateLayer
        anchors.fill: parent
        radius: 20
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onContainsMouseChanged: {
            root.hovered = containsMouse;
            if (containsMouse) {
                gridView.currentIndex = index;
            }
        }

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.expanded = true;
            } else {
                clickAnim.start();
            }
        }
    }

    SequentialAnimation {
        id: clickAnim
        ScaleAnimator { target: mainContainer; from: 1.0; to: 0.9; duration: 80; easing.type: Easing.OutQuad }
        ScaleAnimator { target: mainContainer; from: 0.9; to: 1.0; duration: 120; easing.type: Easing.OutBack }
        ScriptAction {
            script: {
                Apps.launch(root.modelData);
                root.visibilities.launcher = false;
            }
        }
    }

    Item {
        id: mainContainer
        x: 4
        y: 4 + root.scrollOffset
        width: parent.width - 8
        height: parent.height - 8

        // Glassmorphic / Glowing card hover backdrop
        Rectangle {
            anchors.fill: parent
            radius: 16
            color: root.hovered || root.isCurrent ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : "transparent"
            border.color: root.hovered || root.isCurrent ? Qt.alpha(Colours.palette.m3onSurface, 0.12) : "transparent"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }

        // App Icon (macOS rounded square)
        Rectangle {
            id: icon
            width: 52
            height: 52
            radius: 12
            color: Colours.layer(Colours.palette.m3surfaceVariant, 0.5)
            border.color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
            border.width: 1

            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter

            scale: root.hovered || root.isCurrent ? 1.12 : 1.0

            Behavior on scale {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }

            IconImage {
                asynchronous: true
                source: Quickshell.iconPath(root.modelData?.icon, "image-missing")
                anchors.fill: parent
                anchors.margins: 7
            }
        }

        // App Name Label
        StyledText {
            id: name

            text: root.modelData?.name ?? ""
            // removed font.pointSize to avoid point/pixel conflict warnings
            font.weight: root.hovered || root.isCurrent ? Font.DemiBold : Font.Normal
            color: root.hovered || root.isCurrent ? (Colours.light ? "#000000" : "#ffffff") : Qt.alpha(Colours.light ? "#000000" : "#ffffff", 0.7)
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

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Favorite Apps Indicator (Top-Right Badge)
        Loader {
            id: favoriteBadge

            asynchronous: true
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 4
            anchors.rightMargin: 4
            active: root.modelData && Strings.testRegexList(GlobalConfig.launcher.favouriteApps, root.modelData.id)

            sourceComponent: Rectangle {
                width: 14
                height: 14
                radius: 7
                color: Colours.palette.m3primaryContainer

                MaterialIcon {
                    text: "favorite"
                    fill: 1
                    color: Colours.palette.m3primary
                    font.pointSize: 7
                    anchors.centerIn: parent
                }
            }
        }
    }

    Controls.Menu {
        id: contextMenu
        attachTo: mainContainer

        items: [
            Controls.MenuItem {
                readonly property bool isPinned: {
                    if (!root.modelData) return false;
                    const pApps = root.visibilities.pinnedApps || [];
                    for (let i = 0; i < pApps.length; i++) {
                        if (pApps[i] === root.modelData.id) return true;
                    }
                    return false;
                }
                text: isPinned ? qsTr("Remove from Panel") : qsTr("Add to Panel")
                icon: isPinned ? "keep_off" : "push_pin"
                
                onClicked: {
                    if (!root.modelData) return;
                    const id = root.modelData.id;
                    const rawPinned = root.visibilities.pinnedApps || [];
                    let pinned = [];
                    for (let i = 0; i < rawPinned.length; i++) {
                        pinned.push(rawPinned[i]);
                    }
                    
                    const idx = pinned.indexOf(id);
                    if (idx > -1) {
                        pinned.splice(idx, 1);
                        console.log("Unpinned", id, "Current pinned array:", pinned);
                    } else {
                        pinned.push(id);
                        console.log("Pinned", id, "Current pinned array:", pinned);
                    }
                    root.visibilities.pinnedApps = pinned;
                }
            }
        ]
    }
}
