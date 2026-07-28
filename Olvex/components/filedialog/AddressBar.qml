pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.filedialog
import qs.services
import qs.utils

StyledRect {
    id: root

    required property var dialog

    readonly property int textPx: Math.max(11, Math.round(Tokens.font.size.normal * 96 / 72))
    readonly property int vPad: Tokens.padding.small
    readonly property int rowHeight: textPx + 4
    readonly property int barHeight: rowHeight + vPad * 2
    readonly property int segPadH: Tokens.padding.small + 2
    readonly property int iconSize: rowHeight

    readonly property string pathIcon: {
        const cwd = root.dialog.cwd;
        if (cwd.length === 0)
            return "folder";
        if (cwd.length === 1) {
            if (cwd[0] === "Home")
                return "home";
            if (AccountFaces.isBundledPath(cwd[0]))
                return "face";
            return "folder";
        }
        if (cwd[0] === "Home" && cwd.length === 2) {
            switch (cwd[1]) {
            case "Downloads":
                return "file_download";
            case "Desktop":
                return "desktop_windows";
            case "Documents":
                return "description";
            case "Music":
                return "music_note";
            case "Pictures":
                return "image";
            case "Videos":
                return "video_library";
            default:
                return "folder";
            }
        }
        return "folder";
    }

    implicitHeight: barHeight
    radius: Tokens.rounding.full
    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

    function scrollToEnd(): void {
        pathScroll.contentX = Math.max(0, pathScroll.contentWidth - pathScroll.width);
    }

    RowLayout {
        id: barRow

        anchors.fill: parent
        anchors.margins: vPad
        spacing: Tokens.spacing.small

        FolderShapeIcon {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: iconSize
            Layout.preferredHeight: iconSize
            compact: true
            glyphIcon: root.pathIcon
        }

        Flickable {
            id: pathScroll

            Layout.fillWidth: true
            Layout.preferredHeight: rowHeight
            Layout.maximumHeight: rowHeight
            Layout.alignment: Qt.AlignVCenter

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            contentWidth: Math.max(width, pathRow.implicitWidth)
            contentHeight: rowHeight

            Behavior on contentX {
                Anim {
                    type: Anim.DefaultSpatial
                    duration: Tokens.anim.durations.expressiveFastSpatial
                }
            }

            Row {
                id: pathRow

                height: rowHeight

                Repeater {
                    model: root.dialog.pathSegments

                    delegate: Row {
                        id: segRow

                        required property int index
                        required property string modelData

                        readonly property bool isCurrent: index === root.dialog.pathSegments.length - 1

                        height: rowHeight
                        spacing: 0

                        Item {
                            visible: index > 0
                            width: sepLabel.width + Tokens.spacing.small
                            height: parent.height

                            StyledText {
                                id: sepLabel

                                anchors.centerIn: parent
                                height: rowHeight
                                verticalAlignment: Text.AlignVCenter
                                text: "/"
                                color: Colours.palette.m3outline
                                font.family: Tokens.font.family.mono
                                textPixelSize: root.textPx
                                opacity: 0.4
                            }
                        }

                        Item {
                            id: segHost

                            height: parent.height
                            width: segLabel.implicitWidth + root.segPadH * 2

                            StyledRect {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: Tokens.rounding.small
                                color: segRow.isCurrent ? Colours.palette.m3secondaryContainer : "transparent"

                                Behavior on color {
                                    CAnim {}
                                }
                            }

                            StateLayer {
                                radius: Tokens.rounding.small
                                disabled: segRow.isCurrent
                                onClicked: root.dialog.navigateToSegment(segRow.index)
                            }

                            StyledText {
                                id: segLabel

                                anchors.centerIn: parent
                                height: rowHeight
                                verticalAlignment: Text.AlignVCenter
                                text: modelData
                                color: segRow.isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                font.family: Tokens.font.family.mono
                                textPixelSize: root.textPx
                                font.weight: segRow.isCurrent ? Font.DemiBold : Font.Medium
                            }
                        }
                    }
                }
            }

            Connections {
                target: root.dialog
                function onAbsolutePathChanged(): void {
                    Qt.callLater(root.scrollToEnd);
                }
            }

            onContentWidthChanged: Qt.callLater(root.scrollToEnd)
            Component.onCompleted: Qt.callLater(root.scrollToEnd)
        }
    }
}