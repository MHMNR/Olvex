
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
    readonly property int rounding: (typeof Config !== "undefined" && Config && Config.border) ? Config.border.drawerRounding : Tokens.rounding.large
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
    implicitHeight: listWrapper.height + padding * 2

    Item {
        id: listWrapper

        implicitWidth: list.implicitWidth
        implicitHeight: list.implicitHeight
        width: implicitWidth
        height: implicitHeight

        anchors.centerIn: parent

        ContentList {
            id: list

            content: root
            visibilities: root.visibilities
            panels: root.panels
            maxHeight: root.maxHeight - root.padding * 2
            padding: root.padding
            rounding: root.rounding
        }
    }
}
