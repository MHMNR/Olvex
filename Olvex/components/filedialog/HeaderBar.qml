pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.filedialog
import qs.services

StyledRect {
    id: root

    required property var dialog

    implicitWidth: inner.implicitWidth + Tokens.padding.normal * 2
    implicitHeight: inner.implicitHeight + Tokens.padding.normal * 2

    color: Colours.tPalette.m3surfaceContainer

    RowLayout {
        id: inner

        anchors.fill: parent
        anchors.margins: Tokens.padding.normal
        spacing: Tokens.spacing.small

        Item {
            implicitWidth: implicitHeight
            implicitHeight: backIcon.implicitHeight + Tokens.padding.small * 2

            StateLayer {
                radius: Tokens.rounding.small
                disabled: !root.dialog.canNavBack
                onClicked: root.dialog.goBack()
            }

            MaterialIcon {
                id: backIcon

                anchors.centerIn: parent
                text: "arrow_back"
                color: root.dialog.canNavBack ? Colours.palette.m3onSurface : Colours.palette.m3outline
                grade: 200
            }
        }

        Item {
            implicitWidth: implicitHeight
            implicitHeight: forwardIcon.implicitHeight + Tokens.padding.small * 2

            StateLayer {
                radius: Tokens.rounding.small
                disabled: !root.dialog.canNavForward
                onClicked: root.dialog.goForward()
            }

            MaterialIcon {
                id: forwardIcon

                anchors.centerIn: parent
                text: "arrow_forward"
                color: root.dialog.canNavForward ? Colours.palette.m3onSurface : Colours.palette.m3outline
                grade: 200
            }
        }

        Item {
            implicitWidth: implicitHeight
            implicitHeight: upIcon.implicitHeight + Tokens.padding.small * 2

            StateLayer {
                radius: Tokens.rounding.small
                disabled: !root.dialog.canNavUp
                onClicked: root.dialog.leaveDirectory()
            }

            MaterialIcon {
                id: upIcon

                anchors.centerIn: parent
                text: "drive_folder_upload"
                color: root.dialog.canNavUp ? Colours.palette.m3onSurface : Colours.palette.m3outline
                grade: 200
            }
        }

        AddressBar {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: backIcon.implicitHeight + Tokens.padding.small * 2
            dialog: root.dialog
        }
    }
}
