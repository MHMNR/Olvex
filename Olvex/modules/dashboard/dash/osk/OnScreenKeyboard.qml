import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.components
import qs.services
import Olvex.Services
import Olvex.Config
import Olvex.Config as Config
import Qt5Compat.GraphicalEffects as GE
import QtCore

Item {
    id: root
    
    HoverHandler { id: oskHover }
    readonly property bool containsMouse: oskHover.hovered

    required property var visibilities
    readonly property var ydotool: Ydotool
    readonly property bool isDocked: visibilities && visibilities.isOskDocked ? true : false
    property bool showingSettings: false
    readonly property real padding: 22
    property bool isSplit: false
    property string activeLayoutName: "Default"
    onActiveLayoutNameChanged: Ydotool.activeLayout = activeLayoutName
    Component.onCompleted: {
        Ydotool.activeLayout = activeLayoutName
        // Trigger initial auto-cap check
        if (ydotool.autoCapitalizeEnabled) {
            wordEngine.autoCapPending = true
        }
    }
    property real oskScale: oskSettings.scale
    
    Settings {
        id: oskSettings
        category: "OnScreenKeyboard"
        property real scale: 1.0
    }

    onOskScaleChanged: {
        oskSettings.scale = oskScale
    }
    
    signal hideRequested()
    signal dragged(real dx, real dy)

    Connections {
        target: root.visibilities
        function onOskChanged() {
            if (root.visibilities.osk) {
                // Reset stale modifier state from physical keyboard before OSK use
                ydotool.resetModifiers();
            }
        }
    }

    // Word prediction engine
    OskWordEngine {
        id: wordEngine
        ydotool: root.ydotool
        
        onAutoCapPendingChanged: {
            if (autoCapPending && ydotool.autoCapitalizeEnabled && !ydotool.isShiftActive && !ydotool.capsMode) {
                root.latchShift();
            }
        }
        
        onSentenceBoundaryDetected: {
            if (ydotool.autoCapitalizeEnabled && !ydotool.isShiftActive && !ydotool.capsMode) {
                root.latchShift();
            }
        }
    }
    
    function latchShift() {
        let m = ydotool.latchedModifiers.slice();
        if (m.indexOf(42) === -1) {
            m.push(42);
            ydotool.latchedModifiers = m;
        }
    }

    // Layout stability: Keep implicit size constant regardless of mode
    implicitWidth: oskLayoutContainer.implicitWidth + (root.padding * 2)
    implicitHeight: oskLayoutContainer.implicitHeight + (root.padding * 2) + 6

    readonly property bool isDragging: dragArea.pressed
    
    // Split is only applicable to Default and Phone layouts
    readonly property bool canSplit: root.activeLayoutName === "Default" || root.activeLayoutName === "Phone"



    // Content Wrapper for Blur Source (includes BG and Keys)
    Item {
        id: oskContentWrapper
        anchors.fill: parent
        z: 0

        StyledRect {
            id: oskBackground
            anchors.fill: parent
            
            radius: Tokens.rounding.large - 5
            topLeftRadius: radius
            topRightRadius: radius
            bottomLeftRadius: radius
            bottomRightRadius: radius
            
            color: Colours.tPalette.m3surface // Deep dark glass to match dashboard panels
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3onSurface, 0.08) // Subtle dashboard-style border
            
            Behavior on radius { NumberAnimation { duration: Tokens.anim.durations.expressiveDefaultSpatial } }
        }

        ColumnLayout {
            id: oskLayoutContainer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: root.padding
            anchors.rightMargin: root.padding
            anchors.topMargin: root.padding - 6
            anchors.bottomMargin: 8
            spacing: 12
            clip: false

            // Top Header Bar
            RowLayout {
                id: oskHeader
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                spacing: 12

                // Symmetrical Header Caps
                RowLayout {
                    id: headerLeftRow
                    spacing: 8
                    Layout.preferredWidth: 80
                    Layout.alignment: Qt.AlignLeft
                    
                    OskControlButton {
                        id: settingsBtn
                        icon: "\ue8b8" // settings
                        hideBackground: true
                        onClicked: root.showingSettings = true
                        // Hide header button during the entire time the settings card is open or morphing
                        opacity: (root.showingSettings || settingsCard.width > 40) ? 0 : 1
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    
                    Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                    }
                }

                // Middle Section (Suggestion Bar / Search Bar)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    clip: true

                    // Emoji Search Bar
                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
                        visible: root.activeLayoutName === "Emoji Search"
                        border.color: headerSearchInput.activeFocus ? Colours.palette.m3primary : "transparent"
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 8
                            StyledText {
                                text: "search"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 16
                                color: Qt.alpha(Colours.palette.m3onSurface, 0.5)
                            }
                            TextInput {
                                id: headerSearchInput
                                Layout.fillWidth: true
                                font.pixelSize: 14
                                color: Colours.palette.m3onSurface
                                verticalAlignment: TextInput.AlignVCenter
                                text: oskContent.item ? (oskContent.item.searchText || "") : ""
                                
                                Text {
                                    text: "Search Emoji"
                                    visible: !headerSearchInput.text && !headerSearchInput.activeFocus
                                    color: Qt.alpha(Colours.palette.m3onSurface, 0.4)
                                    font: headerSearchInput.font
                                }
                                
                                onActiveFocusChanged: {
                                    if (activeFocus) {
                                        root.activeLayoutName = "Phone";
                                    }
                                }
                                
                                onTextChanged: {
                                    if (oskContent.item && oskContent.item.objectName === "emojiPicker") {
                                        oskContent.item.searchText = text;
                                    }
                                }
                            }
                        }
                    }

                    // Suggestion Bar - Visible when not searching
                    OskSuggestionBar {
                        id: suggestionBar
                        anchors.fill: parent
                        visible: root.activeLayoutName !== "Emoji Search" && implicitHeight > 0
                        engine: wordEngine
                        onSuggestionAccepted: (word) => {
                            let suffix = wordEngine.acceptSuggestion(word);
                            ydotool.typeString(suffix);
                        }
                    }
                }

                // Control Buttons
                RowLayout {
                    id: headerRightRow
                    spacing: 8
                    Layout.preferredWidth: 80
                    Layout.alignment: Qt.AlignRight
                    
                    OskControlButton {
                        icon: root.isDocked ? "\ue5ce" : "\ue5cf" // expand_less / expand_more
                        onClicked: visibilities.isOskDocked = !visibilities.isOskDocked
                    }

                    OskControlButton {
                        icon: "\ue5cd" // close
                        onClicked: root.hideRequested()
                    }
                }
            }


            // Keyboard Content
            OskContent {
                id: oskContent
                activeLayoutName: root.activeLayoutName
                scaleFactor: root.oskScale
                isDocked: root.isDocked
                isSplit: root.isSplit && root.isDocked && root.canSplit
                dockProgress: parent.parent.parent.parent.dockProgress // Accessing PanelWindow.dockProgress
                wordEngine: wordEngine
                Layout.fillWidth: true
                onHideRequested: root.hideRequested()
                onLayoutSwitchRequested: (target) => {
                    root.activeLayoutName = target;
                }
            }

            // Bottom Drag Handle
            Rectangle {
                id: dragHandle
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 60
                Layout.preferredHeight: 6
                Layout.topMargin: 8
                radius: 3
                color: "#ffffff"
                opacity: (isDocked || root.showingSettings) ? 0 : 0.3
                Behavior on opacity { NumberAnimation { duration: 200 } }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    anchors.margins: -20 // Much larger touch area for easier dragging
                    
                    property real pressX
                    property real pressY
                    
                    onPressed: (mouse) => {
                        let pos = mapToItem(root.parent, mouse.x, mouse.y);
                        pressX = pos.x;
                        pressY = pos.y;
                    }
                    
                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            let pos = mapToItem(root.parent, mouse.x, mouse.y);
                            root.dragged(pos.x - pressX, pos.y - pressY);
                        }
                    }
                }
            }
        }
    }

    // Click outside to close (Invisible Backdrop)
    MouseArea {
        anchors.fill: parent
        enabled: root.showingSettings
        visible: enabled
        onClicked: root.showingSettings = false
        z: 99 // Just below the settings card
    }

    // Morphing Settings Card (The Button ITSELF morphs)
    Rectangle {
        id: settingsCard
        z: 100 
        visible: true
        opacity: 1 // ALWAYS opaque to prevent fade-in jump
        color: "transparent"
        
        // Morphs from the gear icon and expands downwards, overlaying the keys. Height is capped so it doesn't clip off-screen.
        // Morphs from the gear icon and expands downwards
        // Morphs from the gear icon and expands downwards
        x: oskHeader.x + headerLeftRow.x + settingsBtn.x + oskLayoutContainer.x
        y: oskHeader.y + headerLeftRow.y + settingsBtn.y + oskLayoutContainer.y
        
        width: root.showingSettings ? 340 : 32
        height: root.showingSettings ? Math.min(settingsPanel.maxImplicitHeight, oskLayoutContainer.height - (headerLeftRow.y + settingsBtn.y)) : 32
        radius: root.showingSettings ? 24 : 8
        clip: true
        
        Behavior on x { NumberAnimation { duration: Tokens.anim.durations.expressiveDefaultSpatial; easing: Tokens.anim.expressiveDefaultSpatial } }
        Behavior on y { NumberAnimation { duration: Tokens.anim.durations.expressiveDefaultSpatial; easing: Tokens.anim.expressiveDefaultSpatial } }
        Behavior on width { NumberAnimation { duration: Tokens.anim.durations.expressiveDefaultSpatial; easing: Tokens.anim.expressiveDefaultSpatial } }
        Behavior on height { NumberAnimation { duration: Tokens.anim.durations.expressiveDefaultSpatial; easing: Tokens.anim.expressiveDefaultSpatial } }
        Behavior on radius { NumberAnimation { duration: Tokens.anim.durations.expressiveDefaultSpatial; easing: Tokens.anim.expressiveDefaultSpatial } }

        // Background Layer (solid color)
        Rectangle {
            id: settingsCardBg
            anchors.fill: parent
            radius: settingsCard.radius
            color: root.showingSettings ? Colours.palette.m3surfaceVariant : Colours.tPalette.m3surfaceVariant
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3primary, 0.2)
        }
        
      
        
        // Interaction logic (Button state) - REMOVED white flash effect
        MouseArea {
            id: settingsInteraction
            anchors.fill: parent
            enabled: !root.showingSettings
            onClicked: root.showingSettings = true
            
            MaterialIcon {
                anchors.centerIn: parent
                text: "\ue8b8" // settings
                color: "#ffffff"
                font.pixelSize: 18
                // Ensure icon is ONLY visible when card is in its small button state
                opacity: (root.showingSettings || settingsCard.width > 40) ? 0 : (settingsInteraction.containsMouse ? 1 : 0.6)
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }
        
        OskSettings {
            id: settingsPanel
            anchors.fill: parent
            isSplit: root.isSplit
            canSplit: root.canSplit
            activeLayoutName: root.activeLayoutName
            oskScale: root.oskScale
            opacity: root.showingSettings ? 1 : 0
            visible: opacity > 0
            
            onIsSplitChanged: root.isSplit = settingsPanel.isSplit
            onActiveLayoutNameChanged: root.activeLayoutName = settingsPanel.activeLayoutName
            onOskScaleChanged: root.oskScale = settingsPanel.oskScale
            onClose: root.showingSettings = false
        }
    }
}
