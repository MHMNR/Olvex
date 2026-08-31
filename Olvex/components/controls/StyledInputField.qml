
import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property string text: ""
    property var validator: null
    property bool readOnly: false
    property int horizontalAlignment: TextInput.AlignHCenter

    // Expose activeFocus through alias to avoid FINAL property override
    readonly property alias hasFocus: inputField.activeFocus

    signal textEdited(string text)

    signal editingFinished

    implicitWidth: 70
    implicitHeight: inputField.implicitHeight + Tokens.padding.small * 2

    StyledRect {
        id: container

        anchors.fill: parent
        color: inputHover.containsMouse || inputField.activeFocus
            ? Qt.alpha(Colours.palette.m3onSurface, 0.18)
            : Qt.alpha(Colours.palette.m3onSurface, 0.12)
        radius: Tokens.rounding.full
        border.width: 0
        border.color: "transparent"
        opacity: root.enabled ? 1 : 0.5

        Behavior on color {
            CAnim {}
        }

        MouseArea {
            id: inputHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            acceptedButtons: Qt.NoButton
            enabled: root.enabled
        }

        StyledTextField {
            id: inputField

            anchors.centerIn: parent
            width: parent.width - Tokens.padding.normal
            horizontalAlignment: root.horizontalAlignment
            validator: root.validator
            readOnly: root.readOnly
            enabled: root.enabled

            onTextChanged: {
                root.text = text;
                root.textEdited(text);
            }

            onEditingFinished: {
                root.editingFinished();
            }

            Binding {
                target: inputField
                property: "text"
                value: root.text
                when: !inputField.activeFocus
            }
        }
    }
}
