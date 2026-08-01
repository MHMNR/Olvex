import QtQuick

Rectangle {
    id: root

    color: "transparent"
    antialiasing: true
    smooth: true

    Behavior on color {
        CAnim {}
    }
}
