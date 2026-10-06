import ".."
import "../ui"
import "."
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import Olvex.Config
import qs.services

Item {
    id: root

    property Session session: null
    property Component leftContent: null
    property Component rightContent: null
    property real leftWidthRatio: 0.24
    property int leftMinimumWidth: 220
    property int leftMaximumWidth: 280
    property var leftLoaderProperties: ({})
    property var rightLoaderProperties: ({})
    property alias leftLoader: leftLoader
    property alias rightLoader: rightLoader

    property bool collapsed: false
    property real collapsedWidth: 64
    signal toggleCollapsed()

    readonly property real computedExpandedWidth: Math.max(root.leftMinimumWidth, Math.min(root.leftMaximumWidth, Math.floor(root.width * root.leftWidthRatio)))

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
            anchors.rightMargin: Tokens.padding.small
            radius: Tokens.rounding.large
            color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.15)
            border.width: 1
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

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftPane.right
        anchors.right: parent.right

        Rectangle {
            id: rightCard
            anchors.fill: parent
            anchors.margins: Tokens.padding.normal
            anchors.leftMargin: Tokens.padding.small
            anchors.rightMargin: Tokens.padding.normal
            radius: Tokens.rounding.large
            color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.15)
            border.width: 1

            Loader {
                id: rightLoader
                anchors.fill: parent
                anchors.margins: Tokens.padding.normal
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
