pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Olvex.Config
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property var lock

    anchors.fill: parent
    anchors.margins: Tokens.padding.large

    spacing: Tokens.spacing.smaller

    // ── Header row ──────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.smaller

        StyledText {
            Layout.fillWidth: true
            text: qsTr("NOTIFICATIONS")
            color: Qt.alpha(Colours.palette.m3outline, 0.6)
            font.family: Tokens.font.family.mono
            textPointSize: Tokens.font.size.smaller
            font.weight: 600
        }

        // Status dot
        Rectangle {
            implicitWidth:  8
            implicitHeight: 8
            radius: 4
            color: Notifs.list.length > 0 ? Colours.palette.m3secondary : Qt.alpha(Colours.palette.m3outline, 0.4)

            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    ClippingRectangle {
        id: clipRect

        Layout.fillWidth: true
        Layout.fillHeight: true

        radius: Tokens.rounding.small
        color: "transparent"

        Loader {
            asynchronous: true
            anchors.centerIn: parent
            active: opacity > 0
            opacity: Notifs.list.length > 0 && !GlobalConfig.lock.hideNotifs ? 0 : 1

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.large
                Layout.alignment: Qt.AlignHCenter

                Image {
                    Layout.alignment: Qt.AlignHCenter
                    source: Paths.absolutePath("root:/assets/bone.png")
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 112
                    sourceSize.height: 112
                    Layout.preferredWidth: 112
                    Layout.preferredHeight: 112

                    layer.enabled: true
                    layer.effect: Colouriser {
                        colorizationColor: Colours.palette.m3outlineVariant
                        opacity: 0.4
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: GlobalConfig.lock.hideNotifs ? qsTr("Unlock for Notifications") : qsTr("Systems clear")
                    color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
                    textPointSize: Tokens.font.size.large
                    font.family: Tokens.font.family.mono
                    font.weight: 500
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.StandardExtraLarge
                }
            }
        }

        StyledListView {
            anchors.fill: parent
            visible: !GlobalConfig.lock.hideNotifs
            spacing: Tokens.spacing.small
            clip: true

            model: ScriptModel {
                values: {
                    const list = Notifs.notClosed.map(n => [n.appName, null]);
                    return [...new Map(list).keys()];
                }
            }

            delegate: NotifGroup {}

            add: Transition {
                Anim {
                    property: "opacity"
                    from: 0
                    to: 1
                }
                Anim {
                    property: "scale"
                    from: 0
                    to: 1
                    type: Anim.DefaultSpatial
                }
            }

            remove: Transition {
                Anim {
                    property: "opacity"
                    to: 0
                }
                Anim {
                    property: "scale"
                    to: 0.6
                }
            }

            move: Transition {
                Anim {
                    properties: "opacity,scale"
                    to: 1
                }
                Anim {
                    property: "y"
                    type: Anim.DefaultSpatial
                }
            }

            displaced: Transition {
                Anim {
                    properties: "opacity,scale"
                    to: 1
                }
                Anim {
                    property: "y"
                    type: Anim.DefaultSpatial
                }
            }
        }
    }
}
