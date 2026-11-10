import QtQuick
import Olvex.Config
import qs.components
import qs.services

// Pill button used across the setup wizard (Filled / Tonal / Text).
StyledRect {
    id: root

    enum Kind {
        Filled,
        Tonal,
        Text
    }

    property int kind: SetupButton.Filled
    property string label
    property string icon
    property bool iconTrailing: true
    property bool disabled: false

    signal clicked

    readonly property color onColor: kind === SetupButton.Filled
        ? Colours.palette.m3onPrimary
        : kind === SetupButton.Tonal
            ? Colours.palette.m3onSecondaryContainer
            : Colours.palette.m3onSurface

    implicitHeight: 44
    implicitWidth: row.implicitWidth + 40
    radius: height / 2
    color: kind === SetupButton.Filled ? Colours.palette.m3primary : kind === SetupButton.Tonal ? Colours.palette.m3secondaryContainer : "transparent"
    opacity: disabled ? 0.38 : 1.0
    scale: layer.pressed ? 0.96 : 1.0

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 8

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.icon && !root.iconTrailing
            text: root.icon
            iconPointSize: 18
            color: root.onColor
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.weight: Font.DemiBold
            textPointSize: Tokens.font.size.normal
            color: root.onColor
        }

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.icon && root.iconTrailing
            text: root.icon
            iconPointSize: 18
            color: root.onColor
        }
    }

    StateLayer {
        id: layer

        anchors.fill: parent
        radius: root.radius
        color: root.onColor
        disabled: root.disabled
        onClicked: root.clicked()
    }
}

