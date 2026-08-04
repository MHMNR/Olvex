import QtQuick
import QtQuick.Layouts
import M3Shapes
import Olvex.Config
import qs.components
import qs.services

RowLayout {
    id: root

    property real value: 0
    property real max: Infinity
    property real min: -Infinity
    property real step: 1
    property alias repeatRate: timer.interval

    property bool isEditing: false
    property string displayText: root.value.toString()

    signal valueModified(value: real)

    spacing: Tokens.spacing.extraSmall

    onValueChanged: {
        if (!root.isEditing) {
            root.displayText = root.value.toString();
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

    // Minus Button (-)
    Item {
        implicitWidth: 28
        implicitHeight: 28

        scale: downState.pressed ? 0.92 : (downState.containsMouse ? 1.08 : 1.0)
        Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.70 } }

        MaterialIcon {
            id: downIcon
            anchors.centerIn: parent
            text: "remove"
            iconPointSize: Tokens.font.size.small
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
    StyledTextField {
        id: textField

        inputMethodHints: Qt.ImhFormattedNumbersOnly
        text: root.isEditing ? text : root.displayText
        font.family: "Monospace"
        font.weight: Font.Medium
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
            root.focus = false;
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

        padding: 0
        leftPadding: Tokens.padding.extraSmall
        rightPadding: Tokens.padding.extraSmall

        background: StyledRect {
            implicitWidth: 42
            implicitHeight: 28
            radius: Tokens.rounding.small
            color: Colours.tPalette.m3surfaceContainerHigh
            border.color: textField.activeFocus ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
            border.width: textField.activeFocus ? 2 : 1
        }
    }

    // Plus Button (+)
    Item {
        implicitWidth: 28
        implicitHeight: 28

        scale: upState.pressed ? 0.92 : (upState.containsMouse ? 1.08 : 1.0)
        Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.70 } }

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
