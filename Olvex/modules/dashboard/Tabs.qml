pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services

Item {
    id: root

    required property real nonAnimWidth
    required property DashboardState dashState
    required property var tabs

    readonly property int count: tabs ? tabs.length : 0
    readonly property real trackInset: 4
    readonly property real segmentWidth: Math.max(148, Math.min(180, (root.nonAnimWidth - root.trackInset * 2) / Math.max(count, 1)))
    readonly property real totalTrackWidth: Math.min(nonAnimWidth, (segmentWidth * Math.max(count, 1)) + (trackInset * 2))
    readonly property int safeIndex: Math.max(0, Math.min(dashState.currentTab, Math.max(count - 1, 0)))

    implicitHeight: 52

    // Centered M3 Expressive Pill Track
    StyledRect {
        id: track

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: root.totalTrackWidth
        height: 44
        radius: height / 2
        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.5)
        border.width: 0

        // Sliding Primary Indicator Pill
        StyledRect {
            id: indicator

            x: root.trackInset + root.safeIndex * root.segmentWidth
            y: root.trackInset
            width: root.segmentWidth
            height: track.height - root.trackInset * 2
            radius: height / 2
            color: Colours.palette.m3primary
            z: 0

            Behavior on x {
                Anim { type: Anim.DefaultSpatial }
            }
            Behavior on width {
                Anim { type: Anim.DefaultSpatial }
            }

            border.width: 0
        }

        // Segment Tabs Row
        Row {
            anchors.fill: parent
            anchors.margins: root.trackInset
            spacing: 0
            z: 1

            Repeater {
                model: root.tabs

                delegate: Item {
                    id: cell

                    required property var modelData
                    required property int index

                    readonly property bool isCurrent: root.dashState.currentTab === index

                    width: root.segmentWidth
                    height: parent.height

                    Row {
                        id: cellContent
                        anchors.centerIn: parent
                        spacing: Tokens?.spacing?.small ?? 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cell.modelData.iconName
                            fill: cell.isCurrent ? 1 : 0
                            iconPointSize: (Tokens?.font?.size?.normal ?? 13) + 1
                            color: cell.isCurrent ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                            Behavior on color {
                                CAnim {}
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cell.modelData.text
                            font.family: Tokens?.font?.family?.sans ?? "sans-serif"
                            font.weight: cell.isCurrent ? Font.DemiBold : Font.Medium
                            font.letterSpacing: 0.2
                            textPointSize: Tokens?.font?.size?.small ?? 12
                            color: cell.isCurrent ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                            Behavior on color {
                                CAnim {}
                            }
                        }
                    }

                    // Subtle smooth hover highlight pill matching Olvex slider switches
                    StyledRect {
                        anchors.fill: parent
                        radius: height / 2
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.05)
                        opacity: cellState.containsMouse && !cell.isCurrent && !cellState.pressed ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                    }

                    StateLayer {
                        id: cellState
                        anchors.fill: parent
                        radius: height / 2
                        showHoverBackground: false
                        color: cell.isCurrent ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        onClicked: root.dashState.currentTab = cell.index
                    }
                }
            }
        }
    }
}
