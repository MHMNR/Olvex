import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import "../../../components/effects"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import M3Shapes
import Olvex
import Olvex.Config
import qs.services
import qs.utils
import qs.components.filedialog

Item {
    id: root

    property Session session
    opacity: 0.0
    transform: Translate { id: yTrans; y: 20 }

    Component.onCompleted: {
        revealAnim.start();
        Wallpapers.ensureCatalog();
        if (Wallpapers.isVideoPath(Wallpapers.actualCurrent)) {
            root.wallpaperMode = "live";
        } else if (GlobalConfig.background && GlobalConfig.background.liveWallpaper && GlobalConfig.background.liveWallpaper.enabled && Wallpapers.liveEntryObjects && Wallpapers.liveEntryObjects.length > 0) {
            root.wallpaperMode = "live";
        } else {
            root.wallpaperMode = "static";
        }
    }

    ParallelAnimation {
        id: revealAnim
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: yTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutCubic }
    }

    // ── Tab state ──
    property int currentTab: 0 // 0: Local (My Wallpapers), 1: Store (Wallhaven)

    // ── Local Wallpaper Mode ──
    property string wallpaperMode: Wallpapers.isVideoPath(Wallpapers.actualCurrent) ? "live" : "static"
    readonly property var transitionTypes: ["fade", "wipe", "disc", "stripes", "iris", "pixelate", "portal", "random"]
    readonly property var clockPositions: ["middle-center", "top-left", "top-center", "top-right", "middle-left", "middle-right", "bottom-left", "bottom-center", "bottom-right"]

    function idxOf(list, val) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === val) return i;
        }
        return 0;
    }

    function setWallpaperMode(mode) {
        root.wallpaperMode = mode === "live" ? "live" : "static";
        if (GlobalConfig.background && GlobalConfig.background.liveWallpaper)
            GlobalConfig.background.liveWallpaper.enabled = root.wallpaperMode === "live";
        Wallpapers.ensureCatalog();
    }

    // ── Store Backend Paths ──
    function getMarketScriptPath() {
        const candidates = [
            "/home/abm/Projects/QS-Config/Github/Olvex/scripts/src/olvex/utils/wallpaper_market.py",
            Paths.home + "/.local/Olvex/scripts/src/olvex/utils/wallpaper_market.py",
            Paths.home + "/Projects/QS-Config/Olvex/scripts/src/olvex/utils/wallpaper_market.py"
        ];
        if (typeof CUtils !== "undefined" && typeof CUtils.fileExists === "function") {
            for (let i = 0; i < candidates.length; i++) {
                if (CUtils.fileExists(candidates[i])) return candidates[i];
            }
        }
        return candidates[0];
    }

    // ── Detail overlay state (container transform from card) ──
    property var detailItem: null
    property var detailInfo: null
    property rect detailSrc: Qt.rect(0, 0, 0, 0)
    property bool detailOpen: false
    property real detailProg: 0.0

    function prettyName(it) {
        if (!it) return "";
        return (it.category || qsTr("Wallpaper")) + " · " + it.id;
    }

    function formatCount(n) {
        if (!n) return "0";
        if (n >= 1000000) return (n / 1000000).toFixed(1) + "M";
        if (n >= 1000) return (n / 1000).toFixed(1) + "k";
        return String(n);
    }

    function fmtSize(b) {
        if (!b) return "—";
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB";
        return Math.round(b / 1024) + " KB";
    }

    function openDetail(item, card) {
        if (!item || !card) return;
        collapseAnim.stop();
        expandAnim.stop();
        const p = card.mapToItem(root, 0, 0);
        detailSrc = Qt.rect(p.x, p.y, card.width, card.height);
        detailProg = 0.0;
        detailItem = item;
        detailInfo = null;
        detailOpen = true;
        expandAnim.restart();
        infoProc.command = ["python3", getMarketScriptPath(), "info", item.id];
        infoProc.running = false;
        infoProc.running = true;
    }

    function closeDetail() {
        if (!detailOpen) return;
        detailOpen = false;
        expandAnim.stop();
        collapseAnim.restart();
    }

    // M3 Expressive container transform — same tokens as the cursor / icon stores
    NumberAnimation {
        id: expandAnim
        target: root
        property: "detailProg"
        to: 1.0
        duration: 380
        easing: Tokens.anim.expressiveDefaultSpatial
        onFinished: root.detailProg = 1.0
    }

    NumberAnimation {
        id: collapseAnim
        target: root
        property: "detailProg"
        to: 0.0
        duration: 300
        easing: Tokens.anim.emphasized
        onFinished: {
            root.detailProg = 0.0;
            root.detailItem = null;
            root.detailInfo = null;
        }
    }

    Process {
        id: infoProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text.trim());
                    if (root.detailItem && r.id === root.detailItem.id) root.detailInfo = r;
                } catch (e) {}
            }
        }
    }

    // ── Store State & Queries ──
    property var marketList: []
    property bool marketLoading: false
    property bool marketHasMore: true
    property int marketPage: 1
    property bool marketAppendMode: false

    property string marketSort: "toplist" // toplist, views, favorites, date_added, random
    property string marketTopRange: "1M" // 1d, 1w, 1M, 3M, 1y
    property string marketCategory: "111" // 111: All, 100: General, 010: Anime, 001: People
    property string marketPurity: "100" // 100: SFW, 010: Sketchy, 110: Both
    property string marketResolution: "" // "" (Any), "1920x1080", "2560x1440", "3840x2160"
    property string marketSearch: ""

    property var downloadingWallpapers: ({})
    property var downloadProgress: ({})
    property var installedOverrides: ({})

    // Infinite scroll trigger via flickable
    Connections {
        target: contentFlickable
        enabled: root.currentTab === 1 && !root.marketLoading && root.marketHasMore && root.marketList.length > 0
        function onContentYChanged() {
            if (!contentFlickable) return;
            const maxScroll = contentFlickable.contentHeight - contentFlickable.height;
            if (contentFlickable.contentY > maxScroll - 400 && !root.marketLoading && root.marketHasMore) {
                root.loadMoreMarket();
            }
        }
    }

    function refreshMarket() {
        marketPage = 1;
        marketHasMore = true;
        fetchMarket(1, false);
    }

    function loadMoreMarket() {
        if (marketLoading || !marketHasMore) return;
        fetchMarket(marketPage + 1, true);
    }

    function fetchMarket(page, append) {
        if (marketLoading) return;
        marketLoading = true;
        marketAppendMode = append;
        marketPage = page;

        try {
            const script = getMarketScriptPath();
            const args = [
                "python3", script, "list",
                "--sort", marketSort,
                "--top_range", marketTopRange,
                "--categories", marketCategory,
                "--purity", marketPurity,
                "--page", String(page)
            ];
            if (marketResolution && marketResolution !== "") {
                args.push("--atleast");
                args.push(marketResolution);
            }
            if (marketSearch && marketSearch.trim() !== "") {
                args.push("--search");
                args.push(marketSearch.trim());
            }

            marketProc.command = args;
            marketProc.running = false;
            marketProc.running = true;
        } catch (e) {
            console.warn("[AppearanceWallpapers] fetchMarket error:", e);
            marketLoading = false;
        }
    }

    Process {
        id: marketProc
        onExited: (exitCode, exitStatus) => {
            root.marketLoading = false;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.marketLoading = false;
                if (!text || text.trim() === "") return;
                try {
                    const parsed = JSON.parse(text.trim());
                    if (parsed.items && parsed.items.length > 0) {
                        if (root.marketAppendMode) {
                            const current = root.marketList.slice();
                            const existingIds = new Set(current.map(it => it.id));
                            for (let i = 0; i < parsed.items.length; i++) {
                                if (!existingIds.has(parsed.items[i].id)) {
                                    current.push(parsed.items[i]);
                                }
                            }
                            root.marketList = current;
                        } else {
                            root.marketList = parsed.items;
                        }
                        const meta = parsed.meta || {};
                        root.marketHasMore = meta.current_page < (meta.last_page || 1);
                    } else {
                        if (!root.marketAppendMode) root.marketList = [];
                        root.marketHasMore = false;
                    }
                } catch (e) {
                    console.warn("[AppearanceWallpapers] Market parse error:", e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "") {
                    console.warn("[AppearanceWallpapers] Market stderr:", text);
                }
            }
        }
    }

    // ── Download & Apply Wallpaper ──
    function handleDownloadOutput(wid, line, applyAfter) {
        if (!line) return;
        const trimmed = line.trim();
        if (trimmed.startsWith("PROGRESS:")) {
            const prog = parseInt(trimmed.substring(9).trim(), 10);
            if (!isNaN(prog)) {
                let d = Object.assign({}, root.downloadProgress);
                d[wid] = Math.min(100, Math.max(0, prog));
                root.downloadProgress = d;
            }
        } else if (trimmed.startsWith("{")) {
            try {
                const res = JSON.parse(trimmed);
                if (res.success && res.path) {
                    let d = Object.assign({}, root.downloadProgress);
                    d[wid] = 100;
                    root.downloadProgress = d;

                    let ov = Object.assign({}, root.installedOverrides);
                    ov[wid] = res.path;
                    root.installedOverrides = ov;

                    for (let i = 0; i < root.marketList.length; i++) {
                        if (root.marketList[i].id === wid) {
                            root.marketList[i].isInstalled = true;
                            root.marketList[i].localPath = res.path;
                            break;
                        }
                    }

                    Wallpapers.ensureCatalog();

                    if (typeof Toaster !== "undefined" && Toaster.toast) {
                        Toaster.toast(
                            qsTr("Wallpaper Downloaded"),
                            qsTr("Saved to ~/Pictures/Wallpapers/%1").arg(res.filename),
                            "download_done"
                        );
                    }

                    if (applyAfter) {
                        Wallpapers.setWallpaper(res.path);
                        if (typeof Toaster !== "undefined" && Toaster.toast) {
                            Toaster.toast(
                                qsTr("Wallpaper Applied"),
                                qsTr("Desktop background updated"),
                                "wallpaper"
                            );
                        }
                    }
                } else if (res.error) {
                    console.warn("[AppearanceWallpapers] Download error:", res.error);
                    if (typeof Toaster !== "undefined" && Toaster.toast) {
                        Toaster.toast(
                            qsTr("Download Failed"),
                            res.error,
                            "error"
                        );
                    }
                }
            } catch (e) {
                console.warn("[AppearanceWallpapers] Download parse error:", e);
            }
        }
    }

    function handleDownloadFinished(wid, exitCode, exitStatus) {
        let d = Object.assign({}, root.downloadingWallpapers);
        delete d[wid];
        root.downloadingWallpapers = d;
    }

    function downloadWallpaper(item, applyAfter) {
        if (!item || !item.id || !item.fullUrl) return;
        const wid = item.id;
        let dw = Object.assign({}, root.downloadingWallpapers);
        dw[wid] = true;
        root.downloadingWallpapers = dw;

        let dp = Object.assign({}, root.downloadProgress);
        dp[wid] = 0;
        root.downloadProgress = dp;

        const cmdArgs = JSON.stringify(["python3", "-u", getMarketScriptPath(), "download", wid, item.fullUrl]);

        const qmlCode = `
            import Quickshell.Io
            Process {
                id: proc
                command: ${cmdArgs}
                running: true
                stdout: SplitParser {
                    onRead: line => root.handleDownloadOutput("${wid}", line, ${applyAfter ? "true" : "false"})
                }
                stderr: StdioCollector {
                    onStreamFinished: {
                        if (text && text.trim() !== "") {
                            console.warn("[WallpaperDownload] stderr:", text);
                        }
                    }
                }
                onExited: (code, status) => {
                    root.handleDownloadFinished("${wid}", code, status);
                    proc.destroy();
                }
            }
        `;

        try {
            Qt.createQmlObject(qmlCode, root, "downloaderProc_" + wid + "_" + Date.now());
        } catch (e) {
            console.error("[AppearanceWallpapers] Failed to create download process:", e);
            let d = Object.assign({}, root.downloadingWallpapers);
            delete d[wid];
            root.downloadingWallpapers = d;
        }
    }

    // ── Station Header (Pinned / Does NOT scroll) ──
    ColumnLayout {
        id: headerContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.large
        z: 10

        // Row 1: Segmented Nav Bar (My Wallpapers | Store) + Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.normal

            Segmented {
                model: [
                    { label: qsTr("My Wallpapers (%1)").arg(Wallpapers.staticEntries.length) },
                    { label: qsTr("Store") }
                ]
                currentIndex: root.currentTab
                onSelected: i => {
                    root.currentTab = i;
                    contentFlickable.contentY = 0;
                    if (searchPill) searchPill.searchExpanded = false;
                    if (i === 1 && root.marketList.length === 0) {
                        root.refreshMarket();
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Store actions (Search + Refresh) — only on Store tab
            RowLayout {
                id: storeActions
                spacing: Tokens.spacing.small
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: root.currentTab === 1

                // Reparent in explicit order: search (left), refresh (right)
                Component.onCompleted: {
                    searchPill.parent = storeActions;
                    refreshMarketBtn.parent = storeActions;
                }
            }

            // Action Buttons (Only visible on My Wallpapers tab)
            RowLayout {
                spacing: Tokens.spacing.small
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: root.currentTab === 0

                // Open Folder Button
                StyledRect {
                    id: openFolderBtn
                    readonly property bool hovered: openFolderMa.containsMouse
                    readonly property real expandedWidth: Math.round(38 + folderText.implicitWidth + 18)

                    implicitHeight: 38
                    implicitWidth: hovered ? expandedWidth : 38
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: implicitWidth
                    radius: Tokens.rounding.full
                    clip: true

                    color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)

                    Behavior on implicitWidth { Anim { type: Anim.DefaultSpatial } }

                    Item {
                        id: folderIconWrap
                        width: 38
                        height: 38
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "folder_open"
                            iconPointSize: 18
                            color: Colours.palette.m3onSurface
                        }
                    }

                    StyledText {
                        id: folderText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: folderIconWrap.right
                        anchors.leftMargin: 2
                        text: qsTr("Open Folder")
                        textPointSize: Tokens.font.size.smaller
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurface
                        opacity: openFolderBtn.hovered ? 1.0 : 0.0
                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                    }

                    MouseArea {
                        id: openFolderMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["xdg-open", GlobalConfig.paths.wallpaperDir || (Paths.home + "/Pictures/Wallpapers")])
                    }
                }

                // Refresh / Scan Button
                StyledRect {
                    id: scanWallBtn
                    readonly property bool hovered: scanWallMa.containsMouse
                    readonly property real expandedWidth: Math.round(38 + scanText.implicitWidth + 18)

                    implicitHeight: 38
                    implicitWidth: hovered ? expandedWidth : 38
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: implicitWidth
                    radius: Tokens.rounding.full
                    clip: true

                    color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)

                    Behavior on implicitWidth { Anim { type: Anim.DefaultSpatial } }

                    Item {
                        id: scanIconWrap
                        width: 38
                        height: 38
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "refresh"
                            iconPointSize: 18
                            color: Colours.palette.m3onSurface
                        }
                    }

                    StyledText {
                        id: scanText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: scanIconWrap.right
                        anchors.leftMargin: 2
                        text: qsTr("Reload Catalog")
                        textPointSize: Tokens.font.size.smaller
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurface
                        opacity: scanWallBtn.hovered ? 1.0 : 0.0
                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                    }

                    MouseArea {
                        id: scanWallMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.ensureCatalog()
                    }
                }
            }
        }

        // Row 2: Store Toolbar (Only visible on Tab 1 / Store)
        Item {
            Layout.fillWidth: true
            implicitHeight: marketToolbarRow.implicitHeight
            visible: root.currentTab === 1

            RowLayout {
                id: marketToolbarRow
                anchors.fill: parent
                spacing: Tokens.spacing.normal
                visible: root.currentTab === 1

                // Category Filter
                RowLayout {
                    id: filtersRow
                    spacing: Tokens.spacing.normal
                    visible: true
                    Layout.alignment: Qt.AlignVCenter

                StyledText {
                    text: qsTr("Category:")
                    color: Colours.palette.m3onSurfaceVariant
                    font.weight: Font.Medium
                    textPointSize: Tokens.font.size.normal
                    Layout.alignment: Qt.AlignVCenter
                }

                OptionPicker {
                    id: categoryPicker
                    Layout.alignment: Qt.AlignVCenter
                    model: [
                        { label: qsTr("All"), val: "111" },
                        { label: qsTr("General"), val: "100" },
                        { label: qsTr("Anime"), val: "010" },
                        { label: qsTr("People"), val: "001" }
                    ]
                    currentIndex: 0
                    onSelected: i => {
                        const vals = ["111", "100", "010", "001"];
                        root.marketCategory = vals[i] || "111";
                        root.refreshMarket();
                    }
                }

                // Purity Filter (SFW / Sketchy / Both)
                StyledText {
                    text: qsTr("Purity:")
                    color: Colours.palette.m3onSurfaceVariant
                    font.weight: Font.Medium
                    textPointSize: Tokens.font.size.normal
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 8
                }

                OptionPicker {
                    id: purityPicker
                    Layout.alignment: Qt.AlignVCenter
                    model: [
                        { label: qsTr("SFW"), val: "100" },
                        { label: qsTr("Sketchy"), val: "010" },
                        { label: qsTr("Both"), val: "110" }
                    ]
                    currentIndex: 0
                    onSelected: i => {
                        const vals = ["100", "010", "110"];
                        root.marketPurity = vals[i] || "100";
                        root.refreshMarket();
                    }
                }

                // Sort By
                StyledText {
                    text: qsTr("Sort:")
                    color: Colours.palette.m3onSurfaceVariant
                    font.weight: Font.Medium
                    textPointSize: Tokens.font.size.normal
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 8
                }

                OptionPicker {
                    id: sortPicker
                    Layout.alignment: Qt.AlignVCenter
                    model: [
                        { label: qsTr("Toplist"), val: "toplist" },
                        { label: qsTr("Most Views"), val: "views" },
                        { label: qsTr("Favorites"), val: "favorites" },
                        { label: qsTr("Newest"), val: "date_added" },
                        { label: qsTr("Random"), val: "random" }
                    ]
                    currentIndex: 0
                    onSelected: i => {
                        const keys = ["toplist", "views", "favorites", "date_added", "random"];
                        root.marketSort = keys[i] || "toplist";
                        root.refreshMarket();
                    }
                }

                // Resolution
                StyledText {
                    text: qsTr("Quality:")
                    color: Colours.palette.m3onSurfaceVariant
                    font.weight: Font.Medium
                    textPointSize: Tokens.font.size.normal
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 8
                }

                OptionPicker {
                    id: resPicker
                    Layout.alignment: Qt.AlignVCenter
                    model: [
                        { label: qsTr("Any"), val: "" },
                        { label: qsTr("1080p+"), val: "1920x1080" },
                        { label: qsTr("2K+"), val: "2560x1440" },
                        { label: qsTr("4K Ultra"), val: "3840x2160" }
                    ]
                    currentIndex: 0
                    onSelected: i => {
                        const vals = ["", "1920x1080", "2560x1440", "3840x2160"];
                        root.marketResolution = vals[i] || "";
                        root.refreshMarket();
                    }
                }
                }

                Item { Layout.fillWidth: true }

                // Expanding Search Pill (Store)
                StyledRect {
                    id: searchPill
                    property bool searchExpanded: false
                    readonly property bool searchActive: searchExpanded

                    implicitHeight: 38
                    implicitWidth: searchActive ? 220 : 38
                    Layout.fillWidth: false
                    radius: Tokens.rounding.full
                    color: searchActive
                        ? (marketSearchInput.activeFocus
                            ? Qt.alpha(Colours.palette.m3onSurface, 0.16)
                            : (searchPillTrigger.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.13) : Qt.alpha(Colours.palette.m3onSurface, 0.10)))
                        : (searchPillTrigger.containsMouse
                            ? Qt.alpha(Colours.palette.m3onSurface, 0.15)
                            : Qt.alpha(Colours.palette.m3onSurface, 0.09))
                    border.width: 0
                    clip: true

                    Behavior on implicitWidth { Anim { type: Anim.DefaultSpatial } }
                    Behavior on color { CAnim {} }

                    MaterialIcon {
                        id: searchPillIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        color: marketSearchInput.activeFocus ? Colours.palette.m3primary : Colours.palette.m3onSurface
                        iconPointSize: 16
                        verticalAlignment: Text.AlignVCenter
                        Behavior on color { CAnim {} }
                    }

                    MouseArea {
                        id: searchPillTrigger
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 38
                        hoverEnabled: true
                        enabled: !searchPill.searchActive
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchPill.searchExpanded = true;
                            marketSearchInput.forceActiveFocus();
                        }
                    }

                    Item {
                        id: inputWrapper
                        anchors.left: searchPillIcon.right
                        anchors.leftMargin: 8
                        anchors.right: clearBtn.visible ? clearBtn.left : parent.right
                        anchors.rightMargin: 8
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        opacity: searchPill.searchActive ? 1.0 : 0.0
                        visible: opacity > 0.01
                        Behavior on opacity { Anim { type: Anim.FastEffects } }

                        TextInput {
                            id: marketSearchInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colours.palette.m3onSurface
                            selectionColor: Colours.palette.m3primary
                            selectedTextColor: Colours.palette.m3surface
                            font.family: Tokens.font.family.sans
                            font.pixelSize: Math.max(12, Math.round(Tokens.font.size.normal * 96 / 72))
                            selectByMouse: true
                            clip: true

                            onAccepted: {
                                root.marketSearch = text.trim();
                                root.refreshMarket();
                            }

                            Keys.onEscapePressed: event => {
                                if (text.length > 0) {
                                    text = "";
                                    root.marketSearch = "";
                                    root.refreshMarket();
                                    event.accepted = true;
                                } else {
                                    searchPill.searchExpanded = false;
                                    focus = false;
                                    event.accepted = true;
                                }
                            }
                        }

                        StyledText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: qsTr("Search wallpapers…")
                            color: Colours.palette.m3onSurfaceVariant
                            font.family: Tokens.font.family.sans
                            font.pixelSize: Math.max(12, Math.round(Tokens.font.size.normal * 96 / 72))
                            visible: marketSearchInput.text.length === 0 && !marketSearchInput.inputMethodComposing
                            opacity: marketSearchInput.text.length === 0 ? 1.0 : 0
                            Behavior on opacity { Anim { type: Anim.FastEffects } }
                        }
                    }

                    StyledRect {
                        id: clearBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: Tokens.rounding.full
                        color: clearBtnMa.pressed ? Qt.alpha(Colours.palette.m3onSurface, 0.12) :
                               clearBtnMa.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : "transparent"
                        opacity: searchPill.searchActive ? 1.0 : 0.0
                        visible: opacity > 0.01

                        Behavior on color { CAnim {} }
                        Behavior on opacity { Anim { type: Anim.FastEffects } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            color: Colours.palette.m3onSurfaceVariant
                            iconPointSize: 14
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            id: clearBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                marketSearchInput.text = "";
                                if (root.marketSearch !== "") {
                                    root.marketSearch = "";
                                    root.refreshMarket();
                                }
                                searchPill.searchExpanded = false;
                                marketSearchInput.focus = false;
                            }
                        }
                    }
                }

                // Refresh Button (Store)
                StyledRect {
                    id: refreshMarketBtn
                    implicitHeight: 38
                    implicitWidth: 38
                    radius: Tokens.rounding.full
                    color: refreshMarketMa.pressed
                        ? Qt.alpha(Colours.palette.m3onSurface, 0.18)
                        : (refreshMarketMa.containsMouse
                            ? Qt.alpha(Colours.palette.m3onSurface, 0.15)
                            : Qt.alpha(Colours.palette.m3onSurface, 0.09))
                    border.width: 0

                    Behavior on color { CAnim {} }

                    LoadingIndicator {
                        anchors.centerIn: parent
                        implicitSize: 20
                        color: Colours.palette.m3primary
                        animated: root.marketLoading
                        visible: opacity > 0
                        opacity: root.marketLoading ? 1.0 : 0.0
                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "refresh"
                        iconPointSize: 18
                        color: Colours.palette.m3onSurface
                        visible: opacity > 0
                        opacity: root.marketLoading ? 0.0 : 1.0
                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                    }

                    MouseArea {
                        id: refreshMarketMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.marketLoading ? Qt.ArrowCursor : Qt.PointingHandCursor
                        enabled: !root.marketLoading
                        onClicked: root.refreshMarket()
                    }
                }
            }
        }
    }

    // Click outside to collapse searchbar
    MouseArea {
        anchors.fill: parent
        z: 9
        visible: searchPill.searchActive
        onClicked: {
            searchPill.searchExpanded = false;
            marketSearchInput.focus = false;
        }
    }

    // ── Main Scrolling Content ──
    StyledClippingRect {
        id: scrollViewport
        anchors.top: headerContainer.bottom
        anchors.topMargin: Tokens.spacing.normal
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        radius: Tokens.rounding.large

        StyledFlickable {
            id: contentFlickable
            anchors.fill: parent
            clip: false
            contentWidth: width
            flickableDirection: Flickable.VerticalFlick
            contentHeight: scrollContent.implicitHeight + Tokens.padding.large * 2

            Item {
                id: scrollContent
                width: contentFlickable.width
                implicitHeight: root.currentTab === 0 ? installedContentCol.implicitHeight : marketContentCol.implicitHeight

                // ═════════════════════════════════════════════════════════════════
                // TAB 0: LOCAL WALLPAPERS & SETTINGS
                // ═════════════════════════════════════════════════════════════════
                ColumnLayout {
                    id: installedContentCol
                    width: parent.width
                    spacing: Tokens.spacing.large
                    visible: root.currentTab === 0

                    Section {
                        Layout.fillWidth: true
                        title: qsTr("General")
                        description: root.wallpaperMode === "live" ? qsTr("Video wallpapers from ~/Pictures/Wallpapers/Live") : qsTr("Still images from your wallpaper folder")
                        icon: "image"

                    SettingRow {
                        title: qsTr("Turn on/off olvex walls")
                        description: qsTr("Draw the selected wallpaper on the desktop")
                        StyledSwitch {
                            checked: GlobalConfig.background.wallpaperEnabled
                            onToggled: {
                                GlobalConfig.background.wallpaperEnabled = checked;
                                GlobalConfig.save();
                            }
                        }
                    }

                    // Unified Wallpaper Type & Grid Card
                    StyledRect {
                        id: wallpaperPickerCard
                        Layout.fillWidth: true
                        implicitWidth: parent ? parent.width : 0
                        width: parent ? parent.width : implicitWidth

                        property bool isFirstInGroup: false
                        property bool isLastInGroup: false
                        property bool isSingleInGroup: false

                        readonly property real topR: (isSingleInGroup || isFirstInGroup) ? 22 : 6
                        readonly property real bottomR: (isSingleInGroup || isLastInGroup) ? 22 : 6
                        topLeftRadius: topR
                        topRightRadius: topR
                        bottomLeftRadius: bottomR
                        bottomRightRadius: bottomR

                        color: Colours.palette.m3surfaceContainerHigh
                        border.width: 0
                        implicitHeight: cardContent.implicitHeight + 28

                        ColumnLayout {
                            id: cardContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 14
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 16

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    StyledText {
                                        width: parent.width
                                        text: qsTr("Wallpaper Type")
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: -0.1
                                        color: Colours.palette.m3onSurface
                                        textPointSize: Tokens.font.size.normal
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: qsTr("Static images or live video backgrounds")
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.weight: Font.Normal
                                        font.letterSpacing: 0.1
                                        textPointSize: Tokens.font.size.small
                                    }
                                }

                                Segmented {
                                    id: sourceSeg
                                    minSegmentWidth: 88
                                    model: [{
                                            label: qsTr("Static")
                                        }, {
                                            label: qsTr("Live")
                                        }]
                                    currentIndex: root.wallpaperMode === "live" ? 1 : 0
                                    onSelected: i => root.setWallpaperMode(i === 1 ? "live" : "static")
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: root.wallpaperMode === "live"
                                spacing: 16

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    StyledText {
                                        width: parent.width
                                        text: qsTr("Turn off live wallpaper audio")
                                        font.weight: Font.DemiBold
                                        color: Colours.palette.m3onSurface
                                        textPointSize: Tokens.font.size.normal
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: qsTr("Silence sound from the video wallpaper")
                                        color: Colours.palette.m3onSurfaceVariant
                                        textPointSize: Tokens.font.size.small
                                    }
                                }

                                StyledSwitch {
                                    checked: (GlobalConfig.background && GlobalConfig.background.liveWallpaper && GlobalConfig.background.liveWallpaper.muted !== undefined)
                                             ? GlobalConfig.background.liveWallpaper.muted
                                             : true
                                    onToggled: {
                                        if (GlobalConfig.background && GlobalConfig.background.liveWallpaper) {
                                            GlobalConfig.background.liveWallpaper.muted = checked;
                                            GlobalConfig.save();
                                        }
                                    }
                                }
                            }

                            WallpaperGrid {
                                id: wallGrid
                                Layout.fillWidth: true
                                Layout.preferredHeight: implicitHeight
                                session: root.session
                                mode: root.wallpaperMode
                                columnsCount: 5
                                visibleRows: 3
                            }
                        }
                    }

                    SettingRow {
                        title: qsTr("Per-monitor wallpaper")
                        description: qsTr("Use an independent wallpaper on each display")
                        divider: false
                        StyledSwitch {
                            checked: GlobalConfig.background.perMonitorWallpaper
                            onToggled: {
                                GlobalConfig.background.perMonitorWallpaper = checked;
                                GlobalConfig.save();
                            }
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    title: qsTr("Transition")
                    description: qsTr("Animation when the wallpaper changes")
                    icon: "transition_fade"

                    SettingRow {
                        title: qsTr("Transition type")
                        description: qsTr("Visual effect used to swap wallpapers")
                        OptionPicker {
                            model: root.transitionTypes
                            currentIndex: root.idxOf(root.transitionTypes, (GlobalConfig.background.wallpaperTransition && GlobalConfig.background.wallpaperTransition.type) ? GlobalConfig.background.wallpaperTransition.type : "random")
                            onSelected: i => {
                                if (GlobalConfig.background && GlobalConfig.background.wallpaperTransition) {
                                    GlobalConfig.background.wallpaperTransition.type = root.transitionTypes[i];
                                    GlobalConfig.save();
                                }
                            }
                        }
                    }

                    SettingRow {
                        title: qsTr("Duration")
                        description: qsTr("How long the transition lasts (ms)")
                        CustomSpinBox {
                            value: (GlobalConfig.background.wallpaperTransition && GlobalConfig.background.wallpaperTransition.duration !== undefined) ? GlobalConfig.background.wallpaperTransition.duration : 1000
                            min: 200
                            max: 3000
                            step: 100
                            onValueModified: v => {
                                if (GlobalConfig.background && GlobalConfig.background.wallpaperTransition) {
                                    GlobalConfig.background.wallpaperTransition.duration = v;
                                    GlobalConfig.save();
                                }
                            }
                        }
                    }

                    SettingRow {
                        title: qsTr("Transition FPS")
                        description: qsTr("Frame rate for the transition animation")
                        CustomSpinBox {
                            value: (GlobalConfig.background.wallpaperTransition && GlobalConfig.background.wallpaperTransition.fps !== undefined) ? GlobalConfig.background.wallpaperTransition.fps : 60
                            min: 30
                            max: 165
                            step: 15
                            onValueModified: v => {
                                if (GlobalConfig.background && GlobalConfig.background.wallpaperTransition) {
                                    GlobalConfig.background.wallpaperTransition.fps = v;
                                    GlobalConfig.save();
                                }
                            }
                        }
                    }

                    SettingRow {
                        title: qsTr("Transition step")
                        description: qsTr("Granularity of the transition effect")
                        divider: false
                        CustomSpinBox {
                            value: (GlobalConfig.background.wallpaperTransition && GlobalConfig.background.wallpaperTransition.step !== undefined) ? GlobalConfig.background.wallpaperTransition.step : 90
                            min: 1
                            max: 255
                            step: 5
                            onValueModified: v => {
                                if (GlobalConfig.background && GlobalConfig.background.wallpaperTransition) {
                                    GlobalConfig.background.wallpaperTransition.step = v;
                                    GlobalConfig.save();
                                }
                            }
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    title: qsTr("Cycle Wallpapers")
                    description: qsTr("Automatically switch wallpapers on a schedule")
                    icon: "cycle"

                    SettingRow {
                        title: qsTr("Auto cycle")
                        description: qsTr("Switch wallpaper periodically")
                        StyledSwitch {
                            checked: GlobalConfig.background.wallpaperCycling.enabled
                            onToggled: {
                                GlobalConfig.background.wallpaperCycling.enabled = checked;
                                GlobalConfig.save();
                            }
                        }
                    }

                    SettingRow {
                        title: qsTr("Cycle interval")
                        description: qsTr("Time between wallpaper changes (minutes)")
                        CustomSpinBox {
                            value: Math.max(1, Math.round((GlobalConfig.background.wallpaperCycling.intervalSeconds || 300) / 60))
                            min: 1
                            max: 1440
                            step: 5
                            onValueModified: v => {
                                GlobalConfig.background.wallpaperCycling.intervalSeconds = v * 60;
                                GlobalConfig.save();
                            }
                        }
                    }

                    SettingRow {
                        title: qsTr("Shuffle")
                        description: qsTr("Pick wallpapers in random order")
                        StyledSwitch {
                            checked: GlobalConfig.background.wallpaperCycling.shuffle
                            onToggled: {
                                GlobalConfig.background.wallpaperCycling.shuffle = checked;
                                GlobalConfig.save();
                            }
                        }
                    }

                    SettingRow {
                        title: qsTr("Pause on fullscreen")
                        description: qsTr("Pause automatic wallpaper cycling while a fullscreen app is active")
                        divider: false
                        StyledSwitch {
                            checked: GlobalConfig.background.wallpaperCycling.pauseOnFullscreen
                            onToggled: {
                                GlobalConfig.background.wallpaperCycling.pauseOnFullscreen = checked;
                                GlobalConfig.save();
                            }
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    title: qsTr("Wallpaper Directory")
                    description: qsTr("Folder containing your static wallpapers")
                    icon: "folder"

                    SettingRow {
                        title: qsTr("Default Directory")
                        description: GlobalConfig.paths.wallpaperDir || qsTr("~/Pictures/Wallpapers")
                        divider: false
                        IconTextButton {
                            icon: "edit"
                            text: qsTr("Change")
                            type: IconTextButton.Filled
                            onClicked: wallpaperDirPicker.open()
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // TAB 1: WALLHAVEN STORE
            // ═════════════════════════════════════════════════════════════════
            ColumnLayout {
                id: marketContentCol
                width: parent.width
                spacing: Tokens.spacing.large
                visible: root.currentTab === 1

                // Loading State (initial)
                Item {
                    visible: root.marketLoading && root.marketList.length === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 260

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.normal

                        LoadingIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            implicitSize: 44
                            color: Colours.palette.m3primary
                            animated: root.marketLoading && root.marketList.length === 0
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Discovering high-resolution wallpapers from Wallhaven…")
                            color: Colours.palette.m3onSurfaceVariant
                            textPointSize: Tokens.font.size.normal
                            font.weight: Font.Medium
                        }
                    }
                }

                // Empty / No Results State
                Item {
                    visible: !root.marketLoading && root.marketList.length === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "wallpaper"
                            iconPointSize: 44
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("No wallpapers found")
                            color: Colours.palette.m3onSurface
                            textPointSize: Tokens.font.size.normal
                            font.weight: Font.Medium
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Try searching another topic or changing category / quality filter")
                            color: Colours.palette.m3onSurfaceVariant
                            textPointSize: Tokens.font.size.small
                        }
                    }
                }

                // Wallpaper Store Grid (3 columns, 16:10 tiles)
                GridLayout {
                    id: wallStoreGrid
                    width: parent.width
                    columns: 3
                    columnSpacing: Tokens.spacing.normal
                    rowSpacing: Tokens.spacing.normal
                    visible: root.marketList.length > 0

                    Repeater {
                        model: root.marketList

                        delegate: Item {
                            id: storeCard
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.preferredWidth: Math.max(100, Math.floor((wallStoreGrid.width - wallStoreGrid.columnSpacing * 2) / 3))
                            Layout.maximumWidth: Layout.preferredWidth
                            Layout.preferredHeight: 250
                            implicitHeight: 250

                            readonly property bool isDownloading: Boolean(root.downloadingWallpapers[modelData.id])
                            readonly property int currentProgress: root.downloadProgress[modelData.id] || 0
                            readonly property bool isInstalled: Boolean(root.installedOverrides[modelData.id] || modelData.isInstalled)
                            readonly property string localPath: root.installedOverrides[modelData.id] || modelData.localPath || ""
                            readonly property bool isCurrent: localPath !== "" && localPath === Wallpapers.actualCurrent
                            readonly property bool isHovered: cardMouse.containsMouse
                            opacity: (root.detailItem && root.detailItem.id === modelData.id) ? 0.0 : 1.0

                            StyledRect {
                                anchors.fill: parent
                                radius: Tokens.rounding.large
                                color: storeCard.isHovered
                                    ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
                                    : Colours.palette.m3surfaceContainer
                                border.width: storeCard.isCurrent ? 2 : 0
                                border.color: storeCard.isCurrent ? Colours.palette.m3primary : "transparent"

                                Behavior on color { CAnim {} }
                                Behavior on border.color { CAnim {} }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Tokens.padding.normal
                                    spacing: Tokens.spacing.small

                                    // Thumbnail Box (16:10)
                                    StyledClippingRect {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 130
                                        radius: Tokens.rounding.normal
                                        color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.5)

                                        Image {
                                            id: thumbImg
                                            anchors.fill: parent
                                            source: modelData.localThumb && modelData.localThumb !== ""
                                                ? ("file://" + modelData.localThumb)
                                                : (modelData.thumbUrl || "")
                                            fillMode: Image.PreserveAspectCrop
                                            sourceSize.width: 480
                                            sourceSize.height: 300
                                            asynchronous: true
                                            cache: true
                                            smooth: true
                                            mipmap: true
                                            visible: status === Image.Ready
                                        }

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            visible: thumbImg.status !== Image.Ready
                                            text: "image"
                                            iconPointSize: 36
                                            color: Colours.palette.m3onSurfaceVariant
                                        }

                                        // Resolution Pill Badge (Top Left)
                                        StyledRect {
                                            anchors.top: parent.top
                                            anchors.topMargin: 8
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            implicitHeight: 22
                                            implicitWidth: resText.implicitWidth + 12
                                            radius: Tokens.rounding.full
                                            color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.85)

                                            StyledText {
                                                id: resText
                                                anchors.centerIn: parent
                                                text: (modelData.resolution || "HD").replace("x", "×")
                                                font.weight: Font.DemiBold
                                                textPointSize: Tokens.font.size.smaller
                                                color: Colours.palette.m3onSurface
                                            }
                                        }

                                        // Category & Purity Pill Badge (Top Right)
                                        StyledRect {
                                            anchors.top: parent.top
                                            anchors.topMargin: 8
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            implicitHeight: 22
                                            implicitWidth: catText.implicitWidth + 12
                                            radius: Tokens.rounding.full
                                            color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.85)

                                            StyledText {
                                                id: catText
                                                anchors.centerIn: parent
                                                text: modelData.category || "General"
                                                font.weight: Font.Medium
                                                textPointSize: Tokens.font.size.smaller
                                                color: Colours.palette.m3onSurface
                                            }
                                        }

                                        // Active / Applied indicator on thumbnail
                                        StyledRect {
                                            visible: storeCard.isCurrent
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 8
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            implicitHeight: 24
                                            implicitWidth: activeCheckRow.implicitWidth + 14
                                            radius: Tokens.rounding.full
                                            color: Colours.palette.m3primary

                                            RowLayout {
                                                id: activeCheckRow
                                                anchors.centerIn: parent
                                                spacing: 4

                                                MaterialIcon {
                                                    text: "check"
                                                    iconPointSize: 13
                                                    color: Colours.palette.m3onPrimary
                                                }

                                                StyledText {
                                                    text: qsTr("Active")
                                                    font.weight: Font.DemiBold
                                                    textPointSize: Tokens.font.size.smaller
                                                    color: Colours.palette.m3onPrimary
                                                }
                                            }
                                        }
                                    }

                                    // Info & Stats
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: root.prettyName(modelData)
                                            font.weight: storeCard.isCurrent ? Font.DemiBold : Font.Medium
                                            textPointSize: Tokens.font.size.normal
                                            color: storeCard.isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                            elide: Text.ElideRight
                                        }

                                        // Favorites count
                                        RowLayout {
                                            spacing: 2
                                            MaterialIcon {
                                                text: "favorite"
                                                iconPointSize: 14
                                                color: Colours.palette.m3onSurfaceVariant
                                            }
                                            StyledText {
                                                text: String(modelData.favorites || 0)
                                                textPointSize: Tokens.font.size.smaller
                                                color: Colours.palette.m3onSurfaceVariant
                                            }
                                        }
                                    }

                                    // Spacer pins hero to the top padding and the button to the
                                    // bottom padding — identical geometry to the expanded card's
                                    // anchors, so the morph start/end frames line up exactly.
                                    Item { Layout.fillHeight: true }

                                    // Action Button Row (Apply / Download / In Progress)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Tokens.spacing.small

                                        // Main Action Button (Apply if installed, Download if not)
                                        StyledClippingRect {
                                            id: cardActionBtn
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 34
                                            radius: height / 2
                                            clip: true

                                            readonly property bool isDownloading: storeCard.isDownloading
                                            readonly property int currentProgress: storeCard.currentProgress
                                            readonly property bool isInstalled: storeCard.isInstalled
                                            readonly property bool isCurrent: storeCard.isCurrent

                                            color: isDownloading
                                                ? Qt.alpha(Colours.palette.m3primary, 0.15)
                                                : (isInstalled
                                                    ? (mainBtnMa.containsMouse ? Colours.layer(Colours.palette.m3secondaryContainer, 2) : Colours.palette.m3secondaryContainer)
                                                    : (mainBtnMa.containsMouse ? Colours.layer(Colours.palette.m3primary, 2) : Colours.palette.m3primary))

                                            Behavior on color { CAnim {} }

                                            // State 1: "Installed" / "Applied" Content
                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                opacity: (cardActionBtn.isInstalled && !cardActionBtn.isDownloading) ? 1.0 : 0.0
                                                visible: opacity > 0.01
                                                Behavior on opacity { Anim { type: Anim.FastEffects } }

                                                MaterialIcon {
                                                    iconPointSize: 16
                                                    color: Colours.palette.m3onSecondaryContainer
                                                    text: cardActionBtn.isCurrent ? "check" : "wallpaper"
                                                }

                                                StyledText {
                                                    font.weight: Font.DemiBold
                                                    textPointSize: Tokens.font.size.normal
                                                    color: Colours.palette.m3onSecondaryContainer
                                                    text: cardActionBtn.isCurrent ? qsTr("Applied") : qsTr("Set Wallpaper")
                                                }
                                            }

                                            // State 2: "Download & Set" Content
                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                opacity: (!cardActionBtn.isInstalled && !cardActionBtn.isDownloading) ? 1.0 : 0.0
                                                visible: opacity > 0.01
                                                Behavior on opacity { Anim { type: Anim.FastEffects } }

                                                MaterialIcon {
                                                    iconPointSize: 16
                                                    color: Colours.palette.m3onPrimary
                                                    text: "download"
                                                }

                                                StyledText {
                                                    font.weight: Font.DemiBold
                                                    textPointSize: Tokens.font.size.normal
                                                    color: Colours.palette.m3onPrimary
                                                    text: qsTr("Download & Set")
                                                }
                                            }

                                            // State 3: Base "Downloading... X%" Content
                                            RowLayout {
                                                id: cardBtnBaseContent
                                                anchors.centerIn: parent
                                                spacing: 6
                                                opacity: cardActionBtn.isDownloading ? 1.0 : 0.0
                                                visible: opacity > 0.01
                                                Behavior on opacity { Anim { type: Anim.FastEffects } }

                                                MaterialIcon {
                                                    iconPointSize: 16
                                                    color: Colours.palette.m3primary
                                                    text: "downloading"
                                                }

                                                StyledText {
                                                    font.weight: Font.DemiBold
                                                    textPointSize: Tokens.font.size.normal
                                                    color: Colours.palette.m3primary
                                                    text: qsTr("Downloading... %1%").arg(cardActionBtn.currentProgress)
                                                }
                                            }

                                            // Dynamic Progress Fill (clipped inside with rounded cap & inverted text)
                                            Rectangle {
                                                id: cardBtnProgressFill
                                                visible: cardActionBtn.isDownloading
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: Math.max(0, Math.min(cardActionBtn.width, Math.round(cardActionBtn.width * (cardActionBtn.currentProgress / 100.0))))
                                                radius: height / 2
                                                color: Colours.palette.m3primary
                                                clip: true
                                                z: 2

                                                Behavior on width {
                                                    Anim {
                                                        type: Anim.StandardLarge
                                                    }
                                                }

                                                RowLayout {
                                                    width: cardBtnBaseContent.width
                                                    height: cardBtnBaseContent.height
                                                    x: (cardActionBtn.width - width) / 2
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 6

                                                    MaterialIcon {
                                                        iconPointSize: 16
                                                        color: Colours.palette.m3onPrimary
                                                        text: "downloading"
                                                    }

                                                    StyledText {
                                                        font.weight: Font.DemiBold
                                                        textPointSize: Tokens.font.size.normal
                                                        color: Colours.palette.m3onPrimary
                                                        text: qsTr("Downloading... %1%").arg(cardActionBtn.currentProgress)
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: mainBtnMa
                                                anchors.fill: parent
                                                hoverEnabled: !cardActionBtn.isDownloading
                                                cursorShape: cardActionBtn.isDownloading ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                enabled: !cardActionBtn.isDownloading
                                                onClicked: {
                                                    if (storeCard.isInstalled) {
                                                        if (storeCard.localPath) {
                                                            Wallpapers.setWallpaper(storeCard.localPath);
                                                        }
                                                    } else {
                                                        root.downloadWallpaper(modelData, true);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    z: -1
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openDetail(modelData, storeCard)
                                }
                            }
                        }
                    }
                }

                // Infinite Scroll Loading Spinner at bottom
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    visible: root.marketLoading && root.marketList.length > 0

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.normal

                        LoadingIndicator {
                            implicitSize: 22
                            color: Colours.palette.m3primary
                            animated: true
                        }

                        StyledText {
                            text: qsTr("Loading more wallpapers…")
                            color: Colours.palette.m3onSurfaceVariant
                            textPointSize: Tokens.font.size.normal
                        }
                    }
                }

                Item { Layout.preferredHeight: 40 }
            }
        }
    }
}

    // ══════════════════════════════════════════════════════════════════
    // WALLPAPER DETAILS — M3 container transform (card → detail)
    // Elements persist across the morph: hero, badges, title row and the
    // action button are the same items in both states; only extras fade in.
    // ══════════════════════════════════════════════════════════════════
    Item {
        id: detailLayer
        anchors.fill: parent
        z: 50
        visible: root.detailItem !== null

        readonly property var it: root.detailItem
        readonly property real p: root.detailProg
        readonly property real pc: Math.max(0.0, Math.min(1.0, p))
        readonly property real ex: Math.max(0.0, Math.min(1.0, (pc - 0.45) / 0.55))
        readonly property real pad: Tokens.padding.normal
        readonly property real tw: Math.min(scrollViewport.width - 48, 620)
        readonly property real th: Math.min(scrollViewport.height - 32, 560)
        readonly property real tx: scrollViewport.x + Math.round((scrollViewport.width - tw) / 2)
        readonly property real ty: scrollViewport.y + Math.round((scrollViewport.height - th) / 2)
        readonly property bool resting: !expandAnim.running && !collapseAnim.running && root.detailOpen

        readonly property bool dInstalled: it ? Boolean(root.installedOverrides[it.id] || it.isInstalled) : false
        readonly property string dPath: it ? (root.installedOverrides[it.id] || it.localPath || "") : ""
        readonly property bool dBusy: it ? Boolean(root.downloadingWallpapers[it.id]) : false
        readonly property int dProgress: it ? (root.downloadProgress[it.id] || 0) : 0
        readonly property bool dCurrent: dPath !== "" && dPath === Wallpapers.actualCurrent

        Shortcut {
            sequence: "Escape"
            enabled: root.detailOpen
            onActivated: root.closeDetail()
        }

        ClippingRectangle {
            id: clipBox
            x: scrollViewport.x
            y: scrollViewport.y
            width: scrollViewport.width
            height: scrollViewport.height
            radius: Tokens.rounding.large
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: Colours.palette.m3scrim
                opacity: detailLayer.ex * (Colours.light ? 0.42 : 0.6)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeDetail()
                    onWheel: wheel => { wheel.accepted = true; }
                }
            }

            Elevation {
                x: detailCard.x
                y: detailCard.y
                width: detailCard.width
                height: detailCard.height
                radius: detailCard.radius
                level: 4
                opacity: detailLayer.resting ? 1.0 : 0.0
                visible: detailLayer.resting
            }

            Rectangle {
                id: detailCard
                x: root.detailSrc.x + (detailLayer.tx - root.detailSrc.x) * detailLayer.p - clipBox.x
                y: root.detailSrc.y + (detailLayer.ty - root.detailSrc.y) * detailLayer.p - clipBox.y
                width: Math.max(100, root.detailSrc.width + (detailLayer.tw - root.detailSrc.width) * detailLayer.p)
                height: Math.max(100, root.detailSrc.height + (detailLayer.th - root.detailSrc.height) * detailLayer.p)
                radius: Tokens.rounding.large
                antialiasing: true
                clip: true
                color: Qt.rgba(
                    Colours.palette.m3surfaceContainer.r + (Colours.palette.m3surfaceContainerHigh.r - Colours.palette.m3surfaceContainer.r) * detailLayer.pc,
                    Colours.palette.m3surfaceContainer.g + (Colours.palette.m3surfaceContainerHigh.g - Colours.palette.m3surfaceContainer.g) * detailLayer.pc,
                    Colours.palette.m3surfaceContainer.b + (Colours.palette.m3surfaceContainerHigh.b - Colours.palette.m3surfaceContainer.b) * detailLayer.pc,
                    1.0)

                MouseArea {
                    anchors.fill: parent
                    onWheel: wheel => { wheel.accepted = true; }
                }

                // ── Hero (same item as the card thumbnail, grows in place) ──
                StyledClippingRect {
                    id: heroBox
                    x: detailLayer.pad
                    y: detailLayer.pad
                    width: parent.width - detailLayer.pad * 2
                    height: 130 + (Math.min(260, detailLayer.th * 0.45) - 130) * detailLayer.p
                    radius: Tokens.rounding.normal
                    color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.5)

                    Image {
                        anchors.fill: parent
                        source: detailLayer.it
                            ? (detailLayer.it.localThumb && detailLayer.it.localThumb !== ""
                                ? "file://" + detailLayer.it.localThumb
                                : (detailLayer.it.thumbUrl || ""))
                            : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 900
                        sourceSize.height: 560
                        asynchronous: true
                        smooth: true
                        mipmap: true
                    }

                    // Resolution badge (persisting)
                    StyledRect {
                        x: 8
                        y: 8
                        implicitHeight: 22 + 2 * detailLayer.pc
                        implicitWidth: dResText.implicitWidth + 12
                        radius: height / 2
                        color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.85)
                        StyledText {
                            id: dResText
                            anchors.centerIn: parent
                            text: detailLayer.it ? (detailLayer.it.resolution || "HD").replace("x", "×") : ""
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.smaller
                            color: Colours.palette.m3onSurface
                        }
                    }

                    // Category badge (persisting; slides left to make room for close)
                    StyledRect {
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8 + 40 * detailLayer.ex
                        implicitHeight: 22 + 2 * detailLayer.pc
                        implicitWidth: dCatText.implicitWidth + 12
                        radius: height / 2
                        color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.85)
                        StyledText {
                            id: dCatText
                            anchors.centerIn: parent
                            text: detailLayer.it ? (detailLayer.it.category || "General") : ""
                            font.weight: Font.Medium
                            textPointSize: Tokens.font.size.smaller
                            color: Colours.palette.m3onSurface
                        }
                    }

                    // Active pill (persisting)
                    StyledRect {
                        visible: detailLayer.dCurrent
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        implicitHeight: 24
                        implicitWidth: dActiveRow.implicitWidth + 14
                        radius: height / 2
                        color: Colours.palette.m3primary
                        RowLayout {
                            id: dActiveRow
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIcon { text: "check"; iconPointSize: 13; color: Colours.palette.m3onPrimary }
                            StyledText {
                                text: qsTr("Active")
                                font.weight: Font.DemiBold
                                textPointSize: Tokens.font.size.smaller
                                color: Colours.palette.m3onPrimary
                            }
                        }
                    }

                    // Close button (fades/scales in)
                    StyledRect {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: 32
                        height: 32
                        radius: 16
                        opacity: detailLayer.ex
                        scale: 0.7 + 0.3 * detailLayer.ex
                        visible: opacity > 0.01
                        color: closeMa.containsMouse ? Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.95) : Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.8)
                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            iconPointSize: 18
                            color: Colours.palette.m3onSurface
                        }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeDetail()
                        }
                    }
                }

                // ── Title row (same position logic as the card: just under hero) ──
                RowLayout {
                    id: dTitleRow
                    anchors.top: heroBox.bottom
                    anchors.topMargin: Tokens.spacing.small
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: detailLayer.pad
                    anchors.rightMargin: detailLayer.pad
                    spacing: 6

                    StyledText {
                        Layout.fillWidth: true
                        text: root.prettyName(detailLayer.it)
                        font.weight: Font.DemiBold
                        textPointSize: Tokens.font.size.normal + 1.5 * detailLayer.pc
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        spacing: 2
                        MaterialIcon { text: "favorite"; iconPointSize: 14; color: Colours.palette.m3onSurfaceVariant }
                        StyledText {
                            text: detailLayer.it ? String(detailLayer.it.favorites || 0) : ""
                            textPointSize: Tokens.font.size.smaller
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    RowLayout {
                        spacing: 2
                        visible: detailLayer.ex > 0.01
                        opacity: detailLayer.ex
                        Layout.leftMargin: 4
                        MaterialIcon { text: "visibility"; iconPointSize: 14; color: Colours.palette.m3onSurfaceVariant }
                        StyledText {
                            text: root.formatCount(detailLayer.it ? detailLayer.it.views : 0)
                            textPointSize: Tokens.font.size.smaller
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                // ── Extras (only these fade in; sit between title and button) ──
                Item {
                    id: extrasBox
                    anchors.top: dTitleRow.bottom
                    anchors.topMargin: 6
                    anchors.bottom: dButton.top
                    anchors.bottomMargin: 8
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: detailLayer.pad
                    anchors.rightMargin: detailLayer.pad
                    clip: true
                    opacity: detailLayer.ex
                    visible: opacity > 0.01

                    ColumnLayout {
                        width: parent.width
                        spacing: Tokens.spacing.small
                        y: (1.0 - detailLayer.ex) * 10

                        StyledText {
                            Layout.fillWidth: true
                            text: root.detailInfo && root.detailInfo.uploader
                                ? qsTr("by %1 · wallhaven.cc").arg(root.detailInfo.uploader)
                                : qsTr("wallhaven.cc")
                            textPointSize: Tokens.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: detailLayer.it ? [
                                    root.fmtSize(detailLayer.it.fileSize),
                                    qsTr("Ratio %1").arg(detailLayer.it.ratio || "—"),
                                    (detailLayer.it.purity || "").toString()
                                ] : []
                                delegate: StyledRect {
                                    required property string modelData
                                    visible: modelData !== ""
                                    implicitHeight: 26
                                    implicitWidth: chipText.implicitWidth + 18
                                    radius: 13
                                    color: Qt.alpha(Colours.palette.m3primary, 0.14)
                                    StyledText {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        textPointSize: Tokens.font.size.small
                                        font.weight: Font.Medium
                                        color: Colours.palette.m3primary
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: detailLayer.it && detailLayer.it.colors && detailLayer.it.colors.length > 0
                            StyledText {
                                text: qsTr("Palette")
                                textPointSize: Tokens.font.size.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                            Repeater {
                                model: detailLayer.it ? (detailLayer.it.colors || []) : []
                                delegate: Rectangle {
                                    required property string modelData
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: modelData
                                    border.width: 1
                                    border.color: Qt.alpha(Colours.palette.m3outline, 0.4)
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: root.detailInfo && root.detailInfo.tags && root.detailInfo.tags.length > 0
                            Repeater {
                                model: root.detailInfo ? (root.detailInfo.tags || []) : []
                                delegate: StyledRect {
                                    required property string modelData
                                    implicitHeight: 24
                                    implicitWidth: tagText.implicitWidth + 16
                                    radius: 12
                                    color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
                                    StyledText {
                                        id: tagText
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        textPointSize: Tokens.font.size.smaller
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Action button (same item as the card's; anchored to bottom so it rides the morph) ──
                StyledClippingRect {
                    id: dButton
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: detailLayer.pad
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: detailLayer.pad
                    anchors.rightMargin: detailLayer.pad
                    height: 34 + 6 * detailLayer.pc
                    radius: height / 2
                    clip: true

                    readonly property bool isDownloading: detailLayer.dBusy
                    readonly property int currentProgress: detailLayer.dProgress
                    readonly property bool isInstalled: detailLayer.dInstalled
                    readonly property bool isCurrent: detailLayer.dCurrent

                    color: isDownloading
                        ? Qt.alpha(Colours.palette.m3primary, 0.15)
                        : (isInstalled
                            ? (dActMa.containsMouse ? Colours.layer(Colours.palette.m3secondaryContainer, 2) : Colours.palette.m3secondaryContainer)
                            : (dActMa.containsMouse ? Colours.layer(Colours.palette.m3primary, 2) : Colours.palette.m3primary))

                    Behavior on color { CAnim {} }

                    // State 1: "Installed" / "Applied" Content
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        opacity: (dButton.isInstalled && !dButton.isDownloading) ? 1.0 : 0.0
                        visible: opacity > 0.01
                        Behavior on opacity { Anim { type: Anim.FastEffects } }

                        MaterialIcon {
                            iconPointSize: 16
                            color: Colours.palette.m3onSecondaryContainer
                            text: dButton.isCurrent ? "check" : "wallpaper"
                        }

                        StyledText {
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.normal
                            color: Colours.palette.m3onSecondaryContainer
                            text: dButton.isCurrent ? qsTr("Applied") : qsTr("Set Wallpaper")
                        }
                    }

                    // State 2: "Download & Set" Content
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        opacity: (!dButton.isInstalled && !dButton.isDownloading) ? 1.0 : 0.0
                        visible: opacity > 0.01
                        Behavior on opacity { Anim { type: Anim.FastEffects } }

                        MaterialIcon {
                            iconPointSize: 16
                            color: Colours.palette.m3onPrimary
                            text: "download"
                        }

                        StyledText {
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.normal
                            color: Colours.palette.m3onPrimary
                            text: qsTr("Download & Set")
                        }
                    }

                    // State 3: Base "Downloading... X%" Content
                    RowLayout {
                        id: detailBtnBaseContent
                        anchors.centerIn: parent
                        spacing: 6
                        opacity: dButton.isDownloading ? 1.0 : 0.0
                        visible: opacity > 0.01
                        Behavior on opacity { Anim { type: Anim.FastEffects } }

                        MaterialIcon {
                            iconPointSize: 16
                            color: Colours.palette.m3primary
                            text: "downloading"
                        }

                        StyledText {
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.normal
                            color: Colours.palette.m3primary
                            text: qsTr("Downloading... %1%").arg(dButton.currentProgress)
                        }
                    }

                    // Dynamic Progress Fill (clipped inside with rounded cap & inverted text)
                    Rectangle {
                        id: detailBtnProgressFill
                        visible: dButton.isDownloading
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(0, Math.min(dButton.width, Math.round(dButton.width * (dButton.currentProgress / 100.0))))
                        radius: height / 2
                        color: Colours.palette.m3primary
                        clip: true
                        z: 2

                        Behavior on width {
                            Anim {
                                type: Anim.StandardLarge
                            }
                        }

                        RowLayout {
                            width: detailBtnBaseContent.width
                            height: detailBtnBaseContent.height
                            x: (dButton.width - width) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            MaterialIcon {
                                iconPointSize: 16
                                color: Colours.palette.m3onPrimary
                                text: "downloading"
                            }

                            StyledText {
                                font.weight: Font.DemiBold
                                textPointSize: Tokens.font.size.normal
                                color: Colours.palette.m3onPrimary
                                text: qsTr("Downloading... %1%").arg(dButton.currentProgress)
                            }
                        }
                    }

                    MouseArea {
                        id: dActMa
                        anchors.fill: parent
                        hoverEnabled: !dButton.isDownloading
                        cursorShape: dButton.isDownloading ? Qt.ArrowCursor : Qt.PointingHandCursor
                        enabled: !dButton.isDownloading
                        onClicked: {
                            if (dButton.isInstalled) {
                                if (detailLayer.dPath) Wallpapers.setWallpaper(detailLayer.dPath);
                            } else {
                                root.downloadWallpaper(detailLayer.it, true);
                            }
                        }
                    }
                }
            }
        }
    }

    readonly property FileDialog wallpaperDirPicker: FileDialog {
        title: qsTr("Select Wallpaper Directory")
        filterLabel: qsTr("Folders")
        filters: ["*"]
        initialCwd: ["Home", "Pictures", "Wallpapers"]
        resetCwdOnOpen: true

        onAccepted: path => {
            let dirPath = path;
            if (dirPath.includes(".")) {
                const parts = dirPath.split("/");
                parts.pop();
                dirPath = parts.join("/");
            }
            GlobalConfig.paths.wallpaperDir = dirPath;
            GlobalConfig.save();
            Wallpapers.ensureCatalog();
            Quickshell.execDetached(["notify-send", "-a", "olvex-shell", "-u", "low", qsTr("Wallpaper directory updated"), qsTr("Set to %1").arg(dirPath)]);
        }
    }
}
