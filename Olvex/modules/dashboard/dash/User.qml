pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import M3Shapes
import Olvex.Config
import qs.components
import qs.components.effects
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property bool dashboardActive
    required property FileDialog facePicker

    readonly property color accentColor: Colours.palette.m3primary
    readonly property color textColor: Colours.palette.m3onSurface
    readonly property int avatarSize: 52
    readonly property real padH: 8
    readonly property real rowGap: 4
    readonly property real rowLineH: (root.avatarSize - root.rowGap) / 2
    readonly property var m3Emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]
    readonly property string displayName: (SysInfo.user || "user").toUpperCase()
    readonly property string avatarInitial: {
        const raw = SysInfo.user || "user";
        return raw.charAt(0).toUpperCase();
    }

    function openFacePicker() {
        root.visibilities.launcher = false;
        root.facePicker.open();
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.padH
        anchors.rightMargin: root.padH
        height: root.avatarSize
        spacing: 8

        Item {
            id: avatarHost

            Layout.preferredWidth: root.avatarSize
            Layout.preferredHeight: root.avatarSize
            Layout.maximumWidth: root.avatarSize

            scale: avatarLayer.containsMouse ? 1.03 : 1.0

            Behavior on scale {
                SpringAnimation {
                    spring: 4.2
                    damping: 0.70
                    mass: 1.0
                    epsilon: 0.01
                }
            }

            MaterialShape {
                id: avatarRing

                anchors.fill: parent
                z: 0
                implicitSize: root.avatarSize
                shape: MaterialShape.Cookie12Sided
                color: Colours.layer(Colours.palette.m3primaryContainer, 1)

                Anim on rotation {
                    running: root.dashboardActive
                    from: 360
                    to: 0
                    duration: 20000
                    easing.type: Easing.Linear
                    loops: Animation.Infinite
                }
            }

            Item {
                id: avatarMaskWrap

                anchors.fill: parent
                visible: false
                z: 0
                layer.enabled: true

                MaterialShape {
                    implicitSize: root.avatarSize
                    shape: MaterialShape.Cookie12Sided
                    color: "white"

                    Anim on rotation {
                        running: root.dashboardActive
                        from: 360
                        to: 0
                        duration: 20000
                        easing.type: Easing.Linear
                        loops: Animation.Infinite
                    }
                }
            }

            Item {
                id: avatarFallback

                anchors.fill: parent
                visible: pfp.status !== Image.Ready
                z: 1
                layer.enabled: true
                layer.effect: Mask {
                    maskSource: avatarMaskWrap
                }

                MaterialShape {
                    anchors.centerIn: parent
                    implicitSize: root.avatarSize * 0.72
                    shape: MaterialShape.Circle
                    color: Qt.alpha(Colours.palette.m3secondaryContainer, 0.55)
                }

                StyledText {
                    anchors.centerIn: parent
                    text: root.avatarInitial
                    color: avatarLayer.containsMouse ? Colours.palette.m3primary : Colours.palette.m3onPrimaryContainer
                    textPixelSize: 26
                    font.family: Tokens.font.family.sans
                    font.weight: Font.Bold
                    font.letterSpacing: -0.5

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: root.m3Emphasized
                        }
                    }
                }
            }

            CachingImage {
                id: pfp

                anchors.fill: parent
                z: 1
                path: AccountFaces.customPath
                layer.enabled: true
                layer.effect: Mask {
                    maskSource: avatarMaskWrap
                }
            }

            Connections {
                target: AccountFaces
                function onFaceChanged() {
                    pfp.reload();
                }
            }

            StateLayer {
                id: avatarLayer

                anchors.fill: parent
                radius: root.avatarSize / 2
                color: Colours.palette.m3onSurface
                z: 2
                onClicked: root.openFacePicker()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.avatarSize
            spacing: root.rowGap

            TitleRow {
                Layout.fillWidth: true
                Layout.preferredHeight: root.rowLineH
                text: root.displayName
            }

            MetaRow {
                Layout.fillWidth: true
                Layout.preferredHeight: root.rowLineH
                imageSource: SysInfo.osLogo
                fallbackIcon: "computer"
                text: SysInfo.osPrettyName || SysInfo.osName || "Linux"
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: root.avatarSize
            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.28)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.avatarSize
            spacing: root.rowGap

            MetaRow {
                Layout.fillWidth: true
                Layout.preferredHeight: root.rowLineH
                icon: "schedule"
                text: SysInfo.uptime || "—"
                mono: true
            }

            MetaRow {
                Layout.fillWidth: true
                Layout.preferredHeight: root.rowLineH
                icon: "select_window"
                text: SysInfo.wm || "—"
            }
        }
    }

    component TitleRow: Item {
        id: titleRow

        required property string text

        StyledText {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: titleRow.text
            color: Colours.palette.m3onSurface
            textPointSize: Tokens.font.size.small
            font.family: Tokens.font.family.sans
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    component MetaRow: Item {
        id: row

        required property string text
        property string icon: ""
        property string imageSource: ""
        property string fallbackIcon: "info"
        property bool mono: false

        RowLayout {
            anchors.fill: parent
            spacing: 5

            Item {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12

                ColouredIcon {
                    id: rowLogo

                    anchors.centerIn: parent
                    visible: row.imageSource.length > 0 && status === Image.Ready
                    source: row.imageSource
                    implicitSize: 12
                    colour: Qt.alpha(root.textColor, 0.72)
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !rowLogo.visible
                    text: row.icon || row.fallbackIcon
                    color: root.accentColor
                    iconPointSize: 12
                    fill: 1
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: row.text
                color: Colours.palette.m3onSurfaceVariant
                textPointSize: Tokens.font.size.smaller
                font.weight: Font.DemiBold
                font.family: row.mono ? Tokens.font.family.mono : Tokens.font.family.sans
                opacity: 0.82
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }
}
