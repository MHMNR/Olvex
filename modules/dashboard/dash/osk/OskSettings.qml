import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.components
import qs.components.controls
import qs.services
import Olvex.Config
import Olvex.Services

Item {
    id: root
    
    property bool isSplit: false
    property string activeLayoutName: "Default"
    property real oskScale: 1.0
    property bool canSplit: true
    signal close()
    
    property real maxImplicitHeight: headerRow.implicitHeight + scrollContent.implicitHeight + 64 // 24 * 2 margins + 16 spacing
    
    implicitWidth: 340
    implicitHeight: maxImplicitHeight
    
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // Header
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: 12
            
            MaterialIcon {
                text: "\ue8b8" // settings
                color: Colours.palette.m3primary
                font.pixelSize: 24
            }
            
            StyledText {
                text: "Keyboard Settings"
                color: Colours.palette.m3onSurface
                font.pixelSize: 18
                font.weight: Font.Bold
                Layout.fillWidth: true
            }
            
            OskControlButton {
                icon: "\ue5cd" // close
                onClicked: root.close()
            }
        }
        
        // Settings List (Scrollable)
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            
            ColumnLayout {
                id: scrollContent
                width: parent.width
                spacing: 12
            
            // Card 1: Keyboard Layout
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: layoutCol.implicitHeight + 28
                radius: 16
                color: Colours.tPalette.m3surfaceContainer
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3primary, 0.15)
                
                ColumnLayout {
                    id: layoutCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10
                    
                    StyledText {
                        text: "Keyboard Layout"
                        color: Colours.palette.m3onSurface
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }
                    
                    StyledRect {
                        id: layoutSelector
                        Layout.fillWidth: true
                        implicitHeight: 42
                        radius: 21
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.1)
                        
                        StyledRect {
                            id: layoutIndicator
                            readonly property var options: ["Default", "Phone", "Traditional"]
                            readonly property int index: options.indexOf(root.activeLayoutName)
                            
                            x: 4 + index * (layoutSelector.width - 8) / options.length
                            y: 4
                            width: (layoutSelector.width - 8) / options.length
                            height: 34
                            radius: 17
                            color: Colours.palette.m3primary
                            
                            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 0
                            
                            Repeater {
                                model: ["Default", "Phone", "Traditional"]
                                delegate: Item {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: modelData === root.activeLayoutName ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                        font.pixelSize: 13
                                        font.weight: modelData === root.activeLayoutName ? Font.Bold : Font.Medium
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                    
                                    StateLayer {
                                        anchors.fill: parent
                                        radius: 14
                                        onClicked: root.activeLayoutName = modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Card 2: Split Layout Toggle
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: toggleRow.implicitHeight + 28
                radius: 16
                color: Colours.tPalette.m3surfaceContainer
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3primary, 0.15)
                
                RowLayout {
                    id: toggleRow
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12
                    opacity: root.canSplit ? 1 : 0.5
                    
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        
                        StyledText {
                            text: "Split Layout"
                            color: Colours.palette.m3onSurface
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        
                        StyledText {
                            text: root.canSplit ? "Ergonomic thumb typing" : "Not available"
                            color: Colours.palette.m3onSurfaceVariant
                            font.pixelSize: 11
                        }
                    }
                    
                    StyledSwitch {
                        checked: root.isSplit
                        enabled: root.canSplit
                        onClicked: root.isSplit = !root.isSplit
                    }
                }
            }

            // Card 3: Auto-capitalization Toggle
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: autoCapRow.implicitHeight + 28
                radius: 16
                color: Colours.tPalette.m3surfaceContainer
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3primary, 0.15)
                
                RowLayout {
                    id: autoCapRow
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12
                    
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        
                        StyledText {
                            text: "Auto-capitalization"
                            color: Colours.palette.m3onSurface
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        
                        StyledText {
                            text: "Automatically capitalize first letter"
                            color: Colours.palette.m3onSurfaceVariant
                            font.pixelSize: 11
                        }
                    }
                    
                    StyledSwitch {
                        checked: Ydotool.autoCapitalizeEnabled
                        onClicked: Ydotool.autoCapitalizeEnabled = !Ydotool.autoCapitalizeEnabled
                    }
                }
            }

            // Card 4: Keyboard Scale Slider
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: scaleRow.implicitHeight + 28
                radius: 16
                color: Colours.tPalette.m3surfaceContainer
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3primary, 0.15)
                
                ColumnLayout {
                    id: scaleRow
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12
                    
                    RowLayout {
                        Layout.fillWidth: true
                        
                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true
                            
                            StyledText {
                                text: "Keyboard Scale"
                                color: Colours.palette.m3onSurface
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            
                            StyledText {
                                text: "Adjust the size of the keyboard"
                                color: Colours.palette.m3onSurfaceVariant
                                font.pixelSize: 11
                            }
                        }
                        
                        StyledText {
                            text: Math.round(scaleSlider.value * 100) + "%"
                            color: Colours.palette.m3primary
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        StyledSlider {
                            id: scaleSlider
                            Layout.fillWidth: true
                            implicitHeight: 24
                            from: 0.7
                            to: 1.5
                            value: root.oskScale
                        }
                        
                        StyledRect {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: 16
                            color: Colours.palette.m3primary
                            
                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "\ue5ca" // check
                                color: Colours.palette.m3onPrimary
                                font.pixelSize: 18
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.oskScale = scaleSlider.value
                            }
                        }
                    }
                }
            }
        }
    }
}
}
