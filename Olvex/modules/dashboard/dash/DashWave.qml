import QtQuick
import qs.components

Item {
    id: root
    property color color: "white"
    property real speed: 0.02
    property real offset: 0
    
    clip: true
    
    StyledRect {
        id: waveBody
        width: parent.width * 2
        height: parent.height * 2
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        radius: width / 2
        color: root.color
        
        NumberAnimation on rotation {
            from: 0; to: 360
            duration: 1000 / root.speed
            loops: Animation.Infinite
            running: true
        }
        
        Component.onCompleted: {
            rotation = root.offset;
        }
    }
}
