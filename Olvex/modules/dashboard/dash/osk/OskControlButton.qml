import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import Olvex.Config

Item {
    id: root
    
    property string icon
    signal clicked()
    
    Layout.preferredWidth: 32
    Layout.preferredHeight: 32
    
    property bool hideBackground: false
    
    property real widthExpansion: interaction.pressed ? 8 : 0
    Behavior on widthExpansion { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }

    // Background and Border
    StyledRect {
        anchors.fill: parent
        anchors.leftMargin: -root.widthExpansion / 2
        anchors.rightMargin: -root.widthExpansion / 2
        radius: 16
        color: Colours.light
            ? (interaction.containsMouse ? Colours.tileFillHover : Colours.tileFill)
            : (interaction.containsMouse ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainerHigh)
        border.width: Colours.light ? 0 : 1
        border.color: Colours.light ? "transparent" : Qt.alpha(Colours.palette.m3onSurface, 0.08)
        visible: !root.hideBackground
    }
    
    // Interaction Layer - Cleaned (No white flash)
    MouseArea {
        id: interaction
        anchors.fill: parent
        hoverEnabled: true
        
        MaterialIcon {
            anchors.centerIn: parent
            text: root.icon
            color: Colours.palette.m3onSurface
            font.pixelSize: 18
            opacity: interaction.containsMouse ? 1 : (Colours.light ? 0.85 : 0.6)
            
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
        
        onClicked: root.clicked()
    }
}
