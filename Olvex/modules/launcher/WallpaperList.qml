pragma ComponentBehavior: Bound

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
    property bool suppressPreview: false

    function selectMode(nextMode: string): void {
        if (root.mode === nextMode)
            return;
        root.userModeLock = true;
        Visibilities.launcherInterrupted = true;
        root.visibilities.wallpaperLauncher = true;
        root.mode = nextMode;
        Qt.callLater(() => root.search.forceActiveFocus());
    }

    readonly property alias currentItem: view.currentItem
    readonly property alias count: view.count
    readonly property alias currentIndex: view.currentIndex

    function decrementCurrentIndex() {
        view.decrementCurrentIndex();
    }

    function incrementCurrentIndex() {
        view.incrementCurrentIndex();
    }

    function suspend(): void {
        Wallpapers.stopPreview();
        view.currentIndex = 0;
        scriptModel.values = [];
    }

    function resume(): void {
        scriptModel.updateValues();
        Qt.callLater(() => view.jumpToCurrent(true));
    }

    implicitWidth: view.implicitWidth
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

            TextButton {
                text: qsTr("Static")
                checked: root.mode === "static"
                toggle: false
                type: TextButton.Tonal
                onClicked: root.selectMode("static")
            }

            TextButton {
                text: qsTr("Live")
                checked: root.mode === "live"
                toggle: false
                type: TextButton.Tonal
                onClicked: root.selectMode("live")
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

    PathView {
        id: view

        anchors.top: tabs.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        width: implicitWidth
        height: implicitHeight

        readonly property int itemWidth: Tokens.sizes.launcher.wallpaperWidth * 0.8 + Tokens.padding.larger * 2

        readonly property int numItems: {
            const screen = (QsWindow.window as QsWindow)?.screen;
            if (!screen) {
                const maxItems = Config.launcher.maxWallpapers;
                const visible = Math.min(maxItems, scriptModel.values.length);
                if (visible === 2) return 1;
                if (visible > 1 && visible % 2 === 0) return visible - 1;
                return Math.max(1, visible);
            }

            // Guard Config.border access: use safe default object when unavailable
            const _safeBorder = (typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0};
            const barMargins = Math.max(_safeBorder.thickness, root.panels.bar.implicitWidth);
            let outerMargins = 0;
            if (root.panels.popouts.hasCurrent && root.panels.popouts.currentCenter + root.panels.popouts.nonAnimHeight / 2 > screen.height - root.content.implicitHeight - ((Config && ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})) ? ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0}) : ({thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})).thickness * 2)
                outerMargins = root.panels.popouts.nonAnimWidth;
            if (root.visibilities.utilities && root.panels.utilities.implicitWidth > outerMargins)
                outerMargins = root.panels.utilities.implicitWidth;
            const maxWidth = screen.width - _safeBorder.rounding * 4 - (barMargins + outerMargins) * 2;

            if (maxWidth <= 0) return 0;

            const maxItemsOnScreen = Math.floor(maxWidth / itemWidth);
            const visible = Math.min(maxItemsOnScreen, Config.launcher.maxWallpapers, scriptModel.values.length);

            if (visible === 2) return 1;
            if (visible > 1 && visible % 2 === 0) return visible - 1;
            return Math.max(1, visible);
        }

        model: ScriptModel {
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
                root.suppressPreview = true;
                scriptModel.updateValues();
                Qt.callLater(() => {
                    view.jumpToCurrent(false);
                    root.suppressPreview = false;
                    root.search.forceActiveFocus();
                });
            }
        }

        function jumpToCurrent(autoSwitch) {
            if (autoSwitch && root.userModeLock)
                autoSwitch = false;

            const current = Wallpapers.actualCurrent;
            const isLive = Wallpapers.isVideoPath(current);
            
            // Auto-switch mode to match current wallpaper type if we are not searching
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
                currentIndex = idx;
            } else if (scriptModel.values.length > 0) {
                currentIndex = 0;
            }
        }

        Connections {
            target: root.visibilities
            function onWallpaperLauncherChanged() {
                if (root.visibilities.wallpaperLauncher) {
                    root.userModeLock = false;
                    view.jumpToCurrent(true);
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
                    view.jumpToCurrent(true);
                }
            }
        }

        Component.onCompleted: Qt.callLater(() => jumpToCurrent(true))
        Component.onDestruction: Wallpapers.stopPreview()

        Keys.onLeftPressed: event => {
            decrementCurrentIndex();
            event.accepted = true;
        }
        Keys.onRightPressed: event => {
            incrementCurrentIndex();
            event.accepted = true;
        }
        Keys.onReturnPressed: event => {
            if (currentItem)
                currentItem.select?.();
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            onWheel: wheel => {
                if (wheel.angleDelta.y > 0) view.decrementCurrentIndex();
                else view.incrementCurrentIndex();
            }
        }

        Timer {
            id: previewTimer
            interval: 150
            repeat: false
            property string pendingPath: ""
            onTriggered: {
                if (pendingPath) {
                    Wallpapers.preview(pendingPath);
                }
            }
        }

        onCurrentItemChanged: {
            if (root.suppressPreview)
                return;
            const item = currentItem;
            if (item?.hasEntry && item.modelData?.path) {
                previewTimer.stop();
                previewTimer.pendingPath = item.modelData.path;
                previewTimer.start();
            }
        }

        readonly property int visibleItemCount: count > 0 ? Math.min(numItems, count) : 0

        implicitWidth: Math.max(1, visibleItemCount) * itemWidth
        implicitHeight: Tokens.sizes.launcher.wallpaperHeight
        pathItemCount: visibleItemCount
        cacheItemCount: 4

        snapMode: PathView.SnapToItem
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        highlightMoveDuration: Tokens.anim.durations.large

        delegate: WallpaperItem { visibilities: root.visibilities }

        path: Path {
            startY: view.height / 2
            PathAttribute { name: "z"; value: 0 }
            PathLine { x: view.width / 2; relativeY: 0 }
            PathAttribute { name: "z"; value: 1 }
            PathLine { x: view.width; relativeY: 0 }
        }
    }
}
