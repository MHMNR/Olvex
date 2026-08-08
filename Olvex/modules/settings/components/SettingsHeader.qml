pragma ComponentBehavior: Bound


import ".."
import "../chrome"
import "."
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config

Item {
    id: root

    required property string icon
    required property string title

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        anchors.centerIn: parent
        spacing: Tokens.spacing.normal

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            iconPointSize: Tokens.font.size.extraLarge * 3
            font.bold: true
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.title
            textPointSize: Tokens.font.size.large
            font.bold: true
        }
    }
}
