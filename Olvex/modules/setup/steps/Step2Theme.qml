import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import "../../settings/ui"
import ".."

// Step 2: theme mode + wallpaper + palette preview (local mock palette).
Item {
    id: root

    required property var wiz
    required property var backend

    readonly property var currentWallpaper: (wiz.wallpaperIdx >= 0 && wiz.wallpaperIdx < wiz.wallpapers.length) ? wiz.wallpapers[wiz.wallpaperIdx] : null
    readonly property var currentPalette: wiz.palette(currentWallpaper ? currentWallpaper.hue : 0.60)

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.topMargin: 8
        anchors.bottomMargin: 12
        spacing: 11

        StepHeader {
            order: 0
            title: qsTr("Choose your look")
            subtitle: qsTr("Pick a theme mode and a wallpaper. Olvex builds the colors from it.")
        }

        Stagger {
            order: 1
            Layout.fillWidth: true

            Segmented {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                model: root.wiz.themeModeNames.map(n => ({ label: n }))
                currentIndex: root.wiz.themeMode
                onSelected: index => {
                    root.wiz.themeMode = index;
                    root.backend.applyThemeMode(root.wiz.themeModeIds[index]);
                }
            }
        }

        Stagger {
            order: 2
            Layout.fillWidth: true

            SettingRow {
                Layout.fillWidth: true
                implicitHeight: 66
                icon: "opacity"
                title: qsTr("Transparency")
                description: qsTr("See-through panels and dialogs with background blur")
                isSingleInGroup: true
                clickable: true
                customCardColor: root.wiz.cardColor(2)
                customCardHoverColor: root.wiz.cardHoverColor(3)
                onClicked: swTransparency.toggle()

                StyledSwitch {
                    id: swTransparency
                    checked: root.wiz.transparency
                    onToggled: {
                        root.wiz.transparency = checked;
                        root.backend.applyTransparency(checked);
                    }
                }
            }
        }

        Stagger {
            order: 3
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: wallGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 264
                Layout.maximumHeight: 264
                implicitWidth: 844
                implicitHeight: 264
                cellWidth: Math.max(200, Math.floor(width / 3))
                cellHeight: 132
                clip: true
                cacheBuffer: 132
                boundsBehavior: Flickable.DragAndOvershootBounds
                flickDeceleration: 2200
                maximumFlickVelocity: 3200
                model: root.wiz.wallpapers

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: wallGrid
                }

                delegate: Item {
                    id: cellItem

                    required property var modelData
                    required property int index
                    readonly property bool selected: root.wiz.wallpaperApplied && root.wiz.wallpaperIdx === index

                    width: wallGrid.cellWidth
                    height: wallGrid.cellHeight

                    StyledClippingRect {
                        id: tile

                        anchors.fill: parent
                        anchors.leftMargin: (cellItem.index % 3 === 0) ? 0 : 5
                        anchors.rightMargin: (cellItem.index % 3 === 2) ? 0 : 5
                        anchors.topMargin: 0
                        anchors.bottomMargin: 8
                        radius: 16
                        border.width: cellItem.selected ? 2.5 : (tileMouse.containsMouse ? 1.5 : 0)
                        border.color: cellItem.selected ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3primary, 0.5)
                        color: "transparent"

                        Behavior on border.color { CAnim {} }

                        Image {
                            anchors.fill: parent
                            source: {
                                const p = cellItem.modelData.path;
                                if (!p) return "";
                                return p.startsWith("file:") ? p : ("file://" + p);
                            }
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            antialiasing: true
                            mipmap: true
                            sourceSize.width: 480
                            sourceSize.height: 300
                        }

                        // Gradient scrim for consistent white text legibility
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.42; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.alpha("black", 0.72) }
                            }
                        }

                        StyledText {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            text: cellItem.modelData.name
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.smaller
                            color: "white"
                            elide: Text.ElideRight
                        }

                        StyledRect {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: 12
                            color: Colours.palette.m3primary
                            border.width: 0
                            border.color: "transparent"
                            opacity: cellItem.selected ? 1.0 : 0.0
                            scale: cellItem.selected ? 1.0 : 0.75

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 160
                                }
                            }

                            Behavior on scale {
                                Anim {
                                    type: Anim.FastSpatial
                                }
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "check"
                                iconPointSize: 15
                                color: Colours.palette.m3onPrimary
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (root.wiz.wallpaperIdx !== cellItem.index || !root.wiz.wallpaperApplied) {
                                    root.wiz.wallpaperIdx = cellItem.index;
                                    root.wiz.wallpaperApplied = true;
                                    SetupFactory.wallpaperRevealed = true;
                                    root.backend.applyWallpaper(cellItem.modelData.path);
                                }
                            }
                        }
                    }
                }
            }
        }

        Stagger {
            order: 4
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                StyledText {
                    text: qsTr("Generated palette")
                    textPointSize: Tokens.font.size.smaller
                    font.weight: Font.Medium
                    color: Colours.light ? Qt.alpha(Colours.palette.m3onSurface, 0.82) : Colours.palette.m3onSurfaceVariant
                }

                Repeater {
                    model: root.currentPalette

                    delegate: RowLayout {
                        required property var modelData

                        spacing: 6

                        Rectangle {
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 11
                            color: modelData.color
                            border.width: 0
                            border.color: "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        StyledText {
                            text: modelData.label
                            textPointSize: Tokens.font.size.smaller
                            color: Colours.palette.m3onSurface
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }
}

