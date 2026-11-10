import QtQuick
import QtQuick.Layouts

// Column that fades + rises in with a delay of order * 45ms (cascading stagger).
ColumnLayout {
    id: root

    property int order: 0
    property real riseY: 14

    spacing: 0
    opacity: 0

    transform: Translate {
        id: shift

        y: root.riseY
    }

    Component.onCompleted: enter.start()

    SequentialAnimation {
        id: enter

        PauseAnimation {
            duration: 60 + root.order * 45
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 1
                duration: 320
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: shift
                property: "y"
                to: 0
                duration: 420
                easing.type: Easing.OutCubic
            }
        }
    }
}

