import QtQuick

Item {
    id: root

    property color handColor: "white"
    property real handLength: 60
    property real handWidth: 2
    property real tailRatio: 0.22
    property bool active: true

    width: Math.max(2, handWidth)
    height: Math.max(10, handLength)
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    anchors.bottom: parent ? parent.verticalCenter : undefined
    transformOrigin: Item.Bottom

    function syncAngle() {
        const now = new Date();
        const s = now.getSeconds() + now.getMilliseconds() / 1000.0;
        root.rotation = s * 6.0;
    }

    FrameAnimation {
        running: root.active && root.visible
        onTriggered: root.syncAngle()
    }

    Component.onCompleted: syncAngle()

    Rectangle {
        width: root.width
        height: root.height * (1 + root.tailRatio)
        radius: width / 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        color: root.handColor
    }
}

