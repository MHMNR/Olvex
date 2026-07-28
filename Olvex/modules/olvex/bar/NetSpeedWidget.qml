pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property var netSpeedConfig: GlobalConfig.bar?.netSpeed ?? null
    readonly property color colour: Colours.palette.m3tertiary
    readonly property bool showIcons: netSpeedConfig?.showIcons ?? true
    readonly property bool showBackground: netSpeedConfig?.background ?? false
    readonly property int fontSize: netSpeedConfig?.fontSize ?? 11
    readonly property int maxDigits: netSpeedConfig?.maxDigits ?? 0
    readonly property int padding: showBackground ? Tokens.padding.normal : Tokens.padding.small

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, showBackground ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    Component.onCompleted: NetworkUsage.refCount++
    Component.onDestruction: NetworkUsage.refCount--

    Column {
        id: layout

        anchors.centerIn: parent
        spacing: 0

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -2

            MaterialIcon {
                visible: root.showIcons
                text: "upload"
                font.pointSize: Math.max(6, root.fontSize - 2)
                color: root.colour
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                readonly property var fmt: NetworkUsage.formatBytes(NetworkUsage.uploadSpeed)
                readonly property int decimals: fmt.unit.startsWith("B") ? 0 : root.maxDigits
                text: `${fmt.value.toFixed(decimals)}${fmt.unit.charAt(0)}`
                font.pointSize: root.fontSize
                font.family: GlobalConfig.appearance.font.family.sans
                color: root.colour
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Item {
            width: 1
            height: Tokens.spacing.small
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            width: parent.width * 0.6
            color: root.colour
            opacity: 0.2
        }

        Item {
            width: 1
            height: Tokens.spacing.small
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -2

            MaterialIcon {
                visible: root.showIcons
                text: "download"
                font.pointSize: Math.max(6, root.fontSize - 2)
                color: root.colour
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                readonly property var fmt: NetworkUsage.formatBytes(NetworkUsage.downloadSpeed)
                readonly property int decimals: fmt.unit.startsWith("B") ? 0 : root.maxDigits
                text: `${fmt.value.toFixed(decimals)}${fmt.unit.charAt(0)}`
                font.pointSize: root.fontSize
                font.family: GlobalConfig.appearance.font.family.sans
                color: root.colour
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
