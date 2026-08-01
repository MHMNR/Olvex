pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Olvex.Config
import Olvex.Models
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

// Recording list — uses global StyledListView AnimatedList scroll system
// (edge fades + populate transitions) + AnimatedScrollItem for in-view scale.
ColumnLayout {
    id: root

    required property var props
    required property DrawerVisibilities visibilities

    property int selectedIndex: -1

    spacing: Tokens.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small
        visible: list.count > 0

        StyledText {
            text: qsTr("Recent")
            color: Colours.palette.m3onSurfaceVariant
            textPointSize: Tokens.font.size.small
            font.weight: Font.Medium
            font.letterSpacing: 0.2
        }

        Item {
            Layout.fillWidth: true
        }

        StyledText {
            text: list.count === 1 ? qsTr("1 file") : qsTr("%1 files").arg(list.count)
            color: Colours.palette.m3outline
            textPointSize: Tokens.font.size.small
            font.family: Tokens.font.family.mono
        }
    }

    StyledListView {
        id: list

        model: FileSystemModel {
            path: Paths.recsdir
            nameFilters: ["Recording_*.mp4"]
            sortReverse: true
        }

        Layout.fillWidth: true
        Layout.preferredHeight: {
            if (list.count === 0)
                return 88;
            const row = 52;
            const gap = Tokens.spacing.small;
            const n = Math.min(list.count, 4);
            return n * row + Math.max(0, n - 1) * gap;
        }
        clip: true
        spacing: Tokens.spacing.small
        boundsBehavior: Flickable.StopAtBounds
        edgeFades: false
        animatePopulate: true

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: list
        }

        Behavior on Layout.preferredHeight {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        onCountChanged: {
            if (root.selectedIndex >= count)
                root.selectedIndex = count > 0 ? count - 1 : -1;
        }

        delegate: Item {
            id: recording

            required property FileSystemEntry modelData
            required property int index
            property string baseName

            width: list.width
            height: 52

            Component.onCompleted: baseName = modelData.baseName

            readonly property bool selected: root.selectedIndex === index || rowHover.hovered

            readonly property var parsed: {
                const time = recording.baseName;
                const matches = time.match(/^Recording_(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})/);
                if (!matches)
                    return {
                        title: time,
                        sub: ""
                    };
                const date = new Date(parseInt(matches[1]), parseInt(matches[2]) - 1, parseInt(matches[3]), parseInt(matches[4]), parseInt(matches[5]), parseInt(matches[6]));
                return {
                    title: Qt.formatDateTime(date, "h:mm AP"),
                    sub: Qt.formatDate(date, Qt.DefaultLocaleShortDate)
                };
            }

            AnimatedScrollItem {
                anchors.fill: parent
                view: list

                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.normal
                    color: recording.selected
                        ? Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.62)
                        : Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.38)
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, recording.selected ? 0.42 : 0.22)

                    Behavior on color {
                        CAnim {}
                    }
                    Behavior on border.color {
                        CAnim {}
                    }

                    HoverHandler {
                        id: rowHover
                        onHoveredChanged: {
                            if (hovered)
                                root.selectedIndex = recording.index;
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.small
                        spacing: Tokens.spacing.small

                        StyledRect {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignVCenter
                            radius: Tokens.rounding.small
                            color: Qt.alpha(Colours.palette.m3secondaryContainer, 0.55)

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "movie"
                                fill: 1
                                color: Colours.palette.m3onSecondaryContainer
                                iconPointSize: Tokens.font.size.normal
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: recording.parsed.title.length ? qsTr("Recording · %1").arg(recording.parsed.title) : recording.parsed.title
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                                textPointSize: Tokens.font.size.small
                                font.weight: Font.Medium
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: recording.parsed.sub.length > 0
                                text: recording.parsed.sub
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                                textPointSize: Tokens.font.size.small
                                font.family: Tokens.font.family.mono
                                opacity: 0.85
                            }
                        }

                        StyledRect {
                            Layout.alignment: Qt.AlignVCenter
                            implicitHeight: 32
                            implicitWidth: actionRow.implicitWidth + 6
                            radius: height / 2
                            color: Qt.alpha(Colours.palette.m3onSurface, recording.selected ? 0.1 : 0.05)
                            border.width: 1
                            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.22)

                            Behavior on color {
                                CAnim {}
                            }

                            Row {
                                id: actionRow
                                anchors.centerIn: parent
                                spacing: 0

                                IconButton {
                                    type: IconButton.Text
                                    icon: "play_arrow"
                                    iconPointSize: Tokens.font.size.normal
                                    implicitWidth: 30
                                    implicitHeight: 30
                                    onClicked: {
                                        root.visibilities.qspanel = false;
                                        root.visibilities.notificationcenter = false;
                                        Quickshell.execDetached(["app2unit", "--", ...Config.general.apps.playback, recording.modelData.path]);
                                    }
                                }
                                IconButton {
                                    type: IconButton.Text
                                    icon: "folder_open"
                                    iconPointSize: Tokens.font.size.normal
                                    implicitWidth: 30
                                    implicitHeight: 30
                                    onClicked: {
                                        root.visibilities.qspanel = false;
                                        root.visibilities.notificationcenter = false;
                                        Quickshell.execDetached(["app2unit", "--", ...Config.general.apps.explorer, recording.modelData.path]);
                                    }
                                }
                                IconButton {
                                    type: IconButton.Text
                                    icon: "content_copy"
                                    iconPointSize: Tokens.font.size.normal
                                    implicitWidth: 30
                                    implicitHeight: 30
                                    onClicked: Quickshell.execDetached(["wl-copy", recording.modelData.path])
                                }
                                IconButton {
                                    type: IconButton.Text
                                    icon: "delete"
                                    iconPointSize: Tokens.font.size.normal
                                    implicitWidth: 30
                                    implicitHeight: 30
                                    label.color: Colours.palette.m3error
                                    stateLayer.color: Colours.palette.m3error
                                    onClicked: root.props.recordingConfirmDelete = recording.modelData.path
                                }
                            }
                        }
                    }
                }
            }
        }

        Loader {
            asynchronous: true
            anchors.centerIn: parent
            opacity: list.count === 0 ? 1 : 0
            active: opacity > 0

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.small

                StyledRect {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 44
                    implicitHeight: 44
                    radius: Tokens.rounding.normal
                    color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.5)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "videocam_off"
                        color: Colours.palette.m3outline
                        iconPointSize: Tokens.font.size.large
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No recordings yet")
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.small
                    font.weight: Font.Medium
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Captures land here after you stop")
                    color: Colours.palette.m3outline
                    textPointSize: Tokens.font.size.small
                    opacity: 0.85
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }
    }
}
