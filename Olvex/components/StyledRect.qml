import QtQuick

Rectangle {
    id: root

    property bool isReady: false
    Component.onCompleted: isReady = true

    color: "transparent"
    antialiasing: true
    smooth: true

    Behavior on color {
        enabled: root.isReady
        CAnim {}
    }
}
