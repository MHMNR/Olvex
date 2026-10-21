pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Olvex
import Olvex.Config
import qs.components
import qs.services

StackView {
    id: root

    required property PopoutState popouts
    required property QsMenuHandle trayItem

    implicitWidth: currentItem?.implicitWidth ?? 0
    implicitHeight: currentItem?.implicitHeight ?? 0

    initialItem: SubMenu {
        handle: root.trayItem
    }

    pushEnter: NoAnim {}
    pushExit: NoAnim {}
    popEnter: NoAnim {}
    popExit: NoAnim {}

    Component {
        id: subMenuComp

        SubMenu {}
    }

    component NoAnim: Transition {
        NumberAnimation {
            duration: 0
        }
    }

    component SubMenu: Column {
        id: menu

        required property QsMenuHandle handle
        property bool isSubMenu
        property bool shown

        padding: Tokens.padding.small
        spacing: 2

        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.8

        Component.onCompleted: shown = true
        StackView.onActivating: shown = true
        StackView.onDeactivating: shown = false
        StackView.onRemoved: destroy()

        Behavior on opacity {
            Anim {}
        }

        Behavior on scale {
            Anim {}
        }

        QsMenuOpener {
            id: menuOpener

            menu: menu.handle
        }

        Repeater {
            model: menuOpener.children

            StyledRect {
                id: item

                required property QsMenuEntry modelData

                visible: !!modelData
                implicitWidth: Tokens.sizes.bar.trayMenuWidth
                implicitHeight: !modelData || modelData.isSeparator ? 1 : children.implicitHeight + Tokens.padding.small * 2

                radius: Tokens.rounding.small
                color: !modelData || modelData.isSeparator ? Colours.palette.m3outlineVariant : "transparent"

                Loader {
                    id: children

                    asynchronous: true
                    anchors.fill: parent

                    active: !!item.modelData && !item.modelData.isSeparator

                    sourceComponent: Item {
                        implicitHeight: label.implicitHeight
                        StateLayer {
                            anchors.fill: parent

                            radius: item.radius
                            disabled: !item.modelData.enabled

                            onClicked: {
                                const entry = item.modelData;
                                if (entry.hasChildren)
                                    root.push(subMenuComp.createObject(null, {
                                        handle: entry,
                                        isSubMenu: true
                                    }));
                                else {
                                    item.modelData.triggered();
                                    root.popouts.hasCurrent = false;
                                }
                            }
                        }

                        Loader {
                            id: icon

                            asynchronous: true
                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.padding.small
                            anchors.verticalCenter: parent.verticalCenter

                            active: item.modelData.icon !== ""

                            sourceComponent: IconImage {
                                id: iconImg

                                asynchronous: true
                                width: label.implicitHeight
                                height: label.implicitHeight
                                implicitSize: label.implicitHeight
                                opacity: item.modelData.enabled ? 1.0 : (Colours.light ? 0.6 : 0.38)
                                mipmap: true

                                source: item.modelData.icon

                                Component.onCompleted: {
                                    if (iconImg.backer) {
                                        iconImg.backer.smooth = true;
                                        iconImg.backer.mipmap = true;
                                    }
                                }

                                readonly property real dpr: (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1
                                readonly property bool isAppHeader: item.index === 0

                                layer.enabled: Colours.light && !isAppHeader
                                layer.smooth: true
                                layer.mipmap: true
                                layer.textureSize: Qt.size(
                                    Math.round(iconImg.width * dpr * 2),
                                    Math.round(iconImg.height * dpr * 2)
                                )
                                layer.effect: MultiEffect {
                                    brightness: -0.38
                                    contrast: 0.30
                                }
                            }
                        }

                        StyledText {
                            id: label

                            anchors.left: icon.right
                            anchors.leftMargin: icon.active ? Tokens.spacing.small : Tokens.padding.small
                            anchors.verticalCenter: parent.verticalCenter

                            text: labelMetrics.elidedText
                            color: item.modelData.enabled
                                ? Colours.palette.m3onSurface
                                : (Colours.light ? Colours.palette.m3onSurfaceVariant : Qt.alpha(Colours.palette.m3onSurface, 0.38))
                        }

                        TextMetrics {
                            id: labelMetrics

                            text: item.modelData.text
                            font.pixelSize: label.resolvedPixelSize
                            font.family: label.font.family

                            elide: Text.ElideRight
                            elideWidth: root.Tokens.sizes.bar.trayMenuWidth - (icon.active ? icon.implicitWidth + label.anchors.leftMargin : 0) - (expand.active ? expand.implicitWidth + root.Tokens.spacing.normal : 0)
                        }

                        Loader {
                            id: expand

                            asynchronous: true
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: Tokens.padding.small

                            active: item.modelData.hasChildren

                            sourceComponent: MaterialIcon {
                                text: "chevron_right"
                                color: item.modelData.enabled
                                    ? Colours.palette.m3onSurface
                                    : (Colours.light ? Colours.palette.m3onSurfaceVariant : Qt.alpha(Colours.palette.m3onSurface, 0.38))
                            }
                        }
                    }
                }
            }
        }

        Loader {
            asynchronous: true
            active: menu.isSubMenu

            sourceComponent: Item {
                implicitWidth: Tokens.sizes.bar.trayMenuWidth
                implicitHeight: back.implicitHeight + Tokens.padding.small * 2

                StyledRect {
                    anchors.fill: parent

                    radius: Tokens.rounding.small
                    color: Colours.palette.m3secondaryContainer

                    StateLayer {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colours.palette.m3onSecondaryContainer
                        onClicked: root.pop()
                    }

                    Row {
                        id: back
                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.padding.small
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "chevron_left"
                            color: Colours.palette.m3onSecondaryContainer
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Back")
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }
                }
            }
        }
    }
}
