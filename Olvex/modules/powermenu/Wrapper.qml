
import QtQuick
import Olvex.Config
import qs.components

Item {
    id: root

    required property DrawerVisibilities visibilities
    readonly property real nonAnimWidth: content.implicitWidth

    readonly property bool shouldBeActive: visibilities.powermenu && Config.powermenu.enabled
    property real offsetScale: shouldBeActive ? 0 : 1

    property bool contentPrewarmed: false

    Timer {
        id: prewarmTimer
        interval: 2400
        running: true
        repeat: false
        onTriggered: root.contentPrewarmed = true
    }

    readonly property var m3EmphasizedDecel: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var m3EmphasizedAccel: [0.35, 0.0, 0.85, 0.15, 1.0, 1.0]

    visible: offsetScale < 1
    opacity: 1 - offsetScale

    anchors.fill: parent

    Behavior on offsetScale {
        NumberAnimation {
            duration: root.shouldBeActive ? 680 : 330
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.shouldBeActive ? root.m3EmphasizedDecel : root.m3EmphasizedAccel
        }
    }

    Loader {
        id: content
        anchors.fill: parent
        asynchronous: true
        active: root.contentPrewarmed || root.shouldBeActive || root.visible

        sourceComponent: Content {
            visibilities: root.visibilities
        }

    }
}
