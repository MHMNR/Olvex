import QtQuick
import QtQuick.Layouts
import M3Shapes
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property real value: 0
    property real max: Infinity
    property real min: -Infinity
    property real step: 1
    property alias repeatRate: timer.interval

    property bool isEditing: false
    property string displayText: root.value.toString()

    signal valueModified(value: real)

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    onValueChanged: {
        if (!root.isEditing) {
            root.displayText = root.value.toString();
            if (typeof textField !== "undefined" && textField) {
                textField.text = root.displayText;
            }
        }
    }

    function increment(): void {
        let newValue = Math.min(root.max, root.value + root.step);
        const decimals = root.step < 1 ? Math.max(1, Math.ceil(-Math.log10(root.step))) : 0;
        newValue = Math.round(newValue * Math.pow(10, decimals)) / Math.pow(10, decimals);
        root.value = newValue;
        root.displayText = newValue.toString();
        root.valueModified(newValue);
    }

    function decrement(): void {
        let newValue = Math.max(root.min, root.value - root.step);
        const decimals = root.step < 1 ? Math.max(1, Math.ceil(-Math.log10(root.step))) : 0;
        newValue = Math.round(newValue * Math.pow(10, decimals)) / Math.pow(10, decimals);
        root.value = newValue;
        root.displayText = newValue.toString();
        root.valueModified(newValue);
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: Tokens.spacing.small

        // Minus Button (-)
        StyledRect {
            implicitWidth: 32
            implicitHeight: 32
            radius: height / 2
            color: Colours.tPalette.m3surface

            scale: downState.pressed ? 0.96 : (downState.containsMouse ? 1.02 : 1.0)
            Behavior on scale {
                SpringAnimation {
                    spring: downState.pressed ? 5.0 : 4.2
                    damping: downState.pressed ? 0.65 : 0.70
                }
            }

            MaterialIcon {
                id: downIcon
                anchors.centerIn: parent
                text: "remove"
                iconPointSize: 14
                color: Colours.palette.m3onSurfaceVariant
            }

            StateLayer {
                id: downState
                radius: parent.height / 2
                color: Colours.palette.m3onSurface
                onClicked: root.decrement()
                onPressedChanged: {
                    if (pressed) {
                        timer.tickCount = 0;
                        timer.start();
                    } else {
                        timer.stop();
                    }
                }
            }
        }

        // Value Display / Input Capsule
        StyledRect {
            Layout.fillHeight: true
            Layout.preferredWidth: Math.max(48, textField.contentWidth + 24)
            radius: 8
            color: Colours.tPalette.m3surfaceContainer
            border.color: textField.activeFocus ? Colours.palette.m3primary : "transparent"
            border.width: textField.activeFocus ? 2 : 0

            Behavior on border.color { CAnim {} }
            Behavior on Layout.preferredWidth { CAnim { duration: Tokens.anim.durations.short } }

            StyledTextField {
                id: textField
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                inputMethodHints: Qt.ImhFormattedNumbersOnly
                text: root.displayText
                font.weight: Font.Normal
                font.pixelSize: 16
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter

                validator: DoubleValidator {
                    bottom: root.min
                    top: root.max
                    decimals: root.step < 1 ? Math.max(1, Math.ceil(-Math.log10(root.step))) : 0
                }
                onActiveFocusChanged: {
                    if (activeFocus) {
                        root.isEditing = true;
                    } else {
                        root.isEditing = false;
                        root.displayText = root.value.toString();
                        textField.text = root.displayText;
                    }
                }
                onAccepted: {
                    const numValue = parseFloat(text);
                    if (!isNaN(numValue)) {
                        const clampedValue = Math.max(root.min, Math.min(root.max, numValue));
                        root.value = clampedValue;
                        root.displayText = clampedValue.toString();
                        root.valueModified(clampedValue);
                    } else {
                        text = root.displayText;
                    }
                    root.isEditing = false;
                    textField.focus = false;
                }
                onEditingFinished: {
                    if (text !== root.displayText) {
                        const numValue = parseFloat(text);
                        if (!isNaN(numValue)) {
                            const clampedValue = Math.max(root.min, Math.min(root.max, numValue));
                            root.value = clampedValue;
                            root.displayText = clampedValue.toString();
                            root.valueModified(clampedValue);
                        } else {
                            text = root.displayText;
                        }
                    }
                    root.isEditing = false;
                }

                background: Item {}
            }
        }

        // Plus Button (+)
        StyledRect {
            implicitWidth: 32
            implicitHeight: 32
            radius: height / 2
            color: Colours.tPalette.m3surface

            scale: upState.pressed ? 0.96 : (upState.containsMouse ? 1.02 : 1.0)
            Behavior on scale {
                SpringAnimation {
                    spring: upState.pressed ? 5.0 : 4.2
                    damping: upState.pressed ? 0.65 : 0.70
                }
            }

            MaterialIcon {
                id: upIcon
                anchors.centerIn: parent
                text: "add"
                iconPointSize: Tokens.font.size.small
                color: Colours.palette.m3onSurfaceVariant
            }

            StateLayer {
                id: upState
                radius: parent.height / 2
                color: Colours.palette.m3onSurface
                onClicked: root.increment()
                onPressedChanged: {
                    if (pressed) {
                        timer.tickCount = 0;
                        timer.start();
                    } else {
                        timer.stop();
                    }
                }
            }
        }
    }

    // Global click interceptor to clear focus when clicking outside
    MouseArea {
        parent: {
            let p = root;
            while (p && p.parent) p = p.parent;
            return p;
        }
        anchors.fill: parent
        z: 999999
        visible: root.isEditing
        propagateComposedEvents: true
        onPressed: (mouse) => {
            textField.focus = false;
            mouse.accepted = false; // allow the click to pass through to underlying UI
        }
    }

    Timer {
        id: timer

        interval: 100
        repeat: true
        triggeredOnStart: false
        property int tickCount: 0
        onTriggered: {
            if (tickCount > 3) {
                if (upState.pressed)
                    root.increment();
                else if (downState.pressed)
                    root.decrement();
            } else {
                tickCount++;
            }
        }
    }
}
