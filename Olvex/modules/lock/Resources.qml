import QtQuick
import QtQuick.Layouts
import M3Shapes
import Olvex.Config
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services

ColumnLayout {
    id: root

    anchors.fill: parent
    anchors.margins: 14
    spacing: 8

    property bool activePoll: false
    Timer {
        interval: 900
        running: true
        onTriggered: root.activePoll = true
    }

    Item {
        visible: false
        Ref {
            service: SystemUsage
            active: root.activePoll && LockState.locked
        }
    }

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
                text: qsTr("System Resources")
                color: Colours.palette.m3onSurface
                textPointSize: Tokens.font.size.normal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                MaterialIcon {
                    text: "device_thermostat"
                    color: (SystemUsage.cpuTemp || 0) > 80 ? Colours.palette.m3error : Colours.palette.m3tertiary
                    iconPointSize: 13
                }

                StyledText {
                    text: `${Math.round(SystemUsage.cpuTemp || 0)}°C`
                    color: Colours.palette.m3onSurfaceVariant
                    font.family: Tokens.font.family.mono
                    textPointSize: Tokens.font.size.smaller - 2
                    font.weight: Font.Bold
                }
            }
        }
    }

    // ── Concentric M3 Progress Rings (Zero borders, built-in track arcs) ────
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Item {
            id: gaugeCanvas
            width: Math.min(parent.width, parent.height, 176)
            height: width
            anchors.centerIn: parent

            CircularProgress {
                id: ramRing
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                value: SystemUsage.memPerc
                padding: 0
                strokeWidth: 9
                fgColour: Colours.palette.m3primary
                bgColour: Qt.alpha(Colours.palette.m3primary, 0.14)
                Behavior on value { Anim { type: Anim.StandardLarge } }
            }

            CircularProgress {
                id: cpuRing
                anchors.centerIn: parent
                width: parent.width - 34
                height: parent.height - 34
                value: SystemUsage.cpuPerc
                padding: 0
                strokeWidth: 9
                fgColour: Colours.palette.m3secondary
                bgColour: Qt.alpha(Colours.palette.m3secondary, 0.14)
                Behavior on value { Anim { type: Anim.StandardLarge } }
            }

            CircularProgress {
                id: dskRing
                anchors.centerIn: parent
                width: parent.width - 68
                height: parent.height - 68
                value: SystemUsage.storagePerc
                padding: 0
                strokeWidth: 9
                fgColour: Colours.palette.m3tertiary
                bgColour: Qt.alpha(Colours.palette.m3tertiary, 0.14)
                Behavior on value { Anim { type: Anim.StandardLarge } }
            }

            // ── Center M3 Expressive Badge ──────────────────────────────────
            MaterialShape {
                anchors.centerIn: parent
                implicitSize: 64
                shape: MaterialShape.Cookie12Sided
                color: Qt.alpha(Colours.palette.m3primary, 0.14)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "monitoring"
                    color: Colours.palette.m3primary
                    iconPointSize: 26
                }
            }
        }
    }

    // ── Bottom 3 Color-Coded Telemetry Cards (RAM / CPU / DISK) ─────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MetricTile {
            label: qsTr("RAM")
            value: `${Math.round((SystemUsage.memPerc || 0) * 100)}%`
            subValue: SystemUsage.memTotal > 0
                ? `${((SystemUsage.memUsed || 0) / (1024 * 1024)).toFixed(1)}G`
                : "--"
            accent: Colours.palette.m3primary
        }

        MetricTile {
            label: qsTr("CPU")
            value: `${Math.round((SystemUsage.cpuPerc || 0) * 100)}%`
            subValue: `${Math.round(SystemUsage.cpuTemp || 0)}°C`
            accent: Colours.palette.m3secondary
        }

        MetricTile {
            label: qsTr("DISK")
            value: `${Math.round((SystemUsage.storagePerc || 0) * 100)}%`
            subValue: qsTr("used")
            accent: Colours.palette.m3tertiary
        }
    }

    component MetricTile: StyledRect {
        id: metric

        required property string label
        required property string value
        required property string subValue
        required property color accent

        Layout.fillWidth: true
        implicitHeight: 50
        radius: Tokens.rounding.small
        color: Colours.tileFill

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 7

            Rectangle {
                Layout.preferredWidth: 3
                Layout.fillHeight: true
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                radius: 1.5
                color: metric.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: metric.label
                        color: metric.accent
                        font.family: Tokens.font.family.mono
                        textPointSize: 8
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: metric.subValue
                        color: Colours.palette.m3onSurfaceVariant
                        font.family: Tokens.font.family.mono
                        textPointSize: 8
                        font.weight: Font.Medium
                    }
                }

                StyledText {
                    text: metric.value
                    color: Colours.palette.m3onSurface
                    font.family: Tokens.font.family.mono
                    textPointSize: Tokens.font.size.small
                    font.weight: Font.Black
                }
            }
        }
    }
}
