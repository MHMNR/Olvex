import QtQuick

QtObject {
    required property var service
    property bool active: true
    property bool held: false

    function sync(): void {
        if (active && !held) {
            service.refCount++;
            held = true;
        } else if (!active && held) {
            service.refCount--;
            held = false;
        }
    }

    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (held) {
            service.refCount--;
            held = false;
        }
    }
}
