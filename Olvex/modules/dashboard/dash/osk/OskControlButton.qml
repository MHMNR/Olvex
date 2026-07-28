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
        radius: 8
        color: Colours.tPalette.m3surfaceVariant
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
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
            color: "#ffffff"
            iconPointSize: 13.5
            opacity: interaction.containsMouse ? 1 : 0.6
            
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
        
        onClicked: root.clicked()
    }
}
