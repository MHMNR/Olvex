import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services
import ".."

// Step 1: display + scale (mock data until the monitors socket is connected).
Item {
    id: root

    required property var wiz
    required property var backend

    readonly property var monitor: (backend.connected && backend.monitors && backend.monitors.length > 0) ? backend.monitors[0] : wiz.mockMonitors[0]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 18

        StepHeader {
            order: 0
            title: qsTr("Display & scale")
            subtitle: qsTr("Pick a UI size that is comfortable on your screen.")
        }

        Stagger {
            order: 1
            Layout.fillWidth: true

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 72
                radius: 16
                color: root.wiz.cardColor(2)
                border.width: 0
                border.color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 16

                    MaterialIcon {
                        text: "monitor"
                        iconPointSize: 30
                        color: Colours.palette.m3primary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: root.monitor.name
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.normal
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            text: `${root.monitor.width} × ${root.monitor.height} @ ${Math.round(root.monitor.refreshRate)}Hz`
                            textPointSize: Tokens.font.size.smaller
                            color: Colours.light ? Qt.alpha(Colours.palette.m3onSurface, 0.74) : Colours.palette.m3onSurfaceVariant
                        }
                    }

                    StyledRect {
                        visible: !root.backend.connected
                        implicitHeight: 26
                        implicitWidth: sample.implicitWidth + 18
                        radius: 13
                        color: Colours.light ? Qt.alpha(Colours.palette.m3tertiary, 0.15) : Qt.alpha(Colours.palette.m3tertiary, 0.16)
                        border.width: 0
                        border.color: "transparent"

                        StyledText {
                            id: sample

                            anchors.centerIn: parent
                            text: qsTr("Sample data")
                            textPointSize: Tokens.font.size.smaller
                            color: Colours.light ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3tertiary
                            font.weight: Colours.light ? Font.Medium : Font.Normal
                        }
                    }
                }
            }
        }

        Stagger {
            order: 2
            Layout.fillWidth: true
            spacing: 10

            StyledText {
                text: qsTr("Interface scale")
                font.weight: Font.Medium
                textPointSize: Tokens.font.size.normal
                color: Colours.palette.m3onSurface
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: [1.0, 1.25, 1.5, 1.75, 2.0]

                    delegate: StyledRect {
                        id: pill

                        required property real modelData
                        readonly property bool selected: Math.abs(root.wiz.scale - modelData) < 0.01

                        Layout.fillWidth: true
                        implicitHeight: 44
                        radius: 22
                        color: selected ? Colours.palette.m3primary : root.wiz.cardColor(2)
                        border.width: 0
                        border.color: "transparent"

                        Behavior on color {
                            CAnim {}
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: Math.round(pill.modelData * 100) + "%"
                            font.weight: pill.selected ? Font.DemiBold : Font.Normal
                            textPointSize: Tokens.font.size.normal
                            color: pill.selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        }

                        StateLayer {
                            anchors.fill: parent
                            radius: pill.radius
                            color: pill.selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            onClicked: {
                                root.wiz.scale = pill.modelData;
                                root.backend.applyScale(root.monitor.name, pill.modelData);
                            }
                        }
                    }
                }
            }
        }

        Stagger {
            order: 3
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                color: Colours.palette.m3surfaceContainerLow
                clip: true

                Column {
                    anchors.centerIn: parent
                    spacing: 10 * root.wiz.scale

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "visibility"
                        iconPointSize: 26 * root.wiz.scale
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("This is how text will look")
                        font.weight: Font.DemiBold
                        textPointSize: Tokens.font.size.normal * root.wiz.scale
                        color: Colours.palette.m3onSurface

                        Behavior on textPointSize {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Bar, drawers and menus follow this size.")
                        textPointSize: Tokens.font.size.smaller * root.wiz.scale
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
