import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import "../../../components/widgets"
import "../../../components/widgets/clocks"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

ColumnLayout {
    id: root
    
    property Session session
    spacing: Tokens.spacing.large
    opacity: 0.0
    transform: Translate { y: 20; id: yTrans }

    readonly property var placementStrategies: ["leastBusy", "mostBusy", "fixed"]
    readonly property var strategyLabels: [qsTr("Auto (Least Busy)"), qsTr("Auto (Most Busy)"), qsTr("Fixed (Manual)")]
    readonly property var clockPositions: ["middle-center", "top-left", "top-center", "top-right", "middle-left", "middle-right", "bottom-left", "bottom-center", "bottom-right"]

    function idxOf(list, val) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === val) return i;
        }
        return 0;
    }

    Component.onCompleted: {
        revealAnim.start();
    }

    ParallelAnimation {
        id: revealAnim
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: yTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutCubic }
    }

    readonly property string currentClockStyle: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.style)
        ? GlobalConfig.background.desktopClock.style
        : "classic"
    readonly property int currentStyleVariant: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.styleVariant !== undefined)
        ? GlobalConfig.background.desktopClock.styleVariant
        : 0
    property bool catalogExpanded: false

    Section {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.small
        title: qsTr("Clock Style")
        description: qsTr("Choose clock design shared across desktop and lockscreen")
        icon: "watch"

        // Unified Clock Style Picker Card (matching Cursor / Icon Theme Connected Stack)
        StyledRect {
            id: clockStyleCard
            Layout.fillWidth: true
            implicitWidth: parent ? parent.width : 0
            width: parent ? parent.width : implicitWidth

            property bool isFirstInGroup: false
            property bool isLastInGroup: false
            property bool isSingleInGroup: true

            readonly property real topR: (isSingleInGroup || isFirstInGroup) ? 22 : 6
            readonly property real bottomR: (isSingleInGroup || isLastInGroup) ? 22 : 6
            topLeftRadius: topR
            topRightRadius: topR
            bottomLeftRadius: bottomR
            bottomRightRadius: bottomR

            color: Colours.palette.m3surfaceContainerHigh
            border.width: 0
            border.color: "transparent"
            clip: true

            implicitHeight: Math.max(68, cardContentLayout.implicitHeight + 28)

            ColumnLayout {
                id: cardContentLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 0

                // Clickable Header Row (M3 List Item: Title + Neutral Supporting Text + Trailing Value Chip + Chevron)
                Item {
                    id: catalogToggleRow
                    Layout.fillWidth: true
                    implicitHeight: Math.max(40, headerTextCol.implicitHeight)

                    HoverHandler { id: toggleHover }

                    StateLayer {
                        anchors.fill: parent
                        anchors.topMargin: -14
                        anchors.bottomMargin: -14
                        anchors.leftMargin: -20
                        anchors.rightMargin: -20
                        radius: 22
                        color: Colours.palette.m3onSurface
                        onClicked: root.catalogExpanded = !root.catalogExpanded
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: Tokens.spacing.normal

                        ColumnLayout {
                            id: headerTextCol
                            Layout.fillWidth: true
                            spacing: 4

                            StyledText {
                                text: qsTr("Clock Faces")
                                font.weight: Font.Medium
                                textPointSize: Tokens.font.size.normal
                                color: Colours.palette.m3onSurface
                            }

                            StyledText {
                                text: qsTr("Choose from %1 styles for desktop & lockscreen").arg(ClockCatalog.styles.length)
                                textPointSize: Tokens.font.size.small
                                color: Colours.light
                                    ? Qt.alpha(Colours.palette.m3onSurface, 0.76)
                                    : Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Trailing M3 Tonal Value Chip (matches OptionPicker pill below)
                        StyledRect {
                            readonly property var activeEntry: ClockCatalog.entryFor(root.currentClockStyle)
                            readonly property var activeVariants: activeEntry.variants || []
                            readonly property string activeLabel: activeVariants.length > 1
                                ? qsTr("%1 • %2").arg(activeEntry.name).arg(activeVariants[root.currentStyleVariant] || activeVariants[0])
                                : activeEntry.name

                            implicitWidth: activeChipText.implicitWidth + 24
                            implicitHeight: 30
                            radius: height / 2
                            border.width: 0
                            border.color: "transparent"
                            color: Colours.palette.m3secondaryContainer

                            StyledText {
                                id: activeChipText
                                anchors.centerIn: parent
                                text: parent.activeLabel
                                textPointSize: Tokens.font.size.small
                                font.weight: Font.Medium
                                color: Colours.palette.m3onSecondaryContainer
                            }
                        }

                        MaterialIcon {
                            text: "expand_more"
                            iconPointSize: Tokens.font.size.large
                            color: toggleHover.hovered ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                            rotation: root.catalogExpanded ? 180 : 0
                            Behavior on rotation {
                                Anim { duration: Tokens.anim.durations.normal }
                            }
                        }
                    }
                }

                Item {
                    id: catalogReveal
                    Layout.fillWidth: true
                    clip: true
                    implicitHeight: root.catalogExpanded ? (catalogContent.implicitHeight + 14) : 0
                    opacity: root.catalogExpanded ? 1.0 : 0.0
                    visible: implicitHeight > 0

                    Behavior on implicitHeight {
                        Anim { duration: Tokens.anim.durations.normal }
                    }
                    Behavior on opacity {
                        Anim { duration: Tokens.anim.durations.small }
                    }

                    ColumnLayout {
                        id: catalogContent
                        y: 14
                        width: parent.width
                        spacing: 12

                        GridLayout {
                            id: clockGrid
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: Tokens.spacing.normal
                            rowSpacing: Tokens.spacing.normal

                            readonly property real cardWidth: Math.max(140, Math.floor((clockStyleCard.width - 32 - columnSpacing * 2) / 3))

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
                                    Layout.preferredHeight: 164
                                    radius: Tokens.rounding.large
                                    border.width: 0
                                    border.color: "transparent"
                                    color: isSelected
                                        ? Qt.alpha(Colours.palette.m3primary, 0.14)
                                        : (cardHover.hovered ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 1) : Colours.palette.m3surfaceContainer)

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
                                        anchors.margins: 14
                                        spacing: Tokens.spacing.small

                                        // Inner Preview Well (matching Cursor / Icon Theme cards)
                                        StyledRect {
                                            id: previewBox
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 82
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
                                                    const bw = Math.max(1, previewBox.width - 12);
                                                    const bh = Math.max(1, previewBox.height - 10);
                                                    return Math.min(1.0, bw / w, bh / h);
                                                }
                                            }
                                        }

                                        Item { Layout.fillHeight: true }

                                        // Clock Name + Checkmark + Variant Subtitle
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: styleCard.modelData.name
                                                    textPointSize: Tokens.font.size.normal
                                                    font.weight: Font.Medium
                                                    color: styleCard.isSelected ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                                    elide: Text.ElideRight
                                                }

                                                MaterialIcon {
                                                    visible: styleCard.isSelected
                                                    text: "check_circle"
                                                    iconPointSize: 16
                                                    fill: 1
                                                    color: Colours.palette.m3primary
                                                }
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                readonly property var varsList: styleCard.modelData.variants || []
                                                text: styleCard.isSelected && varsList.length > 1
                                                    ? (varsList[root.currentStyleVariant] || varsList[0])
                                                    : (varsList.length > 1 ? qsTr("%1 variants").arg(varsList.length) : qsTr("Standard"))
                                                textPointSize: Tokens.font.size.small
                                                color: Colours.palette.m3onSurfaceVariant
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Variant Selector Chips (shown when selected clock style has multiple variants)
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
                                    implicitWidth: varText.implicitWidth + 24
                                    implicitHeight: 32
                                    radius: height / 2
                                    border.width: 0
                                    border.color: "transparent"
                                    color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainer

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
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Desktop Clock")
        description: qsTr("Configure desktop clock widget and automatic positioning")
        icon: "schedule"

        SettingRow {
            title: qsTr("Show clock")
            description: qsTr("Display time and date widget on the desktop wallpaper")
            StyledSwitch {
                checked: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.enabled !== undefined) ? GlobalConfig.background.desktopClock.enabled : false
                onToggled: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                        GlobalConfig.background.desktopClock.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Placement strategy")
            description: qsTr("Auto-place in wallpaper's empty area or keep fixed")
            OptionPicker {
                model: root.strategyLabels
                currentIndex: root.idxOf(root.placementStrategies, (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.placementStrategy) ? GlobalConfig.background.desktopClock.placementStrategy : "fixed")
                onSelected: i => {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                        GlobalConfig.background.desktopClock.placementStrategy = root.placementStrategies[i];
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            visible: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.placementStrategy === "fixed")
            title: qsTr("Clock position")
            description: qsTr("Where the clock is fixed on the desktop")
            OptionPicker {
                model: root.clockPositions
                currentIndex: root.idxOf(root.clockPositions, (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.position) ? GlobalConfig.background.desktopClock.position : "middle-center")
                onSelected: i => {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                        GlobalConfig.background.desktopClock.position = root.clockPositions[i];
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Clock scale")
            description: qsTr("Adjust size of the desktop clock widget")
            StyledSlider {
                width: 240
                from: 0.5
                to: 3.0
                value: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.scale !== undefined) ? GlobalConfig.background.desktopClock.scale : 1.0
                onMoved: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                        GlobalConfig.background.desktopClock.scale = value;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Adaptive text contrast")
            description: qsTr("Automatically pick high contrast color based on wallpaper region")
            StyledSwitch {
                checked: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.adaptiveTextColor !== undefined) ? GlobalConfig.background.desktopClock.adaptiveTextColor : true
                onToggled: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                        GlobalConfig.background.desktopClock.adaptiveTextColor = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Invert color")
            description: qsTr("Force dark text palette instead of light")
            divider: false
            StyledSwitch {
                checked: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.invertColors !== undefined) ? GlobalConfig.background.desktopClock.invertColors : false
                onToggled: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                        GlobalConfig.background.desktopClock.invertColors = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Background Plate & Blur")
        description: qsTr("Surface card styling behind clock digits")
        icon: "blur_on"

        SettingRow {
            title: qsTr("Clock background card")
            description: qsTr("Show a subtle rounded M3 card behind the clock")
            StyledSwitch {
                checked: Boolean(GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background && GlobalConfig.background.desktopClock.background.enabled)
                onToggled: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background) {
                        GlobalConfig.background.desktopClock.background.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            visible: Boolean(GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background && GlobalConfig.background.desktopClock.background.enabled)
            title: qsTr("Card background blur")
            description: qsTr("Frosted glass effect behind clock")
            StyledSwitch {
                checked: Boolean(GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background && GlobalConfig.background.desktopClock.background.blur)
                onToggled: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background) {
                        GlobalConfig.background.desktopClock.background.blur = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            visible: Boolean(GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background && GlobalConfig.background.desktopClock.background.enabled)
            title: qsTr("Card opacity")
            description: qsTr("Transparency of the clock card plate")
            divider: false
            StyledSlider {
                width: 240
                from: 0.1
                to: 1.0
                value: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background && GlobalConfig.background.desktopClock.background.opacity !== undefined) ? GlobalConfig.background.desktopClock.background.opacity : 0.7
                onMoved: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background) {
                        GlobalConfig.background.desktopClock.background.opacity = value;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}

