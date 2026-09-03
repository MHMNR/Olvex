
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
    readonly property bool launcherVisible: root.visibilities.launcher

    function navigateUp() {
        if (list.currentList && list.currentList.decrementCurrentIndex)
            list.currentList.decrementCurrentIndex();
    }
    function navigateDown() {
        if (list.currentList && list.currentList.incrementCurrentIndex)
            list.currentList.incrementCurrentIndex();
    }
    function navigateLeft() {
        if (list.currentList && list.currentList.moveLeft)
            list.currentList.moveLeft();
    }
    function navigateRight() {
        if (list.currentList && list.currentList.moveRight)
            list.currentList.moveRight();
    }
    function navigateEnter() {
        if (list.currentList && list.currentList.count > 0 && list.currentList.currentItem && list.currentList.currentItem.select)
            list.currentList.currentItem.select();
    }

    function suspendLists() {
        list.suspendLists();
    }

    function resumeLists() {
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

        color: search.activeFocus 
            ? Qt.alpha(Colours.palette.m3onSurface, 0.18)
            : Qt.alpha(Colours.palette.m3onSurface, 0.12)
        radius: Tokens.rounding.full
        border.width: 0
        border.color: "transparent"

        Behavior on color { CAnim {} }

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
            color: search.activeFocus ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant

            Behavior on color { CAnim {} }
        }

        StyledTextField {
            id: search

            background: null

            anchors.left: searchIcon.right
            anchors.right: clearIcon.left
            anchors.leftMargin: Tokens.spacing.small
            anchors.rightMargin: Tokens.spacing.small

            topPadding: Tokens.padding.larger
            bottomPadding: Tokens.padding.larger

            placeholderText: qsTr("Search apps, math, terminal commands...")

            onAccepted: {
                const curList = list.currentList;
                if (!curList) return;
                const cur = curList.currentItem;
                if (!cur) return;

                if (curList.state === "calc") {
                    if (cur.onClicked)
                        cur.onClicked();
                    else if (cur.select)
                        cur.select();
                    return;
                }

                if (cur.modelData && cur.modelData.onClicked) {
                    cur.modelData.onClicked(curList);
                    return;
                }

                if (cur.modelData && cur.modelData.id) {
                    Apps.launch(cur.modelData);
                    root.visibilities.launcher = false;
                    Visibilities.launcherInterrupted = true;
                    return;
                }

                if (cur.select) {
                    cur.select();
                }
            }

            Keys.priority: Keys.BeforeItem
            Keys.onUpPressed: {
                if (list.currentList) {
                    if (list.currentList.showKeyboardHighlight)
                        list.currentList.showKeyboardHighlight();
                    if (list.currentList.decrementCurrentIndex)
                        list.currentList.decrementCurrentIndex();
                }
            }
            Keys.onDownPressed: {
                if (list.currentList) {
                    if (list.currentList.showKeyboardHighlight)
                        list.currentList.showKeyboardHighlight();
                    if (list.currentList.incrementCurrentIndex)
                        list.currentList.incrementCurrentIndex();
                }
            }
            Keys.onEscapePressed: {
                root.visibilities.launcher = false;
                event.accepted = true;
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left) {
                    if (list.currentList) {
                        if (list.currentList.showKeyboardHighlight)
                            list.currentList.showKeyboardHighlight();
                        if (list.currentList.moveLeft)
                            list.currentList.moveLeft();
                    }
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Right) {
                    if (list.currentList) {
                        if (list.currentList.showKeyboardHighlight)
                            list.currentList.showKeyboardHighlight();
                        if (list.currentList.moveRight)
                            list.currentList.moveRight();
                    }
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    const curList = list.currentList;
                    if (curList && curList.count > 0) {
                        const cur = curList.currentItem;
                        if (cur) {
                            if (curList.state === "calc" && cur.onClicked) {
                                cur.onClicked();
                            } else if (cur.modelData && cur.modelData.onClicked) {
                                cur.modelData.onClicked(curList);
                            } else if (cur.select) {
                                cur.select();
                            } else if (cur.modelData && cur.modelData.id) {
                                Apps.launch(cur.modelData);
                                root.visibilities.launcher = false;
                                Visibilities.launcherInterrupted = true;
                            }
                        }
                    }
                    event.accepted = true;
                }

                if (!GlobalConfig.launcher.vimKeybinds)
                    return;

                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                        if (list.currentList && list.currentList.incrementCurrentIndex)
                            list.currentList.incrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                        if (list.currentList && list.currentList.decrementCurrentIndex)
                            list.currentList.decrementCurrentIndex();
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    if (list.currentList && list.currentList.decrementCurrentIndex)
                        list.currentList.decrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Tab) {
                    if (list.currentList && list.currentList.incrementCurrentIndex)
                        list.currentList.incrementCurrentIndex();
                    event.accepted = true;
                }
            }

            Component.onCompleted: forceActiveFocus()

            Timer {
                id: focusTimer
                interval: 80
                repeat: true
                property int attempts: 0
                onTriggered: {
                    if (!root.launcherVisible || search.activeFocus || attempts >= 20) {
                        stop();
                    } else {
                        search.forceActiveFocus();
                        attempts++;
                    }
                }
            }

            Connections {
                function onLauncherChanged() {
                    if (!root.visibilities.launcher) {
                        search.text = "";
                        focusTimer.stop();
                    } else {
                        if (root.visibilities.launcherSearchText) {
                            search.text = root.visibilities.launcherSearchText;
                            root.visibilities.launcherSearchText = "";
                        }
                        search.forceActiveFocus();
                        if (!search.activeFocus) {
                            focusTimer.attempts = 0;
                            focusTimer.start();
                        }
                    }
                }

                function onPowermenuChanged() {
                    if (!root.visibilities.powermenu && root.launcherVisible) {
                        search.forceActiveFocus();
                        if (!search.activeFocus) {
                            focusTimer.attempts = 0;
                            focusTimer.start();
                        }
                    }
                }

                function onLauncherSearchTextChanged() {
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
