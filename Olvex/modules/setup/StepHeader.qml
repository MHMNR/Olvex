import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Stagger {
    id: root

    property string title
    property string subtitle

    Layout.fillWidth: true
    spacing: 3

    StyledText {
        text: root.title
        font.weight: Font.DemiBold
        textPointSize: Tokens.font.size.larger
        color: Colours.palette.m3onSurface
    }

    StyledText {
        Layout.fillWidth: true
        text: root.subtitle
        wrapMode: Text.WordWrap
        textPointSize: Tokens.font.size.normal
        color: Colours.light ? Qt.alpha(Colours.palette.m3onSurface, 0.78) : Colours.palette.m3onSurfaceVariant
    }
}

