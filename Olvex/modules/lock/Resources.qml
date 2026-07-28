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
    spacing: Tokens.spacing.large

    // ── Hidden Ref to trigger service ────────────────────────────────────────
    Item {
        visible: false
        Ref {
            service: SystemUsage
            active: LockState.locked
        }
    }

    // ── Header ───────────────────────────────────────────────────────────────
    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.padding.small
        text: qsTr("SYSTEM RESOURCES")
        color: Colours.palette.m3outline
        font.family: Tokens.font.family.mono
        textPointSize: Tokens.font.size.smaller
        font.weight: 600
        horizontalAlignment: Text.AlignLeft
    }

    // ── Concentric Progress Rings ──────────────────────────────────────────
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignVCenter
        
        implicitHeight: 260

        // Background tracks (subtle circles)
        Rectangle {
            anchors.centerIn: parent
            width: 260; height: 260
            radius: 120
            color: "transparent"
            border.width: 8
            border.color: Qt.alpha(Colours.palette.m3outline, 0.08)
        }
        Rectangle {
            anchors.centerIn: parent
            width: 210; height: 210
            radius: 95
            color: "transparent"
            border.width: 8
            border.color: Qt.alpha(Colours.palette.m3outline, 0.08)
        }
        Rectangle {
            anchors.centerIn: parent
            width: 160; height: 160
            radius: 70
            color: "transparent"
            border.width: 8
            border.color: Qt.alpha(Colours.palette.m3outline, 0.08)
        }

        // Active Progress Rings
        CircularProgress {
            id: ramRing
            anchors.centerIn: parent
            width: 260; height: 260
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
            width: 210; height: 210
            value: SystemUsage.cpuPerc
            padding: 0
            strokeWidth: 8
            fgColour: Colours.palette.m3tertiary
            bgColour: "transparent"
            Behavior on value { Anim { type: Anim.StandardLarge } }
        }

        CircularProgress {
            id: dskRing
            anchors.centerIn: parent
            width: 160; height: 160
            value: SystemUsage.storagePerc
            padding: 0
            strokeWidth: 8
            fgColour: "#ffb74d" // Vibrant Amber/Orange for high contrast
            bgColour: "transparent"
            Behavior on value { Anim { type: Anim.StandardLarge } }
        }

        // Center Stats
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2
            
            RowLayout {
                spacing: 8
                StyledText {
                    text: "RAM"
                    color: ramRing.fgColour
                    font.family: Tokens.font.family.mono
                    textPointSize: 11
                    font.bold: true
                }
                StyledText {
                    text: ((SystemUsage.memPerc || 0) * 100).toFixed(0) + "%"
                    color: ramRing.fgColour
                    font.family: Tokens.font.family.mono
                    textPointSize: 11
                }
            }
            RowLayout {
                spacing: 8
                StyledText {
                    text: "CPU"
                    color: cpuRing.fgColour
                    font.family: Tokens.font.family.mono
                    textPointSize: 11
                    font.bold: true
                }
                StyledText {
                    text: ((SystemUsage.cpuPerc || 0) * 100).toFixed(0) + "%"
                    color: cpuRing.fgColour
                    font.family: Tokens.font.family.mono
                    textPointSize: 11
                }
            }
            RowLayout {
                spacing: 8
                StyledText {
                    text: "DSK"
                    color: dskRing.fgColour
                    font.family: Tokens.font.family.mono
                    textPointSize: 11
                    font.bold: true
                }
                StyledText {
                    text: ((SystemUsage.storagePerc || 0) * 100).toFixed(0) + "%"
                    color: dskRing.fgColour
                    font.family: Tokens.font.family.mono
                    textPointSize: 11
                }
            }
        }
    }

    // ── Bottom Status Row ───────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.padding.small
        
        ColumnLayout {
            spacing: 4
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: "memory"
                color: ramRing.fgColour
                iconPointSize: 18
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: "ACTIVE"
                color: Colours.palette.m3outline
                font.family: Tokens.font.family.mono
                textPointSize: 8
                font.bold: true
            }
        }

        Item { Layout.fillWidth: true }

        ColumnLayout {
            spacing: 4
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: "thermostat"
                color: cpuRing.fgColour
                iconPointSize: 18
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: Math.round(SystemUsage.cpuTemp) + "°C"
                color: Colours.palette.m3outline
                font.family: Tokens.font.family.mono
                textPointSize: 8
                font.bold: true
            }
        }

        Item { Layout.fillWidth: true }

        ColumnLayout {
            spacing: 4
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: "security"
                color: dskRing.fgColour
                iconPointSize: 18
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: "SECURE"
                color: Colours.palette.m3outline
                font.family: Tokens.font.family.mono
                textPointSize: 8
                font.bold: true
            }
        }
    }

    // ── Animations ───────────────────────────────────────────────────────────
    Behavior on implicitHeight { Anim {} }
}
