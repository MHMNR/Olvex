import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services

ColumnLayout {
    id: root

    anchors.fill: parent
    anchors.margins: Tokens.padding.large
    spacing: Tokens.spacing.normal

    property bool activePoll: false
    Timer {
        interval: 900
        running: true
        onTriggered: root.activePoll = true
    }

    // ── Hidden Ref to trigger service ────────────────────────────────────────
    Item {
        visible: false
        Ref {
            service: SystemUsage
            active: root.activePoll
        }
    }

    // ── Header ───────────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        StyledRect {
            implicitWidth: 24
            implicitHeight: 24
            radius: Tokens.rounding.small
            color: Qt.alpha(Colours.palette.m3primary, 0.15)

            MaterialIcon {
                anchors.centerIn: parent
                text: "analytics"
                color: Colours.palette.m3primary
                iconPointSize: 14
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("SYSTEM RESOURCES")
            color: Colours.palette.m3outline
            font.family: Tokens.font.family.mono
            textPointSize: Tokens.font.size.smaller
            font.weight: Font.Bold
            font.letterSpacing: 1
        }
    }

    // ── Concentric Progress Rings (Guaranteed 1:1 Proper Circles) ─────────────
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Item {
            id: gaugeCanvas
            width: Math.min(parent.width, 210)
            height: width
            anchors.centerIn: parent

            // ── Background Tracks (1:1 Perfect Circles: radius = width / 2) ──
            Rectangle {
                anchors.centerIn: parent
                width: 210; height: 210
                radius: 105
                color: "transparent"
                border.width: 8
                border.color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
            }
            Rectangle {
                anchors.centerIn: parent
                width: 165; height: 165
                radius: 82.5
                color: "transparent"
                border.width: 8
                border.color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
            }
            Rectangle {
                anchors.centerIn: parent
                width: 120; height: 120
                radius: 60
                color: "transparent"
                border.width: 8
                border.color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
            }

            // ── Active M3 Progress Rings ──────────────────────────────────────
            CircularProgress {
                id: ramRing
                anchors.centerIn: parent
                width: 210; height: 210
                value: SystemUsage.memPerc
                padding: 0
                strokeWidth: 8
                fgColour: Colours.palette.m3primary
                bgColour: "transparent"
                Behavior on value { Anim { type: Anim.StandardLarge } }
            }

            CircularProgress {
                id: cpuRing
                anchors.centerIn: parent
                width: 165; height: 165
                value: SystemUsage.cpuPerc
                padding: 0
                strokeWidth: 8
                fgColour: Colours.palette.m3secondary
                bgColour: "transparent"
                Behavior on value { Anim { type: Anim.StandardLarge } }
            }

            CircularProgress {
                id: dskRing
                anchors.centerIn: parent
                width: 120; height: 120
                value: SystemUsage.storagePerc
                padding: 0
                strokeWidth: 8
                fgColour: Colours.palette.m3tertiary
                bgColour: "transparent"
                Behavior on value { Anim { type: Anim.StandardLarge } }
            }

            // ── Center Typographic Reading ───────────────────────────────────
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2

                RowLayout {
                    spacing: 6
                    StyledText {
                        text: "RAM"
                        color: ramRing.fgColour
                        font.family: Tokens.font.family.mono
                        textPointSize: 10
                        font.bold: true
                    }
                    StyledText {
                        text: ((SystemUsage.memPerc || 0) * 100).toFixed(0) + "%"
                        color: Colours.palette.m3onSurface
                        font.family: Tokens.font.family.mono
                        textPointSize: 10
                        font.bold: true
                    }
                }
                RowLayout {
                    spacing: 6
                    StyledText {
                        text: "CPU"
                        color: cpuRing.fgColour
                        font.family: Tokens.font.family.mono
                        textPointSize: 10
                        font.bold: true
                    }
                    StyledText {
                        text: ((SystemUsage.cpuPerc || 0) * 100).toFixed(0) + "%"
                        color: Colours.palette.m3onSurface
                        font.family: Tokens.font.family.mono
                        textPointSize: 10
                        font.bold: true
                    }
                }
                RowLayout {
                    spacing: 6
                    StyledText {
                        text: "DSK"
                        color: dskRing.fgColour
                        font.family: Tokens.font.family.mono
                        textPointSize: 10
                        font.bold: true
                    }
                    StyledText {
                        text: ((SystemUsage.storagePerc || 0) * 100).toFixed(0) + "%"
                        color: Colours.palette.m3onSurface
                        font.family: Tokens.font.family.mono
                        textPointSize: 10
                        font.bold: true
                    }
                }
            }
        }
    }

    // ── Bottom Status Row ───────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.padding.small

        ColumnLayout {
            spacing: 2
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "memory"
                color: Colours.palette.m3primary
                iconPointSize: 18
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "ACTIVE"
                color: Colours.palette.m3outline
                font.family: Tokens.font.family.mono
                textPointSize: 8
                font.bold: true
            }
        }

        Item { Layout.fillWidth: true }

        ColumnLayout {
            spacing: 2
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "thermostat"
                color: Colours.palette.m3secondary
                iconPointSize: 18
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Math.round(SystemUsage.cpuTemp) + "°C"
                color: Colours.palette.m3outline
                font.family: Tokens.font.family.mono
                textPointSize: 8
                font.bold: true
            }
        }

        Item { Layout.fillWidth: true }

        ColumnLayout {
            spacing: 2
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "security"
                color: Colours.palette.m3tertiary
                iconPointSize: 18
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "SECURE"
                color: Colours.palette.m3outline
                font.family: Tokens.font.family.mono
                textPointSize: 8
                font.bold: true
            }
        }
    }
}
