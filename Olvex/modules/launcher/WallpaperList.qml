
import "items"
import QtQuick
import Quickshell
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property StyledTextField search
    required property var visibilities
    required property var panels
    required property var content

    property string mode: "static"
    property bool userModeLock: false


    function selectMode(nextMode: string): void {
        if (root.mode === nextMode)
            return;
        root.userModeLock = true;
        Visibilities.launcherInterrupted = true;
        root.visibilities.wallpaperLauncher = true;
        root.mode = nextMode;
        Qt.callLater(() => root.search.forceActiveFocus());
    }

    readonly property alias currentIndex: view.currentIndex
    readonly property int count: scriptModel.values.length

    function decrementCurrentIndex() {
        view.decrementCurrentIndex();
    }

    function incrementCurrentIndex() {
        view.incrementCurrentIndex();
    }

    function applyWallpaper(path, index) {
        if (!path) return;
        console.log("[WallpaperList] Direct apply wallpaper:", path, "at index:", index);
        Wallpapers.setWallpaper(path);
        if (typeof index === "number" && index >= 0) {
            view.snapTo(index);
        }
    }

    function suspend(): void {
        // Keep scriptModel.values intact so thumbnails stay cached in memory
    }

    function resume(): void {
        scriptModel.updateValues();
        Qt.callLater(() => view.jumpToCurrent(true));
    }

    anchors.fill: parent
    implicitHeight: tabs.height + view.implicitHeight + Tokens.padding.normal

    Item {
        id: tabs

        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight + Tokens.spacing.normal
        height: implicitHeight

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        Row {
            id: row

            spacing: Tokens.spacing.small

            // Sliding Segmented Mode Switch (Standalone Clipboard & Settings FilterButtonGroup design)
            StyledRect {
                id: sliderSwitch

                height: 40
                implicitWidth: 184
                radius: height / 2
                color: Colours.palette.m3secondaryContainer

                readonly property bool isLive: root.mode === "live"
                readonly property real inset: 4
                readonly property real segW: (width - inset * 2) / 2

                // Sliding primary indicator thumb
                StyledRect {
                    id: thumb

                    y: sliderSwitch.inset
                    height: parent.height - sliderSwitch.inset * 2
                    width: sliderSwitch.segW
                    x: sliderSwitch.inset + (sliderSwitch.isLive ? 1 : 0) * sliderSwitch.segW
                    radius: height / 2
                    color: Colours.palette.m3primary
                    z: 0

                    Behavior on x {
                        Anim { type: Anim.FastSpatial }
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: sliderSwitch.inset
                    z: 1

                    // Static Segment
                    Item {
                        width: sliderSwitch.segW
                        height: parent.height

                        Row {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.extraSmall || 6

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "image"
                                scale: !sliderSwitch.isLive ? 1.12 : 1.0
                                iconPointSize: Tokens.font.size.normal || 14
                                color: !sliderSwitch.isLive ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                                Behavior on color { CAnim {} }
                                Behavior on scale { Anim {} }
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Static")
                                textPointSize: Tokens.font.size.smaller || 12
                                font.weight: !sliderSwitch.isLive ? Font.DemiBold : Font.Normal
                                color: !sliderSwitch.isLive ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                                Behavior on color { CAnim {} }
                            }
                        }

                        StateLayer {
                            anchors.fill: parent
                            radius: height / 2
                            color: !sliderSwitch.isLive ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            onClicked: root.selectMode("static")
                        }
                    }

                    // Live Segment
                    Item {
                        width: sliderSwitch.segW
                        height: parent.height

                        Row {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.extraSmall || 6

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "movie"
                                scale: sliderSwitch.isLive ? 1.12 : 1.0
                                iconPointSize: Tokens.font.size.normal || 14
                                color: sliderSwitch.isLive ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                                Behavior on color { CAnim {} }
                                Behavior on scale { Anim {} }
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Live")
                                textPointSize: Tokens.font.size.smaller || 12
                                font.weight: sliderSwitch.isLive ? Font.DemiBold : Font.Normal
                                color: sliderSwitch.isLive ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                                Behavior on color { CAnim {} }
                            }
                        }

                        StateLayer {
                            anchors.fill: parent
                            radius: height / 2
                            color: sliderSwitch.isLive ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            onClicked: root.selectMode("live")
                        }
                    }
                }
            }

            Item {
                width: Tokens.spacing.normal
                height: 1
            }

            IconButton {
                icon: "loop"
                type: IconButton.Tonal
                enabled: !Wallpapers.isVideoPath(Wallpapers.current)
                checked: GlobalConfig.background?.wallpaperCycling?.enabled ?? false
                onClicked: {
                    if (GlobalConfig.background?.wallpaperCycling) {
                        const next = !GlobalConfig.background.wallpaperCycling.enabled;
                        console.log("[WallpaperList] Toggling cycling to:", next);
                        GlobalConfig.background.wallpaperCycling.enabled = next;
                    }
                }
            }
        }
    }

    M3Carousel {
        id: view

        anchors.top:   tabs.bottom
        anchors.left:  parent.left
        anchors.right: parent.right

        layout: "heroCenter"
        itemHeight: Tokens.sizes.launcher.wallpaperHeight
        model: scriptModel.values



        onItemClicked: (index, itemData) => {
            if (itemData && itemData.path) {
                console.log("[WallpaperList] onItemClicked:", itemData.path);
                Wallpapers.setWallpaper(itemData.path);
            }
        }

        delegate: Item {
            id: itemCell
            property var modelData
            property int index
            property real parallaxOffset: 0
            property bool isCurrent: false

            readonly property bool hasEntry: itemCell.modelData !== null && itemCell.modelData !== undefined

            Image {
                id: img
                anchors.fill: parent
                source: {
                    if (!itemCell.hasEntry) return "";
                    const p = itemCell.modelData.path;
                    if (!p) return "";
                    if (itemCell.modelData.isVideo || Wallpapers.isVideoPath(p)) {
                        const _ = Wallpapers.thumbnailUpdateCount;
                        const thumb = Wallpapers.videoThumbnailMap[p] || Wallpapers.thumbnailPathFor(p);
                        return thumb ? (thumb.startsWith("file://") ? thumb : "file://" + thumb) : "";
                    }
                    return p.startsWith("file://") ? p : "file://" + p;
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: 1
            }

            // Loading placeholder
            Rectangle {
                anchors.fill: parent
                visible: img.status !== Image.Ready
                color: Colours.tPalette.m3surfaceContainerHigh
                StyledText {
                    anchors.centerIn: parent
                    text: itemCell.hasEntry && itemCell.modelData.name ? itemCell.modelData.name.charAt(0) : ""
                    font.pixelSize: 32
                    font.weight: 600
                    color: Colours.tPalette.m3onSurfaceVariant
                    opacity: 0.4
                }
            }

            // Bottom title gradient overlay
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 52
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: "#CC000000" }
                }
                opacity: itemCell.isCurrent ? 1 : 0.7
                Behavior on opacity { NumberAnimation { duration: 200 } }

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.padding.normal
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.padding.normal
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Tokens.padding.small
                    text: itemCell.hasEntry && itemCell.modelData.name ? itemCell.modelData.name : ""
                    color: "#FFFFFF"
                    font.pixelSize: 12
                    font.weight: itemCell.isCurrent ? 600 : 400
                    elide: Text.ElideRight
                }
            }
        }

        ScriptModel {
            id: scriptModel

            readonly property string searchQuery: root.search.text.split(" ").slice(1).join(" ")

            function updateValues() {
                const results = Wallpapers.query(searchQuery) || [];
                const statics = results.filter(w => !w.isVideo);
                const lives = results.filter(w => w.isVideo);
                console.log(`[WallpaperList] updateValues() mode=${root.mode} | total=${results.length} | static=${statics.length} | live=${lives.length}`);
                values = root.mode === "static" ? statics : lives;
            }

            onSearchQueryChanged: updateValues()
            Component.onCompleted: updateValues()
        }

        Connections {
            target: Wallpapers
            function onCatalogChanged() {
                scriptModel.updateValues();
                Qt.callLater(() => view.jumpToCurrent(false));
            }
            function onThumbnailUpdateCountChanged() {
                scriptModel.updateValues();
            }
        }

        Connections {
            target: root
            function onModeChanged() {
                scriptModel.updateValues();
                Qt.callLater(() => {
                    view.jumpToCurrent(false);
                    root.search.forceActiveFocus();
                });
            }
        }

        function jumpToCurrent(autoSwitch, animate = false) {
            if (autoSwitch && root.userModeLock)
                autoSwitch = false;

            const current = Wallpapers.actualCurrent;
            const isLive = Wallpapers.isVideoPath(current);
            
            if (autoSwitch && scriptModel.searchQuery === "") {
                if (isLive && root.mode !== "live") {
                    root.mode = "live";
                    return;
                } else if (!isLive && root.mode !== "static") {
                    root.mode = "static";
                    return;
                }
            }

            const idx = scriptModel.values.findIndex(w => w && w.path === current);
            console.log(`[WallpaperList] jumpToCurrent: ${current} (idx: ${idx}, modelCount: ${scriptModel.values.length})`);
            if (idx !== -1) {
                if (animate) view.snapTo(idx);
                else view.jumpTo(idx);
            } else if (scriptModel.values.length > 0) {
                if (animate) view.snapTo(0);
                else view.jumpTo(0);
            }
        }

        Connections {
            target: root.visibilities
            function onWallpaperLauncherChanged() {
                if (root.visibilities.wallpaperLauncher) {
                    root.userModeLock = false;
                    view.jumpToCurrent(true, false);
                } else {
                    root.userModeLock = false;
                    Wallpapers.stopPreview();
                }
            }
        }

        Connections {
            target: Wallpapers
            function onActualCurrentChanged() {
                if (root.visibilities.wallpaperLauncher && !root.userModeLock) {
                    view.jumpToCurrent(true, true);
                }
            }
        }

        Component.onCompleted: Qt.callLater(() => jumpToCurrent(true, false))
        Component.onDestruction: Wallpapers.stopPreview()

        Shortcut {
            sequences: ["Left"]
            enabled: root.visibilities.wallpaperLauncher
            onActivated: view.decrementCurrentIndex()
        }

        Shortcut {
            sequences: ["Right"]
            enabled: root.visibilities.wallpaperLauncher
            onActivated: view.incrementCurrentIndex()
        }

        Shortcut {
            sequences: ["Return", "Enter"]
            enabled: root.visibilities.wallpaperLauncher
            onActivated: {
                const itemData = scriptModel.values[view.currentIndex];
                if (itemData && itemData.path) {
                    root.applyWallpaper(itemData.path, view.currentIndex);
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) view.decrementCurrentIndex();
                else if (wheel.angleDelta.y < 0) view.incrementCurrentIndex();
                wheel.accepted = true;
            }
        }


    }
}
