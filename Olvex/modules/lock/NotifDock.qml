
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import M3Shapes
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
    anchors.margins: 14

    spacing: 8

    // ── Signature M3 Header Pill ─────────────────────────────────────────────
    StyledRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: Tokens.rounding.small
        color: Colours.tileFill

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 3
                Layout.fillHeight: true
                Layout.topMargin: 7
                Layout.bottomMargin: 7
                radius: 1.5
                color: Colours.palette.m3primary
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: qsTr("Notifications")
                color: Colours.palette.m3onSurface
                textPointSize: Tokens.font.size.normal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: GlobalConfig.lock.hideNotifs
                    ? qsTr("Hidden")
                    : (Notifs.notClosed.length > 0 ? qsTr("%1 new").arg(Notifs.notClosed.length) : qsTr("Clear"))
                color: Notifs.notClosed.length > 0 && !GlobalConfig.lock.hideNotifs
                    ? Colours.palette.m3primary
                    : Colours.palette.m3onSurfaceVariant
                font.family: Tokens.font.family.mono
                textPointSize: Tokens.font.size.smaller - 2
                font.weight: Font.Bold
            }
        }
    }

    StyledClippingRect {
        id: clipRect

        Layout.fillWidth: true
        Layout.fillHeight: true

        radius: Tokens.rounding.small
        color: "transparent"

        Loader {
            asynchronous: true
            anchors.fill: parent
            active: opacity > 0
            opacity: Notifs.notClosed.length > 0 && !GlobalConfig.lock.hideNotifs ? 0 : 1

            sourceComponent: StyledRect {
                radius: Tokens.rounding.small
                color: Colours.tileFill

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 24, 240)
                    spacing: 8

                    MaterialShape {
                        Layout.alignment: Qt.AlignHCenter
                        implicitSize: 64
                        shape: MaterialShape.Cookie12Sided
                        color: Qt.alpha(Colours.palette.m3primary, 0.16)

                        Image {
                            anchors.centerIn: parent
                            source: Paths.absolutePath("root:/assets/bone.png")
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: 28
                            sourceSize.height: 28
                            width: 28
                            height: 28

                            layer.enabled: true
                            layer.effect: Colouriser {
                                colorizationColor: Colours.palette.m3primary
                            }
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: GlobalConfig.lock.hideNotifs ? qsTr("Notifications hidden") : qsTr("All caught up")
                        color: Colours.palette.m3onSurface
                        textPointSize: Tokens.font.size.normal
                        font.weight: Font.DemiBold
                    }
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
