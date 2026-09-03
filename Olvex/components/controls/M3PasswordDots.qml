import QtQuick
import Quickshell
import M3Shapes
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property string text: ""
    property int dotSize: 20
    property int dotSpacing: 6
    property color color: Colours.palette.m3onSurface
    property color cursorColor: Colours.palette.m3primary
    property bool showCursor: true
    property bool hasFocus: false
    property int alignment: Qt.AlignLeft

    clip: true

    function resetBlink() {
        if (cursor) {
            cursor.resetBlink();
        }
    }

    onTextChanged: resetBlink()

    ListView {
        id: charList

        readonly property int fullWidth: count > 0 ? (count * (implicitHeight + spacing) - spacing) : 0

        width: fullWidth
        height: implicitHeight
        implicitWidth: fullWidth
        implicitHeight: root.dotSize

        anchors.verticalCenter: parent.verticalCenter
        x: {
            if (root.alignment === Qt.AlignHCenter) {
                return fullWidth <= (root.width - 16)
                    ? Math.round((root.width - fullWidth) / 2)
                    : (root.width - fullWidth - 16);
            } else {
                return fullWidth <= (root.width - 16)
                    ? 0
                    : (root.width - fullWidth - 16);
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        orientation: Qt.Horizontal
        spacing: root.dotSpacing
        interactive: false

        model: ScriptModel {
            values: root.text.split("")
        }

        delegate: Item {
            id: ch

            implicitWidth: charList.implicitHeight
            implicitHeight: charList.implicitHeight

            opacity: 0
            scale: 0
            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }
            ListView.onRemove: removeAnim.start()

            // Curated Android 16 / M3 Expressive shapes
            readonly property var expressiveShapes: [
                MaterialShape.Cookie4Sided,
                MaterialShape.Sunny,
                MaterialShape.Clover4Leaf,
                MaterialShape.Diamond,
                MaterialShape.Heart,
                MaterialShape.Pentagon,
                MaterialShape.Gem,
                MaterialShape.Boom,
                MaterialShape.SoftBurst,
                MaterialShape.Flower,
                MaterialShape.Puffy,
                MaterialShape.Bun
            ]

            readonly property int initialShape: expressiveShapes[Math.floor(Math.random() * expressiveShapes.length)]
            property bool isMorphed: false

            MaterialShape {
                id: dotShape
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                color: root.color
                shape: ch.initialShape
                animationDuration: Tokens.anim.durations.expressiveFastSpatial || 350
                animationEasing: Tokens.anim.expressiveFastSpatial

                scale: ch.isMorphed ? 0.68 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: Tokens.anim.durations.expressiveFastSpatial || 350
                        easing: Tokens.anim.expressiveFastSpatial
                    }
                }

                Timer {
                    interval: 400
                    running: true
                    repeat: false
                    onTriggered: {
                        ch.isMorphed = true;
                        dotShape.shape = MaterialShape.Circle;
                    }
                }
            }

            SequentialAnimation {
                id: removeAnim

                PropertyAction {
                    target: ch
                    property: "ListView.delayRemove"
                    value: true
                }
                ParallelAnimation {
                    Anim {
                        target: ch
                        property: "opacity"
                        to: 0
                    }
                    Anim {
                        target: ch
                        property: "scale"
                        to: 0.5
                    }
                }
                PropertyAction {
                    target: ch
                    property: "ListView.delayRemove"
                    value: false
                }
            }

            Behavior on opacity {
                Anim {}
            }

            Behavior on scale {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }
    }

    // Blinking cursor
    Rectangle {
        id: cursor

        readonly property real targetX: root.text.length > 0
            ? (charList.x + charList.fullWidth + 4)
            : 0

        x: Math.min(Math.max(0, targetX), root.width - width - 2)
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: Math.max(14, charList.implicitHeight * 0.85)
        radius: 1
        color: root.cursorColor
        visible: root.showCursor && (root.hasFocus || root.text.length > 0)

        Behavior on x {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        Timer {
            id: blinkTimer
            interval: 500
            repeat: true
            running: cursor.visible
            onTriggered: cursor.opacity = (cursor.opacity > 0.5 ? 0.0 : 1.0)
        }

        function resetBlink() {
            cursor.opacity = 1.0;
            blinkTimer.restart();
        }
    }
}
