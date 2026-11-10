import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services
import ".."

// Step 5: summary + finish.
Item {
    id: root

    required property var wiz
    required property var backend

    signal editStepRequested(int stepIndex)
    signal finishRequested

    readonly property var summary: [
        { id: "scale", step: 1, icon: "monitor", label: qsTr("Interface scale"), value: Math.round(wiz.scale * 100) + "%" },
        { id: "theme", step: 2, icon: "contrast", label: qsTr("Theme"), value: wiz.themeModeNames[wiz.themeMode] },
        { id: "wallpaper", step: 2, icon: "wallpaper", label: qsTr("Wallpaper"), value: (wiz.wallpaperApplied && wiz.wallpaperIdx >= 0) ? wiz.wallpapers[wiz.wallpaperIdx].name : qsTr("Current wallpaper") },
        { id: "transparency", step: 2, icon: "opacity", label: qsTr("Transparency"), value: wiz.transparency ? qsTr("On") : qsTr("Off") },
        { id: "terminal", step: 3, icon: "terminal", label: qsTr("Default terminal"), value: wiz.selectedTerminal },
        { id: "browser", step: 3, icon: "language", label: qsTr("Default browser"), value: wiz.selectedBrowser }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 16

        Stagger {
            order: 0
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            spacing: 8

            StyledRect {
                id: badge

                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 64
                implicitHeight: 64
                radius: 32
                color: Colours.palette.m3primary
                scale: 0.4

                Component.onCompleted: pop.start()

                NumberAnimation {
                    id: pop

                    target: badge
                    property: "scale"
                    to: 1
                    duration: 520
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.6
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "check"
                    iconPointSize: 36
                    color: Colours.palette.m3onPrimary
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Olvex is ready for you")
                font.weight: Font.DemiBold
                textPointSize: Tokens.font.size.larger
                color: Colours.palette.m3onSurface
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("You can change any of this later in Settings.")
                textPointSize: Tokens.font.size.normal
                color: Colours.light ? Qt.alpha(Colours.palette.m3onSurface, 0.78) : Colours.palette.m3onSurfaceVariant
            }
        }

        // 2×3 Bento Grid of 6 interactive configuration summary cards
        Stagger {
            order: 1
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                columnSpacing: 14
                rowSpacing: 12

                Repeater {
                    model: root.summary

                    delegate: StyledRect {
                        id: card

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        implicitHeight: 74
                        radius: 16
                        border.width: 0
                        border.color: "transparent"
                        color: root.wiz.cardColor(2)

                        Behavior on color {
                            CAnim {}
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 14

                            // Squircle Icon Container
                            Item {
                                width: 40
                                height: 40
                                Layout.alignment: Qt.AlignVCenter

                                StyledRect {
                                    anchors.fill: parent
                                    radius: 12
                                    color: Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.12 : 0.16)
                                    border.width: 0
                                    border.color: "transparent"

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: card.modelData.icon
                                        iconPointSize: 20
                                        color: Colours.palette.m3primary
                                    }
                                }
                            }

                            // Label & Value
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: card.modelData.label
                                    elide: Text.ElideRight
                                    textPointSize: Tokens.font.size.small
                                    color: Colours.light
                                        ? Qt.alpha(Colours.palette.m3onSurface, 0.74)
                                        : Colours.palette.m3onSurfaceVariant
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: card.modelData.value
                                    elide: Text.ElideRight
                                    font.weight: Font.DemiBold
                                    textPointSize: Tokens.font.size.larger
                                    color: Colours.palette.m3onSurface
                                }
                            }

                            // Subtle edit indicator on right
                            MaterialIcon {
                                Layout.alignment: Qt.AlignVCenter
                                text: "edit"
                                iconPointSize: 16
                                color: Colours.light
                                    ? Qt.alpha(Colours.palette.m3onSurface, 0.35)
                                    : Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.40)
                            }
                        }

                        // Clicking card jumps straight to that step to edit it
                        StateLayer {
                            anchors.fill: parent
                            radius: card.radius
                            color: Colours.palette.m3primary
                            onClicked: root.editStepRequested(card.modelData.step)
                        }
                    }
                }
            }
        }

        Stagger {
            order: 2
            Layout.alignment: Qt.AlignHCenter

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 220
                Layout.preferredHeight: 50
            }
        }
    }
}

