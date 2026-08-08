
import QtQuick
import Quickshell
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

/// Independent Wallpaper Selector drawer.
/// Controlled by `visibilities.wallpaperLauncher`. Completely decoupled from
/// the app launcher — no shared state, no shared search field.
Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property var panels

    readonly property bool shouldBeActive: visibilities.wallpaperLauncher

    // Padding/rounding constants — mirror what Content.qml uses
    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.large

    // Slide-up offset: 0 = visible, 1 = hidden below screen
    property real offsetScale: shouldBeActive ? 0 : 1

    Behavior on offsetScale {
        Anim { type: Anim.DefaultSpatial }
    }

    // Freeze size on close so the animation doesn't glitch
    Timer {
        id: teardownGrace
        interval: Tokens.anim.durations.large + 100
    }

    onShouldBeActiveChanged: {
        if (shouldBeActive) {
            teardownGrace.stop();
            implicitHeight = Qt.binding(() => innerContent.implicitHeight);
        } else {
            teardownGrace.restart();
            implicitHeight = implicitHeight; // break binding — freeze height for exit anim
        }
    }

    visible: offsetScale < 1
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    implicitHeight: innerContent.implicitHeight

    // ── Inner content ──────────────────────────────────────────────────────
    Item {
        id: innerContent

        // Height = tabs row + carousel + search bar + spacing
        // We use explicit sizes since WallpaperList uses anchors.fill (doesn't propagate implicitHeight)
        readonly property int carouselHeight: Tokens.sizes.launcher.wallpaperHeight
        readonly property int tabsHeight:     40  // approx TextButton row height
        implicitHeight: tabsHeight + carouselHeight + searchWrapper.implicitHeight + root.padding * 3

        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom

        // Wallpaper list (loader keeps it inactive while hidden to save memory)
        Loader {
            id: listLoader

            active: root.shouldBeActive || teardownGrace.running

            anchors.top:    parent.top
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.bottom: searchWrapper.top
            anchors.bottomMargin: root.padding

            sourceComponent: WallpaperList {
                // WallpaperList requires a search field — provide the local one
                search:      wallpaperSearch
                visibilities: root.visibilities
                panels:      root.panels
                content:     root
            }
        }

        // ── Search bar ────────────────────────────────────────────────────
        StyledRect {
            id: searchWrapper

            color: wallpaperSearch.activeFocus ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 2) : Colours.layer(Colours.palette.m3surfaceContainer, 2)
            radius: Tokens.rounding.full
            border.color: wallpaperSearch.activeFocus ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
            border.width: wallpaperSearch.activeFocus ? 2 : 1

            Behavior on border.color { CAnim {} }
            Behavior on color { CAnim {} }

            anchors.left:    parent.left
            anchors.right:   parent.right
            anchors.bottom:  parent.bottom
            anchors.margins: root.padding

            implicitHeight: Math.max(searchIcon.implicitHeight,
                                     wallpaperSearch.implicitHeight,
                                     clearIcon.implicitHeight)

            MaterialIcon {
                id: searchIcon
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: root.padding
                text: "wallpaper_slideshow"
                color: wallpaperSearch.activeFocus ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant

                Behavior on color { CAnim {} }
            }

            StyledTextField {
                id: wallpaperSearch

                background: null

                anchors.left:        searchIcon.right
                anchors.right:       clearIcon.left
                anchors.leftMargin:  Tokens.spacing.small
                anchors.rightMargin: Tokens.spacing.small

                topPadding:    Tokens.padding.larger
                bottomPadding: Tokens.padding.larger

                placeholderText: qsTr("Search wallpapers…")

                Keys.priority: Keys.BeforeItem
                Keys.onLeftPressed:  listLoader.item?.decrementCurrentIndex?.()
                Keys.onRightPressed: listLoader.item?.incrementCurrentIndex?.()
                Keys.onEscapePressed: {
                    root.visibilities.wallpaperLauncher = false;
                    event.accepted = true;
                }
                Keys.onReturnPressed: {
                    const cur = listLoader.item?.currentItem;
                    if (cur) cur.select?.();
                    event.accepted = true;
                }

                Timer {
                    id: focusTimer
                    interval: 50
                    repeat: true
                    property int attempts: 0
                    onTriggered: {
                        if (wallpaperSearch.activeFocus || attempts >= 20) {
                            stop();
                        } else {
                            wallpaperSearch.forceActiveFocus();
                            attempts++;
                        }
                    }
                }
            }

            MaterialIcon {
                id: clearIcon
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: root.padding

                width:   wallpaperSearch.text ? implicitWidth : implicitWidth / 2
                opacity: {
                    if (!wallpaperSearch.text) return 0;
                    if (clearMouse.pressed)    return 0.7;
                    if (clearMouse.containsMouse) return 0.8;
                    return 1;
                }
                text:  "close"
                color: Colours.palette.m3onSurfaceVariant

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: wallpaperSearch.text ? Qt.PointingHandCursor : undefined
                    onClicked: wallpaperSearch.text = ""
                }

                Behavior on width   { Anim { type: Anim.StandardSmall } }
                Behavior on opacity { Anim { type: Anim.StandardSmall } }
            }
        }
    }

    // ── Visibility lifecycle ───────────────────────────────────────────────
    Connections {
        target: root.visibilities
        function onWallpaperLauncherChanged(): void {
            if (root.visibilities.wallpaperLauncher) {
                // Opened
                wallpaperSearch.text = "";
                listLoader.item?.resume?.();
                wallpaperSearch.forceActiveFocus();
                focusTimer.attempts = 0;
                focusTimer.start();
            } else {
                // Closed
                wallpaperSearch.text = "";
                listLoader.item?.suspend?.();
                focusTimer.stop();
            }
        }
    }
}
