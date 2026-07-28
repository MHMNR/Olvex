pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    required property Pam pam
    readonly property alias placeholder: placeholder
    property string buffer

    Layout.fillWidth: true
    Layout.fillHeight: true

    clip: true

    Connections {
        function onBufferChanged(): void {
            if (root.pam.buffer.length > root.buffer.length) {
                charList.bindImWidth();
            } else if (root.pam.buffer.length === 0) {
                charList.implicitWidth = charList.implicitWidth;
                placeholder.animate = true;
            }

            root.buffer = root.pam.buffer;
        }

        target: root.pam
    }

    StyledText {
        id: placeholder

        anchors.centerIn: parent

        text: {
            if (root.pam.passwd.active)
                return qsTr("Loading...");
            if (root.pam.state === "max")
                return qsTr("You have reached the maximum number of tries");
            return qsTr("Enter your password");
        }

        animate: true
        color: root.pam.passwd.active ? Colours.palette.m3secondary : Colours.palette.m3outline
        textPointSize: Tokens.font.size.normal
        font.family: Tokens.font.family.mono

        opacity: root.buffer ? 0 : 1

        Behavior on opacity {
            Anim {}
        }
    }

    ListView {
        id: charList

        readonly property int fullWidth: count * (implicitHeight + spacing) - spacing

        function bindImWidth(): void {
            imWidthBehavior.enabled = false;
            implicitWidth = Qt.binding(() => fullWidth);
            imWidthBehavior.enabled = true;
        }

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: implicitWidth > root.width ? -(implicitWidth - root.width) / 2 : 0

        implicitWidth: fullWidth
        implicitHeight: Tokens.font.size.normal

        orientation: Qt.Horizontal
        spacing: Tokens.spacing.small / 2
        interactive: false

        model: ScriptModel {
            values: root.buffer.split("")
        }

        delegate: StyledRect {
            id: ch

            implicitWidth: implicitHeight
            implicitHeight: charList.implicitHeight

            color: Colours.palette.m3onSurface
            radius: Tokens.rounding.small / 2

            opacity: 0
            scale: 0
            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }
            ListView.onRemove: removeAnim.start()

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

        Behavior on implicitWidth {
            id: imWidthBehavior

            Anim {}
        }
    }

    // Blinking cursor
    Rectangle {
        id: cursor

        readonly property real afterDots: charList.x
            + (charList.implicitWidth > 0 ? charList.implicitWidth + 6 : 0)

        x: Math.min(afterDots, root.width - width - 2)
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: charList.implicitHeight * 1.1
        radius: 1
        color: Colours.palette.m3primary

        Behavior on x { SmoothedAnimation { velocity: 300 } }

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: true
            NumberAnimation { to: 1.0; duration: 80 }
            PauseAnimation   { duration: 520 }
            NumberAnimation { to: 0.0; duration: 80 }
            PauseAnimation   { duration: 380 }
        }
    }
}
