pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import Olvex.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property var lock

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    readonly property bool hasActiveMedia: !!Players.active && Players.active.playbackStatus !== "Stopped"
    property real playerProgress: Players.interpolatedProgress

    function lengthStr(length) {
        if (length < 0) return "-1:-1";
        let l = length;
        if (l > 1000000) l /= 1000000;
        const hours = Math.floor(l / 3600);
        const mins = Math.floor((l % 3600) / 60);
        const secs = Math.floor(l % 60).toString().padStart(2, "0");
        if (hours > 0) return `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
        return `${mins}:${secs}`;
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.large

        // ── Art & Info Row (M3 Expressive) ──────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.large

            // Expressive Squircle Art
            StyledClippingRect {
                id: artContainer
                implicitWidth: 84
                implicitHeight: 84
                Layout.alignment: Qt.AlignVCenter
                
                // M3 Expressive shape morphing: more rounded when playing
                radius: root.hasActiveMedia && Players.active?.isPlaying ? 42 : 24
                
                Behavior on radius {
                    Anim { type: Anim.FastSpatial }
                }

                color: Colours.palette.m3surfaceContainerHigh
                border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "music_note"
                    color: Colours.palette.m3onSurfaceVariant
                    iconPointSize: 24
                    visible: artImage.status !== Image.Ready
                }

                Image {
                    id: artImage
                    anchors.fill: parent
                    source: Players.getArtUrl(Players.active)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready && root.hasActiveMedia
                }
            }

            // Typography & Controls Stack
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing.small

                // Emphasized Typography
                StyledText {
                    Layout.fillWidth: true
                    text: root.hasActiveMedia ? (Players.active?.trackTitle || "No media") : "No Active Media"
                    color: Colours.palette.m3onSurface
                    font.family: Tokens.font.family.sans
                    textPointSize: 15
                    font.weight: 800 // M3 Expressive Black/ExtraBold
                    elide: Text.ElideRight
                    
                    Behavior on textPointSize { Anim { type: Anim.FastSpatial } }
                }
                
                StyledText {
                    Layout.fillWidth: true
                    text: root.hasActiveMedia ? (Players.active?.trackArtist || "") : ""
                    color: Colours.palette.m3onSurfaceVariant
                    font.family: Tokens.font.family.sans
                    textPointSize: 11
                    font.weight: 500
                    elide: Text.ElideRight
                }

                // Controls Row embedded next to text for compactness
                RowLayout {
                    Layout.topMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.normal
                    visible: root.hasActiveMedia

                    PlayerControl {
                        icon: "skip_previous"
                        iconPointSize: Math.round(Tokens.font.size.large * 1.3)
                        onClicked: Players.previous()
                    }

                    // Morphing Play/Pause Button
                    PlayerControl {
                        id: playPauseBtn
                        icon: Players.active?.isPlaying ? "pause" : "play_arrow"
                        label.animate: true
                        toggle: true
                        padding: Tokens.padding.normal
                        checked: Players.active?.isPlaying ?? false
                        iconPointSize: Math.round(Tokens.font.size.large * 1.6)
                        onClicked: Players.togglePlaying()
                        
                        // M3 Expressive: Filled style for primary action
                        // Assuming custom style can be achieved via radius/padding
                        Rectangle {
                            anchors.fill: parent
                            z: -1
                            color: Colours.palette.m3primaryContainer
                            radius: parent.radius
                            opacity: 0.2
                        }
                        
                        onIconChanged: iconAnim.start()
                        SequentialAnimation {
                            id: iconAnim
                            NumberAnimation { target: playPauseBtn; property: "scale"; to: 0.8; duration: 150; easing.type: Easing.OutCubic }
                            NumberAnimation { target: playPauseBtn; property: "scale"; to: 1.0; duration: 300; easing.type: Easing.OutElastic }
                        }
                    }

                    PlayerControl {
                        icon: "skip_next"
                        iconPointSize: Math.round(Tokens.font.size.large * 1.3)
                        onClicked: Players.next()
                    }
                }
            }
        }

        // ── Progress Bar (M3 Expressive) ────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: root.hasActiveMedia

            StyledSlider {
                id: slider
                Layout.fillWidth: true
                implicitHeight: Tokens.padding.large
                enabled: !!Players.active
                
                // M3 Expressive: slightly thicker track
                
                onPressedChanged: {
                    if (!pressed) {
                        Players.seekTo(value);
                    }
                }

                Connections {
                    target: root
                    function onPlayerProgressChanged() {
                        if (!slider.pressed) {
                            slider.value = root.playerProgress;
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: root.lengthStr(Players.active ? Players.interpolatedPosition : -1)
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.smaller
                    font.weight: 600
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    text: root.lengthStr(Players.interpolatedLength > 0 ? Players.interpolatedLength : -1)
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.smaller
                    font.weight: 600
                }
            }
        }
    }

    component PlayerControl: IconButton {
        // Expressive shape morphing based on state
        Layout.preferredWidth: implicitWidth + (stateLayer.pressed ? Tokens.padding.large : internalChecked ? Tokens.padding.normal : 0)
        
        // Morph from circle to squircle
        radius: stateLayer.pressed ? height * 0.25 : internalChecked ? height * 0.35 : height / 2
        radiusAnim.duration: Tokens.anim.durations.expressiveFastSpatial
        radiusAnim.easing: Tokens.anim.expressiveFastSpatial

        Behavior on Layout.preferredWidth {
            Anim { type: Anim.FastSpatial }
        }
    }
}
