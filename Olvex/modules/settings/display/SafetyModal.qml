import "."
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.services

FloatingWindow {
    id: root

    property bool active: DisplayManager.safetyActive
    property int secondsRemaining: DisplayManager.safetySecondsRemaining

    signal confirmClicked
    signal revertClicked

    readonly property int rExLarge: (Tokens.rounding && typeof Tokens.rounding.extraLarge !== "undefined") ? Tokens.rounding.extraLarge : 24
    readonly property int rFull: (Tokens.rounding && typeof Tokens.rounding.full !== "undefined") ? Tokens.rounding.full : 999
    readonly property int padLarge: (Tokens.padding && typeof Tokens.padding.large !== "undefined") ? Tokens.padding.large : 16
    readonly property int spLarge: (Tokens.spacing && typeof Tokens.spacing.large !== "undefined") ? Tokens.spacing.large : 16
    readonly property int spNormal: (Tokens.spacing && typeof Tokens.spacing.normal !== "undefined") ? Tokens.spacing.normal : 12
    readonly property int fLarge: (Tokens.font && typeof Tokens.font.size.large !== "undefined") ? Tokens.font.size.large : 16
    readonly property int fNormal: (Tokens.font && typeof Tokens.font.size.normal !== "undefined") ? Tokens.font.size.normal : 14
    readonly property int fSmall: (Tokens.font && typeof Tokens.font.size.small !== "undefined") ? Tokens.font.size.small : 12
    readonly property int fSmaller: (Tokens.font && typeof Tokens.font.size.smaller !== "undefined") ? Tokens.font.size.smaller : 11

    title: qsTr("Confirm Display Settings")
    color: "transparent"
    visible: active

    implicitWidth: 460
    implicitHeight: cardRect.implicitHeight + 16

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: {
            root.revertClicked();
            DisplayManager.revertSafetyApply();
        }
    }

    Shortcut {
        sequence: "Return"
        enabled: root.visible
        onActivated: {
            root.confirmClicked();
            DisplayManager.confirmSafetyApply();
        }
    }

    Shortcut {
        sequence: "Enter"
        enabled: root.visible
        onActivated: {
            root.confirmClicked();
            DisplayManager.confirmSafetyApply();
        }
    }

    // Modal Card
    StyledRect {
        id: cardRect
        anchors.centerIn: parent
        width: parent.width - 16
        implicitHeight: cardCol.implicitHeight + root.padLarge * 2
        radius: root.rExLarge
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.25)

        ColumnLayout {
            id: cardCol
            anchors.fill: parent
            anchors.margins: root.padLarge
            spacing: root.spLarge

            // Countdown Header Icon & Number
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: root.spNormal

                StyledRect {
                    implicitWidth: 54
                    implicitHeight: 54
                    radius: root.rFull
                    color: Colours.palette.m3primaryContainer

                    StyledText {
                        anchors.centerIn: parent
                        text: String(root.secondsRemaining)
                        font.weight: Font.Bold
                        textPointSize: root.fLarge
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }

                ColumnLayout {
                    spacing: 2
                    StyledText {
                        text: qsTr("Confirm Display Settings")
                        font.weight: Font.Bold
                        textPointSize: root.fNormal
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        text: qsTr("Testing new monitor configuration")
                        textPointSize: root.fSmaller
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            // Message text
            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Do you want to keep these changes? If your screen is blank or unsupported, settings will automatically revert in %1 seconds.").arg(root.secondsRemaining)
                color: Colours.palette.m3onSurfaceVariant
                textPointSize: root.fSmall
                wrapMode: Text.WordWrap
            }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: root.spNormal

                // Revert button
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: root.rFull
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 3)
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outline, 0.3)

                    StyledText {
                        anchors.centerIn: parent
                        text: qsTr("Revert Now")
                        font.weight: Font.Bold
                        textPointSize: root.fSmall
                        color: Colours.palette.m3onSurface
                    }

                    StateLayer {
                        radius: parent.radius
                        onClicked: {
                            root.revertClicked();
                            DisplayManager.revertSafetyApply();
                        }
                    }
                }

                // Keep Changes button
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: root.rFull
                    color: Colours.palette.m3primary

                    StyledText {
                        anchors.centerIn: parent
                        text: qsTr("Keep Changes")
                        font.weight: Font.Bold
                        textPointSize: root.fSmall
                        color: Colours.palette.m3onPrimary
                    }

                    StateLayer {
                        radius: parent.radius
                        onClicked: {
                            root.confirmClicked();
                            DisplayManager.confirmSafetyApply();
                        }
                    }
                }
            }
        }
    }
}
