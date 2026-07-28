import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

// Dropdown trigger — single soft chromatic pill: [icon] label  expand_more
StyledRect {
    id: root

    enum Type {
        Filled,
        Tonal
    }

    property real horizontalPadding: Tokens.padding.normal
    property real verticalPadding: Tokens.padding.smaller
    property int type: SplitButton.Filled
    property bool disabled
    property bool menuOnTop
    property string fallbackIcon
    property string fallbackText

    property alias menuItems: menu.items
    property alias active: menu.active
    property alias expanded: menu.expanded
    property alias menu: menu
    property alias iconLabel: iconLabel
    property alias label: label
    property alias stateLayer: stateLayer

    property color colour: type === 0
        ? Colours.palette.m3primary
        : Colours.palette.m3secondaryContainer
    property color textColour: type === 0
        ? Colours.palette.m3onPrimary
        : Colours.palette.m3onSecondaryContainer
    property color disabledColour: Qt.alpha(Colours.palette.m3onSurface, 0.1)
    property color disabledTextColour: Qt.alpha(Colours.palette.m3onSurface, 0.38)

    readonly property real pillR: height / 2

    implicitWidth: contentRow.implicitWidth + horizontalPadding * 2
    implicitHeight: 36

    radius: pillR
    color: disabled
        ? disabledColour
        : Qt.rgba(colour.r, colour.g, colour.b, 1)
    border.width: 0

    StateLayer {
        id: stateLayer

        radius: root.pillR
        color: root.textColour
        disabled: root.disabled
        onClicked: root.expanded = !root.expanded
    }

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            id: iconLabel

            Layout.alignment: Qt.AlignVCenter
            visible: text.length > 0
            animate: true
            text: root.active?.activeIcon ?? root.fallbackIcon
            color: root.disabled ? root.disabledTextColour : root.textColour
            fill: 0
            iconPointSize: Tokens.font.size.normal
        }

        StyledText {
            id: label

            Layout.alignment: Qt.AlignVCenter
            animate: true
            text: root.active?.activeText ?? root.fallbackText
            color: root.disabled ? root.disabledTextColour : root.textColour
            textPointSize: Tokens.font.size.small
            font.weight: Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        MaterialIcon {
            id: expandIcon

            Layout.alignment: Qt.AlignVCenter
            text: "expand_more"
            color: root.disabled ? root.disabledTextColour : root.textColour
            rotation: root.expanded ? 180 : 0
            iconPointSize: Tokens.font.size.normal
            opacity: 0.85

            Behavior on rotation {
                Anim {}
            }
        }
    }

    Menu {
        id: menu

        attachTo: root
        attachSideY: root.menuOnTop ? Menu.Top : Menu.Bottom
        thisSideY: root.menuOnTop ? Menu.Bottom : Menu.Top
        attachSideX: Menu.Right
        thisSideX: Menu.Right
        marginY: Tokens.spacing.small * (root.menuOnTop ? -1 : 1)
        highlightActive: true
        maxHeight: 320
    }
}
