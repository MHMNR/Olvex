pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    required property var props
    required property DrawerVisibilities visibilities

    property list<MenuItem> menuItems: [
            MenuItem {
                property string activeText: qsTr("Fullscreen")
                icon: "fullscreen"
                text: qsTr("Record fullscreen")
            },
            MenuItem {
                property string activeText: qsTr("Region")
                icon: "screenshot_region"
                text: qsTr("Record region")
            },
            MenuItem {
                property string activeText: qsTr("Fullscreen")
                icon: "select_to_speak"
                text: qsTr("Record fullscreen with sound")
            },
            MenuItem {
                property string activeText: qsTr("Region")
                icon: "volume_up"
                text: qsTr("Record region with sound")
            }
    ]

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2

    radius: Tokens.rounding.normal
    
    color: Colours.tileSurface
    border.width: Colours.light ? 1 : 0
    border.color: Colours.tileStrokeSubtle

    StyledRect {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: Colours.tileShine
        border.width: 1
    }

    StyledRect {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        border.color: Colours.tileShineSoft
        border.width: 1
    }
    clip: true

    Behavior on implicitHeight { Anim {} }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.normal

        ColumnLayout {
            spacing: Tokens.spacing.small
            z: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: qsTr("Screen Recorder")
                    textPointSize: Tokens.font.size.normal
                    font.weight: Font.DemiBold
                    color: Colours.palette.m3onSurface
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                // Original split action: [ mode · start ] + [ chevron / stop ]
                RowLayout {
                    spacing: Recorder.running ? Tokens.spacing.small : 2
                    Behavior on spacing {
                        Anim {}
                    }

                    // Left Action Pill (Record / Pause)
                    StyledRect {
                        id: startPill
                        implicitWidth: Recorder.running ? 42 : (modeTextLayout.implicitWidth + Tokens.padding.large * 2)
                        implicitHeight: Recorder.running ? 42 : 36

                        topLeftRadius: 21
                        bottomLeftRadius: 21
                        topRightRadius: Recorder.running ? 21 : 4
                        bottomRightRadius: Recorder.running ? 21 : 4

                        color: Recorder.running
                            ? (Recorder.paused ? Colours.palette.m3tertiary : Colours.palette.m3primary)
                            : Colours.palette.m3primary

                        Behavior on implicitWidth {
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }
                        Behavior on implicitHeight {
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }
                        Behavior on topRightRadius {
                            Anim {
                                type: Anim.FastSpatial
                            }
                        }
                        Behavior on bottomRightRadius {
                            Anim {
                                type: Anim.FastSpatial
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Tokens.anim.durations.small
                            }
                        }

                        RowLayout {
                            id: modeTextLayout
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small
                            visible: !Recorder.running

                            MaterialIcon {
                                text: {
                                    let found = root.menuItems[0];
                                    for (let i = 0; i < root.menuItems.length; i++) {
                                        if (root.props.recordingMode === root.menuItems[i].icon + root.menuItems[i].text) {
                                            found = root.menuItems[i];
                                            break;
                                        }
                                    }
                                    return found.icon;
                                }
                                color: Colours.palette.m3onPrimary
                                iconPointSize: Tokens.font.size.normal
                            }

                            StyledText {
                                text: {
                                    let found = root.menuItems[0];
                                    for (let i = 0; i < root.menuItems.length; i++) {
                                        if (root.props.recordingMode === root.menuItems[i].icon + root.menuItems[i].text) {
                                            found = root.menuItems[i];
                                            break;
                                        }
                                    }
                                    return found.activeText;
                                }
                                color: Colours.palette.m3onPrimary
                                textPointSize: Tokens.font.size.small
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: Recorder.paused ? "play_arrow" : "pause"
                            color: Recorder.paused ? Colours.palette.m3onTertiary : Colours.palette.m3onPrimary
                            iconPointSize: Tokens.font.size.large
                            visible: Recorder.running
                        }

                        StateLayer {
                            id: startPillState
                            anchors.fill: parent
                            topLeftRadius: parent.topLeftRadius
                            bottomLeftRadius: parent.bottomLeftRadius
                            topRightRadius: parent.topRightRadius
                            bottomRightRadius: parent.bottomRightRadius

                            onClicked: {
                                if (Recorder.running) {
                                    Recorder.togglePause();
                                } else {
                                    const args = ["-f", root.props.recordingFps];
                                    let foundIndex = 0;
                                    for (let i = 0; i < root.menuItems.length; i++) {
                                        if (root.props.recordingMode === root.menuItems[i].icon + root.menuItems[i].text) {
                                            foundIndex = i;
                                            break;
                                        }
                                    }
                                    if (foundIndex === 1)
                                        args.push("-r");
                                    else if (foundIndex === 2)
                                        args.push("-s");
                                    else if (foundIndex === 3)
                                        args.push("-sr");
                                    Recorder.start(args);
                                }
                            }
                        }
                    }

                    // Right Action Pill (Dropdown / Stop)
                    StyledRect {
                        id: menuPill
                        implicitWidth: Recorder.running ? 42 : (modeMenu.expanded ? 36 : 48)
                        implicitHeight: Recorder.running ? 42 : 36

                        topRightRadius: 21
                        bottomRightRadius: 21
                        topLeftRadius: Recorder.running ? 21 : (modeMenu.expanded ? 18 : 4)
                        bottomLeftRadius: Recorder.running ? 21 : (modeMenu.expanded ? 18 : 4)

                        color: Recorder.running ? Colours.palette.m3error : Colours.palette.m3primary

                        Behavior on implicitWidth {
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }
                        Behavior on implicitHeight {
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }
                        Behavior on topLeftRadius {
                            Anim {
                                type: Anim.FastSpatial
                            }
                        }
                        Behavior on bottomLeftRadius {
                            Anim {
                                type: Anim.FastSpatial
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Tokens.anim.durations.small
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "keyboard_arrow_down"
                            color: Colours.palette.m3onPrimary
                            iconPointSize: Tokens.font.size.normal
                            rotation: modeMenu.expanded ? 180 : 0
                            visible: !Recorder.running
                            Behavior on rotation {
                                Anim {}
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "stop"
                            color: Colours.palette.m3onError
                            iconPointSize: Tokens.font.size.large
                            visible: Recorder.running
                        }

                        StateLayer {
                            id: menuPillState
                            anchors.fill: parent
                            topLeftRadius: parent.topLeftRadius
                            bottomLeftRadius: parent.bottomLeftRadius
                            topRightRadius: parent.topRightRadius
                            bottomRightRadius: parent.bottomRightRadius
                            onClicked: {
                                if (Recorder.running) {
                                    Recorder.stop();
                                } else {
                                    modeMenu.expanded = true;
                                }
                            }
                        }

                        Menu {
                            id: modeMenu
                            attachTo: menuPill
                            marginX: 110
                            marginY: 8
                            items: root.menuItems
                            onItemSelected: item => {
                                root.props.recordingMode = item.icon + item.text;
                            }
                        }
                    }
                }

                // Timer (Visible only when running)
                StyledText {
                    visible: Recorder.running
                    text: {
                        const elapsed = Recorder.elapsed;
                        const hours = Math.floor(elapsed / 3600);
                        const mins = Math.floor((elapsed % 3600) / 60);
                        const secs = Math.floor(elapsed % 60).toString().padStart(2, "0");
                        if (hours > 0) return `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
                        return `${mins}:${secs}`;
                    }
                    textPointSize: Tokens.font.size.normal
                    font.weight: Font.DemiBold
                    color: Colours.palette.m3onSurface
                    Layout.leftMargin: Tokens.spacing.small
                }

                Item { Layout.fillWidth: true } // Spacer

                // FPS Label + Selector
                RowLayout {
                    spacing: Tokens.spacing.small
                    
                    StyledText {
                        text: "FPS"
                        textPointSize: Tokens.font.size.small
                        font.weight: Font.DemiBold
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledRect {
                        id: fpsSelector
                        implicitHeight: 36
                        implicitWidth: 108
                        radius: 18
                        color: Colours.tileFill
                        
                        // Sliding Indicator
                        StyledRect {
                            id: indicator
                            readonly property var options: ["30", "60", "90"]
                            readonly property int index: options.indexOf(root.props.recordingFps)
                            
                            x: 4 + index * (fpsSelector.width - 8) / 3
                            y: 4
                            width: (fpsSelector.width - 8) / 3
                            height: 28
                            radius: 14
                            color: Colours.palette.m3primary
                            
                            Behavior on x { Anim { type: Anim.DefaultSpatial } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 0
                            
                            Repeater {
                                model: ["30", "60", "90"]
                                delegate: Item {
                                    required property string modelData

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: modelData === root.props.recordingFps ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                        textPointSize: Tokens.font.size.small - 1
                                        
                                        Behavior on color { ColorAnimation { duration: Tokens.anim.durations.small } }
                                    }
                                    
                                    StateLayer {
                                        anchors.fill: parent
                                        radius: 14
                                        onClicked: root.props.recordingFps = modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }


        }
        Loader {
            id: listLoader
            property bool expanded: root.props.recordingListExpanded
            asynchronous: false
            Layout.fillWidth: true
            Layout.preferredHeight: expanded ? implicitHeight : 0
            sourceComponent: expanded ? recordingList : null
        }
    }

    // Expand list — soft tonal chevron (not a loud primary nugget)
    StyledRect {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Tokens.padding.small

        implicitWidth: 40
        implicitHeight: 18
        radius: height / 2
        color: arrowPillState.containsMouse
            ? Colours.palette.m3secondaryContainer
            : Qt.alpha(Colours.palette.m3onSurface, 0.06)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.28)
        Behavior on color {
            CAnim {}
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "keyboard_arrow_down"
            color: Colours.palette.m3onSurfaceVariant
            iconPointSize: Tokens.font.size.small
            rotation: root.props.recordingListExpanded ? 180 : 0
            Behavior on rotation {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
        }

        StateLayer {
            id: arrowPillState
            anchors.fill: parent
            radius: parent.radius
            color: Colours.palette.m3onSurface
            onClicked: root.props.recordingListExpanded = !root.props.recordingListExpanded
        }
    }

    Component {
        id: recordingList

        RecordingList {
            props: root.props
            visibilities: root.visibilities
        }
    }

}
