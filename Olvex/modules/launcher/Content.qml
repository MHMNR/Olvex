pragma ComponentBehavior: Bound

import QtQuick
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property var panels
    required property real maxHeight

    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.large

    function navigateUp() { list.currentList?.decrementCurrentIndex?.(); }
    function navigateDown() { list.currentList?.incrementCurrentIndex?.(); }
    function navigateLeft() {
        if (list.currentList?.moveLeft) {
            list.currentList.moveLeft();
        }
    }
    function navigateRight() {
        if (list.currentList?.moveRight) {
            list.currentList.moveRight();
        }
    }
    function navigateEnter() {
        if (list.currentList?.count > 0) {
            list.currentList?.currentItem?.select();
        }
    }

    function suspendLists(): void {
        list.suspendLists();
    }

    function resumeLists(): void {
        list.resumeLists();
    }

    implicitWidth: listWrapper.width + padding * 2
    implicitHeight: searchWrapper.height + listWrapper.height + padding * 2

    Item {
        id: listWrapper

        implicitWidth: list.implicitWidth
        implicitHeight: list.implicitHeight + root.padding
        width: implicitWidth
        height: implicitHeight

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: searchWrapper.top
        anchors.bottomMargin: root.padding

        ContentList {
            id: list

            content: root
            visibilities: root.visibilities
            panels: root.panels
            maxHeight: root.maxHeight - searchWrapper.implicitHeight - root.padding * 3
            search: search
            padding: root.padding
            rounding: root.rounding
        }
    }

    StyledRect {
        id: searchWrapper

        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        radius: Tokens.rounding.full

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding

        implicitHeight: Math.max(searchIcon.implicitHeight, search.implicitHeight, clearIcon.implicitHeight)

        MaterialIcon {
            id: searchIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: root.padding

            text: "search"
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledTextField {
            id: search

            anchors.left: searchIcon.right
            anchors.right: clearIcon.left
            anchors.leftMargin: Tokens.spacing.small
            anchors.rightMargin: Tokens.spacing.small

            topPadding: Tokens.padding.larger
            bottomPadding: Tokens.padding.larger

            placeholderText: qsTr("Type \"%1\" for commands").arg(GlobalConfig.launcher.actionPrefix)

            onAccepted: {
                const currentItem = list.currentList?.currentItem;
                if (currentItem) {
                    if (text.startsWith(GlobalConfig.launcher.actionPrefix)) {
                        if (text.startsWith(`${GlobalConfig.launcher.actionPrefix}calc `))
                            currentItem.onClicked();
                        else
                            currentItem.modelData.onClicked(list.currentList);
                    } else {
                        Apps.launch(currentItem.modelData);
                        root.visibilities.launcher = false;
                        Visibilities.launcherInterrupted = true;
                    }
                }
            }

            Keys.priority: Keys.BeforeItem
            Keys.onUpPressed: {
                list.currentList?.showKeyboardHighlight?.();
                list.currentList?.decrementCurrentIndex();
            }
            Keys.onDownPressed: {
                list.currentList?.showKeyboardHighlight?.();
                list.currentList?.incrementCurrentIndex();
            }
            Keys.onEscapePressed: {
                root.visibilities.launcher = false;
                event.accepted = true;
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left) {
                    list.currentList?.showKeyboardHighlight?.();
                    list.currentList?.moveLeft?.();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Right) {
                    list.currentList?.showKeyboardHighlight?.();
                    list.currentList?.moveRight?.();
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (list.currentList?.count > 0) {
                        list.currentList?.currentItem?.select();
                    }
                    event.accepted = true;
                }

                if (!GlobalConfig.launcher.vimKeybinds)
                    return;

                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                        list.currentList?.incrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                        list.currentList?.decrementCurrentIndex();
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Tab) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                }
            }

            Component.onCompleted: forceActiveFocus()

            Timer {
                id: focusTimer
                interval: 50
                repeat: true
                property int attempts: 0
                onTriggered: {
                    if (search.activeFocus || attempts >= 20) {
                        stop();
                    } else {
                        search.forceActiveFocus();
                        attempts++;
                    }
                }
            }

            Connections {
                function onLauncherChanged(): void {
                    if (!root.visibilities.launcher) {
                        search.text = "";
                        focusTimer.stop();
                    } else {
                        if (root.visibilities.launcherSearchText) {
                            search.text = root.visibilities.launcherSearchText;
                            root.visibilities.launcherSearchText = "";
                        }
                        search.forceActiveFocus();
                        focusTimer.attempts = 0;
                        focusTimer.start();
                    }
                }

                function onSessionChanged(): void {
                    if (!root.visibilities.session) {
                        search.forceActiveFocus();
                        focusTimer.attempts = 0;
                        focusTimer.start();
                    }
                }

                function onLauncherSearchTextChanged(): void {
                    if (root.visibilities.launcherSearchText) {
                        search.text = root.visibilities.launcherSearchText;
                        root.visibilities.launcherSearchText = "";
                    }
                }

                target: root.visibilities
            }
        }

        MaterialIcon {
            id: clearIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: root.padding

            width: search.text ? implicitWidth : implicitWidth / 2
            opacity: {
                if (!search.text)
                    return 0;
                if (mouse.pressed)
                    return 0.7;
                if (mouse.containsMouse)
                    return 0.8;
                return 1;
            }

            text: "close"
            color: Colours.palette.m3onSurfaceVariant

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: search.text ? Qt.PointingHandCursor : undefined

                onClicked: search.text = ""
            }

            Behavior on width {
                Anim {
                    type: Anim.StandardSmall
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.StandardSmall
                }
            }
        }
    }
}
