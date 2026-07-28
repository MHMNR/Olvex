pragma ComponentBehavior: Bound

import QtQuick
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property var content
    required property DrawerVisibilities visibilities
    required property var panels
    required property real maxHeight
    required property StyledTextField search
    required property int padding
    required property int rounding

    readonly property int appsPaneHeight: Math.min(maxHeight, 490)
    readonly property var currentList: appList.item

    function suspendLists(): void {
        appList.item?.suspend?.();
    }

    function resumeLists(): void {
        appList.item?.resume?.();
    }

    Connections {
        target: visibilities
        function onLauncherChanged(): void {
            if (visibilities.launcher)
                resumeLists();
        }
    }

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom

    implicitWidth: appList.item?.implicitWidth ?? 590
    implicitHeight: appsPaneHeight

    width: implicitWidth
    height: implicitHeight

    clip: true

    Loader {
        id: appList

        active: true
        visible: true

        anchors.fill: parent

        sourceComponent: AppList {
            search: root.search
            visibilities: root.visibilities
            panels: root.panels
        }
    }

    Item {
        id: empty

        visible: root.currentList?.count === 0
        opacity: visible ? 1 : 0

        implicitWidth: row.implicitWidth + Tokens.padding.large * 2
        implicitHeight: row.implicitHeight + Tokens.padding.large * 2

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: row

            spacing: Tokens.spacing.normal
            anchors.centerIn: parent

            MaterialIcon {
                text: "manage_search"
                color: Colours.palette.m3onSurfaceVariant
                iconPointSize: Tokens.font.size.extraLarge

                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: qsTr("No results")
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.larger
                    font.weight: 500
                }

                StyledText {
                    text: qsTr("Try searching for something else")
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.normal
                }
            }
        }
    }
}