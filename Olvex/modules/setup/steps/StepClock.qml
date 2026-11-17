import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.widgets
import qs.components.widgets.clocks
import qs.services
import ".."

// Step 3: Shared clock selection for Desktop & Lockscreen.
Item {
    id: root

    required property var wiz
    required property var backend

    readonly property string currentClockStyle: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.style)
        ? GlobalConfig.background.desktopClock.style
        : "olvex-signature"
    readonly property int currentStyleVariant: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.styleVariant !== undefined)
        ? GlobalConfig.background.desktopClock.styleVariant
        : 0

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.topMargin: 8
        anchors.bottomMargin: 12
        spacing: 12

        StepHeader {
            order: 0
            title: qsTr("Pick your clock")
            subtitle: qsTr("Shared across desktop and lockscreen. You can change it anytime in Settings.")
        }

        // Scrollable 3-column clock grid
        StyledFlickable {
            id: gridFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: clockGrid.implicitHeight

            GridLayout {
                id: clockGrid
                width: gridFlick.width
                columns: 3
                columnSpacing: Tokens.spacing.normal
                rowSpacing: Tokens.spacing.normal

                readonly property real cardWidth: Math.max(130, Math.floor((width - columnSpacing * 2) / 3))

                Repeater {
                    model: ClockCatalog.styles

                    StyledRect {
                        id: styleCard
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: root.currentClockStyle === modelData.id

                        Layout.fillWidth: false
                        Layout.preferredWidth: clockGrid.cardWidth
                        Layout.maximumWidth: clockGrid.cardWidth
                        Layout.minimumWidth: clockGrid.cardWidth
                        Layout.preferredHeight: 146
                        radius: Tokens.rounding.large
                        border.width: 0
                        border.color: "transparent"
                        color: isSelected
                            ? Qt.alpha(Colours.palette.m3primary, 0.16)
                            : (cardHover.hovered ? root.wiz.cardHoverColor(3) : root.wiz.cardColor(2))

                        Behavior on color { CAnim { duration: Tokens.anim.durations.small } }

                        HoverHandler { id: cardHover }

                        StateLayer {
                            anchors.fill: parent
                            radius: styleCard.radius
                            color: styleCard.isSelected ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            onClicked: {
                                if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                                    if (GlobalConfig.background.desktopClock.style !== styleCard.modelData.id) {
                                        GlobalConfig.background.desktopClock.style = styleCard.modelData.id;
                                        GlobalConfig.background.desktopClock.styleVariant = 0;
                                    }
                                    GlobalConfig.save();
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: Tokens.spacing.small

                            StyledRect {
                                id: previewBox
                                Layout.fillWidth: true
                                Layout.preferredHeight: 74
                                radius: Tokens.rounding.small
                                color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
                                border.width: 0
                                border.color: "transparent"
                                clip: true

                                SharedClock {
                                    anchors.centerIn: parent
                                    clockStyle: styleCard.modelData.id
                                    styleVariant: styleCard.isSelected ? root.currentStyleVariant : 0
                                    clockScale: 0.72
                                    showDatePill: true
                                    shadowEnabled: false
                                    syncFromLockState: false
                                    primaryColor: Colours.palette.m3primary
                                    secondaryColor: Colours.palette.m3secondary
                                    tertiaryColor: Colours.palette.m3tertiary
                                    onSurfaceColor: Colours.palette.m3onSurface
                                    transformOrigin: Item.Center
                                    scale: {
                                        const w = Math.max(1, implicitWidth);
                                        const h = Math.max(1, implicitHeight);
                                        const bw = Math.max(1, previewBox.width - 10);
                                        const bh = Math.max(1, previewBox.height - 8);
                                        return Math.min(1.0, bw / w, bh / h);
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                StyledText {
                                    Layout.fillWidth: true
                                    text: styleCard.modelData.name
                                    textPointSize: Tokens.font.size.small
                                    font.weight: Font.Medium
                                    color: styleCard.isSelected ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                }

                                MaterialIcon {
                                    visible: styleCard.isSelected
                                    text: "check_circle"
                                    iconPointSize: 15
                                    fill: 1
                                    color: Colours.palette.m3primary
                                }
                            }
                        }
                    }
                }
            }
        }

        // Variant Selector Chips (when selected clock has > 1 variant)
        Flow {
            id: variantRow
            readonly property var variantsList: ClockCatalog.entryFor(root.currentClockStyle).variants || []
            visible: variantsList.length > 1
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: variantRow.variantsList

                StyledRect {
                    id: varChip
                    required property string modelData
                    required property int index

                    readonly property bool active: root.currentStyleVariant === index
                    implicitWidth: varText.implicitWidth + 22
                    implicitHeight: 30
                    radius: height / 2
                    border.width: 0
                    border.color: "transparent"
                    color: active ? Colours.palette.m3primary : root.wiz.cardColor(2)

                    Behavior on color { CAnim {} }

                    StateLayer {
                        anchors.fill: parent
                        radius: varChip.radius
                        color: varChip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        onClicked: {
                            if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                                GlobalConfig.background.desktopClock.styleVariant = varChip.index;
                                GlobalConfig.save();
                            }
                        }
                    }

                    StyledText {
                        id: varText
                        anchors.centerIn: parent
                        text: varChip.modelData
                        textPointSize: Tokens.font.size.small
                        font.weight: varChip.active ? Font.DemiBold : Font.Normal
                        color: varChip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    }
                }
            }
        }
    }
}

