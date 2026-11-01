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

Item {
    id: root

    property Session session
    opacity: 0.0
    transform: Translate { id: yTrans; y: 20 }

    Component.onCompleted: {
        revealAnim.start();
        refreshThemes();
        refreshSettings();
    }

    ParallelAnimation {
        id: revealAnim
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: yTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutCubic }
    }

    // ── Tab state ──
    property int currentTab: 0 // 0: Installed, 1: Store

    // ── Installed Themes Data ──
    property var themesList: []
    property string activeThemeId: ""
    property bool isScanning: false
    property bool isApplying: false

    // ── Cursor Basic Settings ──
    property int cursorSize: 24
    property int inactiveTimeout: 0
    property bool noWarps: false
    property real zoomFactor: 1.0

    function getThemesScriptPath() {
        const candidates = [
            "/home/abm/Projects/QS-Config/Github/Olvex/scripts/src/olvex/utils/cursor_themes.py",
            Paths.home + "/.local/Olvex/scripts/src/olvex/utils/cursor_themes.py",
            Paths.home + "/Projects/QS-Config/Olvex/scripts/src/olvex/utils/cursor_themes.py"
        ];
        if (typeof CUtils !== "undefined" && typeof CUtils.fileExists === "function") {
            for (let i = 0; i < candidates.length; i++) {
                if (CUtils.fileExists(candidates[i])) return candidates[i];
            }
        }
        return candidates[0];
    }

    function getMarketScriptPath() {
        const candidates = [
            "/home/abm/Projects/QS-Config/Github/Olvex/scripts/src/olvex/utils/cursor_market.py",
            Paths.home + "/.local/Olvex/scripts/src/olvex/utils/cursor_market.py",
            Paths.home + "/Projects/QS-Config/Olvex/scripts/src/olvex/utils/cursor_market.py"
        ];
        if (typeof CUtils !== "undefined" && typeof CUtils.fileExists === "function") {
            for (let i = 0; i < candidates.length; i++) {
                if (CUtils.fileExists(candidates[i])) return candidates[i];
            }
        }
        return candidates[0];
    }

    function refreshThemes() {
        if (isScanning) return;
        isScanning = true;
        try {
            scannerProc.command = ["python3", getThemesScriptPath()];
            scannerProc.running = false;
            scannerProc.running = true;
        } catch (e) {
            console.warn("[AppearanceCursor] refreshThemes error:", e);
            isScanning = false;
        }
    }

    function refreshSettings() {
        try {
            settingsProc.command = ["python3", getThemesScriptPath(), "settings"];
            settingsProc.running = false;
            settingsProc.running = true;
        } catch (e) {
            console.warn("[AppearanceCursor] refreshSettings error:", e);
        }
    }

    function applyTheme(themeId) {
        if (!themeId) return;
        activeThemeId = themeId;
        isApplying = true;
        try {
            applyProc.command = ["python3", getThemesScriptPath(), "set", themeId, String(root.cursorSize)];
            applyProc.running = false;
            applyProc.running = true;
        } catch (e) {
            console.warn("[AppearanceCursor] applyTheme error:", e);
            isApplying = false;
        }
    }

    function setCursorSetting(key, val) {
        try {
            settingUpdateProc.command = ["python3", getThemesScriptPath(), "set_setting", key, String(val)];
            settingUpdateProc.running = false;
            settingUpdateProc.running = true;
        } catch (e) {
            console.warn("[AppearanceCursor] setCursorSetting error:", e);
        }
    }

    Process {
        id: scannerProc
        onExited: (exitCode, exitStatus) => {
            root.isScanning = false;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.isScanning = false;
                if (!text || text.trim() === "") return;
                try {
                    const parsed = JSON.parse(text.trim());
                    root.themesList = parsed;
                    for (let i = 0; i < parsed.length; i++) {
                        if (parsed[i].isCurrent) {
                            root.activeThemeId = parsed[i].id;
                            break;
                        }
                    }
                    if (!root.activeThemeId && parsed.length > 0) {
                        root.activeThemeId = parsed[0].id;
                    }
                } catch (e) {
                    console.warn("[AppearanceCursor] Failed to parse cursor themes:", e);
                }
            }
        }
    }

    Process {
        id: settingsProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "") return;
                try {
                    const d = JSON.parse(text.trim());
                    if (d.size) root.cursorSize = d.size;
                    if (d.inactiveTimeout !== undefined) root.inactiveTimeout = d.inactiveTimeout;
                    if (d.noWarps !== undefined) root.noWarps = d.noWarps;
                    if (d.zoomFactor !== undefined) root.zoomFactor = d.zoomFactor;
                    if (d.theme) root.activeThemeId = d.theme;
                } catch (e) {
                    console.warn("[AppearanceCursor] Failed to parse cursor settings:", e);
                }
            }
        }
    }

    Process {
        id: settingUpdateProc
        onExited: (exitCode, exitStatus) => {
            root.refreshSettings();
        }
    }

    function onThemeApplied() {
        if (!root.activeThemeId) return;
        if (typeof Toaster !== "undefined" && Toaster.toast) {
            Toaster.toast(
                qsTr("Cursor Theme Applied"),
                qsTr("Switched cursor theme to %1").arg(root.activeThemeId),
                "check_circle"
            );
        }
        root.refreshThemes();
        root.refreshSettings();
    }

    Process {
        id: applyProc
        onExited: (exitCode, exitStatus) => {
            if (root.isApplying) {
                root.isApplying = false;
                if (exitCode === 0) {
                    root.onThemeApplied();
                }
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.isApplying) {
                    root.isApplying = false;
                    root.onThemeApplied();
                }
            }
        }
    }

    // ── Delete Cursor Theme Operations ──
    property bool isDeleting: false
    property var pendingDeleteTheme: null

    function promptDeleteTheme(theme) {
        if (!theme) return;
        pendingDeleteTheme = theme;
        deleteModal.visible = true;
    }

    function confirmDeleteTheme() {
        if (!pendingDeleteTheme || !pendingDeleteTheme.id) {
            deleteModal.visible = false;
            return;
        }
        isDeleting = true;
        deleteModal.visible = false;
        deleteProc.command = ["python3", getThemesScriptPath(), "delete", pendingDeleteTheme.id];
        deleteProc.running = false;
        deleteProc.running = true;
    }

    Process {
        id: deleteProc
        onExited: (exitCode, exitStatus) => {
            root.isDeleting = false;
            if (exitCode === 0) {
                const targetTheme = root.pendingDeleteTheme;
                root.pendingDeleteTheme = null;
                const delName = targetTheme ? (targetTheme.name || "") : "";
                const delId = targetTheme ? (targetTheme.id || "") : "";
                const delMarketId = targetTheme ? (targetTheme.marketId || "") : "";

                if (typeof Toaster !== "undefined" && Toaster.toast) {
                    Toaster.toast(
                        qsTr("Cursor Theme Deleted"),
                        qsTr("Deleted %1 successfully").arg(delName || delId),
                        "delete"
                    );
                }

                // Update overrides map to trigger smooth animation on normal card & detail modal WITHOUT destroying delegates
                let ov = Object.assign({}, root.installedOverrides);
                if (delId) ov[delId] = false;
                if (delName) ov[delName] = false;
                if (delMarketId) ov[delMarketId] = false;
                root.installedOverrides = ov;

                // Mutate items in place so data stays accurate without triggering Repeater model reset
                for (let i = 0; i < root.marketList.length; i++) {
                    const item = root.marketList[i];
                    if (item.id === delId || item.installedThemeId === delId || (delName && (item.name === delName || item.installedThemeId === delName || item.id === delName)) || (delMarketId && item.id === delMarketId)) {
                        item.isInstalled = false;
                        item.installedThemeId = "";
                    }
                }

                if (root.detailTheme && (root.detailTheme.name === delName || root.detailTheme.id === delId || root.detailTheme.installedThemeId === delId || (delMarketId && root.detailTheme.id === delMarketId))) {
                    let dt = Object.assign({}, root.detailTheme);
                    dt.isInstalled = false;
                    dt.installedThemeId = "";
                    root.detailTheme = dt;
                }

                root.refreshThemes();
            } else {
                root.pendingDeleteTheme = null;
                if (typeof Toaster !== "undefined" && Toaster.toast) {
                    Toaster.toast(qsTr("Deletion Failed"), qsTr("Could not delete theme"), "error");
                }
            }
        }
    }

    // ── Online Cursor Pack Market Data ──
    property var marketList: []
    property bool marketLoading: false
    property int marketPage: 0
    property bool marketHasMore: true
    property bool marketAppendMode: false
    property string marketSort: "downloads"
    property string marketSearch: ""
    property var installingThemes: ({})
    property var installProgress: ({})
    property var installedOverrides: ({})

    // ── Direct Flickable Connections for infinite scroll ──
    Connections {
        target: contentFlickable
        enabled: root.currentTab === 1 && !root.marketLoading && root.marketHasMore && root.marketList.length > 0
        function onContentYChanged() {
            if (!contentFlickable) return;
            if (contentFlickable.atYEnd || (contentFlickable.contentY + contentFlickable.height >= contentFlickable.contentHeight - 350)) {
                root.loadMoreMarket();
            }
        }
        function onAtYEndChanged() {
            if (contentFlickable && contentFlickable.atYEnd) {
                root.loadMoreMarket();
            }
        }
    }

    function formatNumber(num) {
        if (!num) return "0";
        if (num >= 1000000) return (num / 1000000).toFixed(1) + "M";
        if (num >= 1000) return (num / 1000).toFixed(1) + "k";
        return String(num);
    }

    function applySorting() {
        if (root.marketList && root.marketList.length > 0) {
            const list = root.marketList.slice();
            if (root.marketSort === "rating") {
                list.sort((a, b) => ((b.rating || 0) - (a.rating || 0)) || ((b.downloads || 0) - (a.downloads || 0)));
            } else if (root.marketSort === "newest" || root.marketSort === "new") {
                list.sort((a, b) => (parseInt(b.id || 0) - parseInt(a.id || 0)));
            } else {
                list.sort((a, b) => ((b.downloads || 0) - (a.downloads || 0)) || ((b.rating || 0) - (a.rating || 0)));
            }
            root.marketList = list;
        }
        root.refreshMarket();
    }

    function refreshMarket() {
        marketPage = 0;
        marketHasMore = true;
        fetchMarket(0, false);
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
            marketProc.command = [
                "python3",
                getMarketScriptPath(),
                "browse",
                root.marketSort,
                String(page),
                root.marketSearch,
                "desc"
            ];
            marketProc.running = false;
            marketProc.running = true;
        } catch (e) {
            console.warn("[AppearanceCursor] fetchMarket error:", e);
            marketLoading = false;
        }
    }

    property int thumbEpoch: 0
    property int thumbTicksLeft: 0

    Timer {
        id: thumbPollTimer
        interval: 450
        repeat: true
        running: root.currentTab === 1 && root.thumbTicksLeft > 0
        onTriggered: {
            root.thumbEpoch++;
            root.thumbTicksLeft--;
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
                    if (parsed && Array.isArray(parsed.items) && parsed.items.length > 0) {
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
                        root.marketHasMore = parsed.items.length >= 10;
                        root.thumbTicksLeft = 25;
                        root.thumbEpoch++;
                    } else {
                        if (!root.marketAppendMode) root.marketList = [];
                        root.marketHasMore = false;
                    }
                } catch (e) {
                    console.warn("[AppearanceCursor] Market parse error:", e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "") {
                    console.warn("[AppearanceCursor] Market stderr:", text);
                }
            }
        }
    }

    function installPack(item) {
        if (!item || !item.downloadUrl) return;
        let map = Object.assign({}, root.installingThemes);
        map[item.id] = true;
        root.installingThemes = map;

        let progMap = Object.assign({}, root.installProgress);
        progMap[item.id] = 5;
        root.installProgress = progMap;

        var proc = installProcComponent.createObject(root, {
            themeItem: item,
            command: [
                "python3",
                getMarketScriptPath(),
                "install",
                item.downloadUrl,
                item.downloadName || (item.name + ".tar.gz")
            ]
        });
        proc.running = true;
    }

    Component {
        id: installProcComponent
        Process {
            id: currentInstallProc
            property var themeItem: null

            stdout: SplitParser {
                onRead: data => {
                    const line = data.trim();
                    if (line.startsWith("PROGRESS:")) {
                        const pct = parseInt(line.substring(9), 10);
                        if (!isNaN(pct) && currentInstallProc.themeItem) {
                            let progMap = Object.assign({}, root.installProgress);
                            progMap[currentInstallProc.themeItem.id] = pct;
                            root.installProgress = progMap;
                        }
                    }
                }
            }

            onExited: (exitCode, exitStatus) => {
                if (themeItem) {
                    let map = Object.assign({}, root.installingThemes);
                    delete map[themeItem.id];
                    root.installingThemes = map;

                    let progMap = Object.assign({}, root.installProgress);
                    delete progMap[themeItem.id];
                    root.installProgress = progMap;

                    if (exitCode === 0) {
                        if (typeof Toaster !== "undefined" && Toaster.toast) {
                            Toaster.toast(
                                qsTr("Cursor Theme Installed"),
                                qsTr("Successfully installed %1").arg(themeItem.name),
                                "download_done"
                            );
                        }
                        if (themeItem) {
                            let ov = Object.assign({}, root.installedOverrides);
                            ov[themeItem.id] = true;
                            if (themeItem.name) ov[themeItem.name] = true;
                            root.installedOverrides = ov;

                            for (let i = 0; i < root.marketList.length; i++) {
                                if (root.marketList[i].id === themeItem.id) {
                                    root.marketList[i].isInstalled = true;
                                    root.marketList[i].installedThemeId = themeItem.name || themeItem.id;
                                    break;
                                }
                            }
                            if (root.detailTheme && root.detailTheme.id === themeItem.id) {
                                let dt = Object.assign({}, root.detailTheme);
                                dt.isInstalled = true;
                                dt.installedThemeId = themeItem.name || themeItem.id;
                                root.detailTheme = dt;
                            }
                        }
                        root.refreshThemes();
                    } else {
                        if (typeof Toaster !== "undefined" && Toaster.toast) {
                            Toaster.toast(
                                qsTr("Installation Failed"),
                                qsTr("Could not install %1").arg(themeItem.name),
                                "error"
                            );
                        }
                    }
                }
                currentInstallProc.destroy();
            }
        }
    }

    function uninstallPack(item) {
        if (!item) return;
        promptDeleteTheme({
            id: item.installedThemeId || item.name,
            name: item.name,
            marketId: item.id
        });
    }

    Process {
        id: uninstallProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                if (typeof Toaster !== "undefined" && Toaster.toast) {
                    Toaster.toast(
                        qsTr("Cursor Theme Removed"),
                        qsTr("Theme uninstalled successfully"),
                        "delete"
                    );
                }
                if (root.detailTheme) {
                    const dtId = root.detailTheme.id;
                    const dtName = root.detailTheme.name;
                    let list = root.marketList.slice();
                    for (let i = 0; i < list.length; i++) {
                        if (list[i].id === dtId || list[i].installedThemeId === dtId || list[i].name === dtName) {
                            let updated = Object.assign({}, list[i]);
                            updated.isInstalled = false;
                            updated.installedThemeId = "";
                            list[i] = updated;
                        }
                    }
                    root.marketList = list;
                    root.closeThemeDetails();
                }
                root.refreshThemes();
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // STATIONARY TOP HEADER (Pinned / Does NOT scroll)
    // ══════════════════════════════════════════════════════════════════════
    ColumnLayout {
        id: headerContainer
        anchors.top: parent.top
        anchors.topMargin: Tokens.padding.normal
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.large
        z: 10

        // Row 1: Clean M3 Segmented Navigation Bar (Installed (N) | Store)
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.normal

            Segmented {
                model: [
                    { label: qsTr("Installed (%1)").arg(root.themesList.length) },
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
        }

        // Row 2: Control Header Row (Tab 0 Section vs Tab 1 Toolbar)
        Item {
            Layout.fillWidth: true
            implicitHeight: root.currentTab === 0 ? installedSection.implicitHeight : marketToolbarRow.implicitHeight

            // Tab 0: Section Title, Subtitle, and Installed Actions
            RowLayout {
                id: installedSection
                anchors.fill: parent
                spacing: Tokens.spacing.normal
                visible: root.currentTab === 0

                StyledRect {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    Layout.maximumWidth: 38
                    Layout.minimumWidth: 38
                    width: 38
                    height: 38
                    radius: Tokens.rounding.normal
                    color: Qt.alpha(Colours.palette.m3primary, 0.12)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "mouse"
                        color: Colours.palette.m3primary
                        iconPointSize: 20
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: qsTr("System Cursor Theme")
                        font.weight: Font.DemiBold
                        textPointSize: Tokens.font.size.large
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        text: qsTr("Pointers, hands, and window resize indicators")
                        textPointSize: Tokens.font.size.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                RowLayout {
                    spacing: Tokens.spacing.small
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                    // Expanding "Open Folder" button
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
                                anchors.horizontalCenterOffset: 1
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
                            onClicked: {
                                openDirProc.command = ["xdg-open", Paths.home + "/.cursors"];
                                openDirProc.running = false;
                                openDirProc.running = true;
                            }
                        }

                        Process { id: openDirProc }
                    }

                    // Expanding "Scan Themes" (rebuild) button
                    StyledRect {
                        id: scanThemesBtn
                        readonly property bool hovered: scanThemesMa.containsMouse
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

                            LoadingIndicator {
                                anchors.centerIn: parent
                                implicitSize: 18
                                color: Colours.palette.m3primary
                                animated: root.isScanning
                                visible: opacity > 0
                                opacity: root.isScanning ? 1.0 : 0.0
                                Behavior on opacity { Anim { type: Anim.FastEffects } }
                            }

                            MaterialIcon {
                                id: scanIcon
                                anchors.centerIn: parent
                                text: "refresh"
                                iconPointSize: 18
                                renderType: Text.QtRendering
                                antialiasing: true
                                color: Colours.palette.m3onSurface
                                visible: opacity > 0
                                opacity: root.isScanning ? 0.0 : 1.0
                                Behavior on opacity { Anim { type: Anim.FastEffects } }
                            }
                        }

                        StyledText {
                            id: scanText
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: scanIconWrap.right
                            anchors.leftMargin: 2
                            text: qsTr("Scan Themes")
                            textPointSize: Tokens.font.size.smaller
                            font.weight: Font.Medium
                            color: Colours.palette.m3onSurface
                            opacity: scanThemesBtn.hovered ? 1.0 : 0.0
                            Behavior on opacity { Anim { type: Anim.FastEffects } }
                        }

                        MouseArea {
                            id: scanThemesMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.isScanning ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !root.isScanning
                            onClicked: {
                                root.refreshThemes();
                                root.refreshSettings();
                            }
                        }
                    }
                }
            }

            // Tab 1: Store Toolbar (Sort by, Search, Refresh)
            RowLayout {
                id: marketToolbarRow
                anchors.fill: parent
                spacing: Tokens.spacing.normal
                visible: root.currentTab === 1

                // Store Sort Label
                StyledText {
                    text: qsTr("Sort by:")
                    color: Colours.palette.m3onSurfaceVariant
                    font.weight: Font.Medium
                    textPointSize: Tokens.font.size.normal
                    Layout.alignment: Qt.AlignVCenter
                }

                // Store Sort Selector (clean text OptionPicker without icons)
                OptionPicker {
                    id: storeSortPicker
                    Layout.alignment: Qt.AlignVCenter
                    model: [
                        { label: qsTr("Downloads"), val: "downloads" },
                        { label: qsTr("Rating"), val: "rating" },
                        { label: qsTr("Newest"), val: "newest" }
                    ]
                    currentIndex: root.marketSort === "rating" ? 1 : (root.marketSort === "newest" ? 2 : 0)
                    onSelected: i => {
                        const keys = ["downloads", "rating", "newest"];
                        root.marketSort = keys[i] || "downloads";
                        root.applySorting();
                    }
                }

                Item { Layout.fillWidth: true }

                // Expanding Search Pill (Store)
                StyledRect {
                    id: searchPill
                    property bool searchExpanded: false
                    readonly property bool searchActive: searchExpanded

                    implicitHeight: 38
                    implicitWidth: searchActive ? 240 : 38
                    radius: Tokens.rounding.full
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    border.width: 0
                    border.color: "transparent"
                    clip: true

                    Behavior on implicitWidth { Anim { type: Anim.DefaultSpatial } }
                    Behavior on color { CAnim {} }

                    MaterialIcon {
                        id: searchPillIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        color: searchPill.searchActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
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

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            acceptedButtons: Qt.NoButton
                        }

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
                            text: qsTr("Search cursor packs…")
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
                    color: refreshMarketMa.pressed ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) :
                           Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                    border.width: 1
                    border.color: refreshMarketMa.containsMouse ? "transparent" : Qt.alpha(Colours.palette.m3outlineVariant, 0.35)

                    Behavior on color { CAnim {} }
                    Behavior on border.color { CAnim {} }

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
                        id: refreshMarketIcon
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

    // ══════════════════════════════════════════════════════════════════════
    // SCROLLABLE CONTENT AREA
    // ══════════════════════════════════════════════════════════════════════
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

                // TAB 0: Installed Cursor Themes Content
                ColumnLayout {
                    id: installedContentCol
                    width: parent.width
                    visible: root.currentTab === 0
                    spacing: Tokens.spacing.large

                    // 3-Column Grid of Installed Cursor Themes (Fixed 3-card sizing)
                    GridLayout {
                        id: installedGrid
                        width: parent.width
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: Tokens.spacing.normal
                        rowSpacing: Tokens.spacing.normal
                        visible: root.themesList.length > 0

                        readonly property real cardWidth: Math.max(140, Math.floor((scrollContent.width - columnSpacing * 2) / 3))

                        Repeater {
                            model: root.themesList

                            delegate: Item {
                                id: cardDelegate
                                required property var modelData
                                required property int index

                                readonly property bool isSelected: modelData.id === root.activeThemeId
                                readonly property bool isHovered: installedCardMouse.containsMouse
                                readonly property bool isDeletable: (modelData.isDeletable !== undefined)
                                    ? modelData.isDeletable
                                    : (!modelData.path.startsWith("/usr") && modelData.id !== "default" && modelData.id !== "hicolor")

                                Layout.fillWidth: false
                                Layout.preferredWidth: installedGrid.cardWidth
                                Layout.maximumWidth: installedGrid.cardWidth
                                Layout.minimumWidth: installedGrid.cardWidth
                                width: installedGrid.cardWidth
                                Layout.preferredHeight: 160
                                implicitHeight: 160

                                StyledRect {
                                    id: cardBg
                                    anchors.fill: parent
                                    radius: Tokens.rounding.large

                                    color: cardDelegate.isHovered
                                        ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
                                        : Colours.layer(Colours.palette.m3surfaceContainer, 1)

                                    border.width: cardDelegate.isSelected ? 2 : 0
                                    border.color: cardDelegate.isSelected
                                        ? Colours.palette.m3primary
                                        : "transparent"

                                    Behavior on color { CAnim { duration: Tokens.anim.durations.small } }
                                    Behavior on border.color { CAnim { duration: Tokens.anim.durations.small } }

                                    // Delete Button (top-right, only on hover for user-installed themes)
                                    StyledRect {
                                        id: deleteThemeBtn
                                        visible: cardDelegate.isDeletable && !cardDelegate.isSelected
                                        opacity: (cardDelegate.isHovered || deleteThemeMa.containsMouse) ? 1.0 : 0.0
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 10
                                        width: 26
                                        height: 26
                                        radius: Tokens.rounding.full
                                        color: deleteThemeMa.pressed ? Colours.layer(Colours.palette.m3error, 1) :
                                               deleteThemeMa.containsMouse ? Colours.palette.m3error :
                                               Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6)
                                        border.width: 0
                                        z: 10

                                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                                        Behavior on color { CAnim {} }

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: "delete"
                                            iconPointSize: 14
                                            color: (deleteThemeMa.pressed || deleteThemeMa.containsMouse) ? Colours.palette.m3onError : Colours.palette.m3error
                                            Behavior on color { CAnim {} }
                                        }

                                        MouseArea {
                                            id: deleteThemeMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.promptDeleteTheme(modelData)
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Tokens.padding.normal
                                        spacing: Tokens.spacing.small

                                        // Cursor Previews Strip (mathematically concentric: large 24 - normal 12 = small 12)
                                        StyledRect {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 68
                                            radius: Tokens.rounding.small
                                            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
                                            border.width: 0
                                            border.color: "transparent"

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 10

                                                Repeater {
                                                    model: (modelData.previews && modelData.previews.length > 0)
                                                        ? modelData.previews.slice(0, 4)
                                                        : []

                                                    delegate: Item {
                                                        required property string modelData
                                                        Layout.preferredWidth: 28
                                                        Layout.preferredHeight: 28

                                                        Image {
                                                            anchors.centerIn: parent
                                                            width: 26
                                                            height: 26
                                                            source: modelData.startsWith("/") ? ("file://" + modelData) : modelData
                                                            sourceSize.width: 32
                                                            sourceSize.height: 32
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                            mipmap: true
                                                        }
                                                    }
                                                }

                                                MaterialIcon {
                                                    visible: !modelData.previews || modelData.previews.length === 0
                                                    text: "mouse"
                                                    iconPointSize: 24
                                                    color: Colours.palette.m3onSurfaceVariant
                                                }
                                            }
                                        }

                                        // Info with title + inline active check badge + subtitle
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: modelData.name || modelData.id
                                                    font.weight: cardDelegate.isSelected ? Font.DemiBold : Font.Medium
                                                    textPointSize: Tokens.font.size.normal
                                                    color: cardDelegate.isSelected ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                                    elide: Text.ElideRight
                                                }

                                                // Active M3 shape badge with M3 checkmark beside the title
                                                Item {
                                                    visible: cardDelegate.isSelected
                                                    Layout.preferredWidth: 18
                                                    Layout.preferredHeight: 18
                                                    Layout.alignment: Qt.AlignVCenter

                                                    MaterialShape {
                                                        anchors.fill: parent
                                                        shape: MaterialShape.Cookie12Sided
                                                        color: Colours.palette.m3primary
                                                    }

                                                    MaterialIcon {
                                                        anchors.centerIn: parent
                                                        text: "check"
                                                        iconPointSize: 11
                                                        color: Colours.palette.m3onPrimary
                                                    }
                                                }
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: modelData.comment ? modelData.comment : (modelData.path.startsWith("/usr") ? qsTr("System Cursor") : qsTr("Custom Cursor"))
                                                textPointSize: Tokens.font.size.small
                                                font.weight: Font.Normal
                                                color: cardDelegate.isSelected ? Qt.alpha(Colours.palette.m3onSurface, 0.70) : Colours.palette.m3onSurfaceVariant
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: installedCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.applyTheme(modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    // ── Basic Cursor Settings Section ──
                    Section {
                        Layout.fillWidth: true
                        title: qsTr("Cursor Settings")
                        description: qsTr("Pointer scale, timeout, and window interaction behavior")
                        icon: "tune"

                        // Setting 1: Cursor Size
                        SettingRow {
                            title: qsTr("Cursor Size")
                            description: qsTr("Size of mouse pointer across Wayland and GTK applications (%1 px)").arg(root.cursorSize)
                            icon: "format_size"

                            OptionPicker {
                                model: [
                                    { label: "24 px (Default)", val: 24 },
                                    { label: "28 px", val: 28 },
                                    { label: "32 px (Medium)", val: 32 },
                                    { label: "36 px", val: 36 },
                                    { label: "48 px (Large)", val: 48 }
                                ]
                                currentIndex: {
                                    const sizes = [24, 28, 32, 36, 48];
                                    const idx = sizes.indexOf(root.cursorSize);
                                    return idx >= 0 ? idx : 0;
                                }
                                onSelected: i => {
                                    const sizes = [24, 28, 32, 36, 48];
                                    const sz = sizes[i] || 24;
                                    root.cursorSize = sz;
                                    root.setCursorSetting("size", sz);
                                }
                            }
                        }

                        // Setting 2: Inactivity Timeout
                        SettingRow {
                            title: qsTr("Hide Cursor When Inactive")
                            description: qsTr("Automatically hide mouse cursor after a duration of no mouse movement")
                            icon: "timer"

                            OptionPicker {
                                model: [
                                    { label: qsTr("Never (Always Visible)"), val: 0 },
                                    { label: qsTr("3 seconds"), val: 3 },
                                    { label: qsTr("5 seconds"), val: 5 },
                                    { label: qsTr("10 seconds"), val: 10 },
                                    { label: qsTr("15 seconds"), val: 15 }
                                ]
                                currentIndex: {
                                    const timeouts = [0, 3, 5, 10, 15];
                                    const idx = timeouts.indexOf(root.inactiveTimeout);
                                    return idx >= 0 ? idx : 0;
                                }
                                onSelected: i => {
                                    const timeouts = [0, 3, 5, 10, 15];
                                    const t = timeouts[i] !== undefined ? timeouts[i] : 0;
                                    root.inactiveTimeout = t;
                                    root.setCursorSetting("inactive_timeout", t);
                                }
                            }
                        }

                        // Setting 3: Prevent Cursor Warping
                        SettingRow {
                            title: qsTr("Prevent Cursor Warping")
                            description: qsTr("Do not automatically snap mouse pointer to newly focused windows")
                            icon: "near_me_disabled"

                            StyledSwitch {
                                checked: root.noWarps
                                onToggled: {
                                    root.noWarps = checked;
                                    root.setCursorSetting("no_warps", checked ? 1 : 0);
                                }
                            }
                        }

                        // Setting 4: Cursor Zoom Factor
                        SettingRow {
                            title: qsTr("Cursor Zoom Factor")
                            description: qsTr("Hardware magnification scale multiplier for pointer visibility (%1x)").arg(root.zoomFactor.toFixed(2))
                            icon: "zoom_in"
                            divider: false

                            OptionPicker {
                                model: [
                                    { label: qsTr("1.00x (Standard)"), val: 1.0 },
                                    { label: qsTr("1.25x"), val: 1.25 },
                                    { label: qsTr("1.50x"), val: 1.5 },
                                    { label: qsTr("2.00x"), val: 2.0 }
                                ]
                                currentIndex: {
                                    const factors = [1.0, 1.25, 1.5, 2.0];
                                    const idx = factors.findIndex(f => Math.abs(f - root.zoomFactor) < 0.05);
                                    return idx >= 0 ? idx : 0;
                                }
                                onSelected: i => {
                                    const factors = [1.0, 1.25, 1.5, 2.0];
                                    const f = factors[i] || 1.0;
                                    root.zoomFactor = f;
                                    root.setCursorSetting("zoom_factor", f);
                                }
                            }
                        }
                    }
                }

                // TAB 1: Online Cursor Pack Market Content
                ColumnLayout {
                    id: marketContentCol
                    width: parent.width
                    visible: root.currentTab === 1
                    spacing: Tokens.spacing.normal

                    // Loading Indicator
                    Item {
                        visible: root.marketLoading && root.marketList.length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180

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
                                text: qsTr("Fetching online cursor themes from Store…")
                                color: Colours.palette.m3onSurfaceVariant
                                textPointSize: Tokens.font.size.normal
                                font.weight: Font.Medium
                            }
                        }
                    }

                    // Empty / No Results
                    Item {
                        visible: !root.marketLoading && root.marketList.length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 160

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: "sentiment_dissatisfied"
                                iconPointSize: 36
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("No cursor themes found")
                                color: Colours.palette.m3onSurface
                                textPointSize: Tokens.font.size.normal
                                font.weight: Font.Medium
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("Try searching for another keyword or refresh")
                                color: Colours.palette.m3onSurfaceVariant
                                textPointSize: Tokens.font.size.small
                            }
                        }
                    }

                    // 3-Column Grid of Online Cursor Themes
                    GridLayout {
                        id: marketGrid
                        width: parent.width
                        columns: 3
                        columnSpacing: Tokens.spacing.normal
                        rowSpacing: Tokens.spacing.normal
                        visible: root.marketList.length > 0

                        Repeater {
                            model: root.marketList

                            delegate: Item {
                                id: storeCardDelegate
                                required property var modelData
                                required property int index

                                readonly property bool isBeingInstalled: Boolean(root.installingThemes[modelData.id])
                                readonly property int currentProgress: root.installProgress[modelData.id] || 0
                                readonly property bool isHovered: storeCardMouse.containsMouse
                                readonly property bool isSelectedForDetail: root.detailTheme && (root.detailTheme.id === modelData.id) && root.detailVisible
                                readonly property bool isThemeInstalled: {
                                    const override = (root.installedOverrides[modelData.id] !== undefined)
                                        ? root.installedOverrides[modelData.id]
                                        : ((modelData.installedThemeId && root.installedOverrides[modelData.installedThemeId] !== undefined)
                                            ? root.installedOverrides[modelData.installedThemeId]
                                            : ((modelData.name && root.installedOverrides[modelData.name] !== undefined)
                                                ? root.installedOverrides[modelData.name]
                                                : undefined));
                                    if (override !== undefined) return Boolean(override);
                                    return Boolean(modelData.isInstalled);
                                }

                                opacity: {
                                    if (!isSelectedForDetail) return 1.0;
                                    if (collapseAnimation.running && root.clampedMorph < 0.12) {
                                        return 1.0 - (root.clampedMorph / 0.12);
                                    }
                                    return 0.0;
                                }

                                Layout.fillWidth: true
                                Layout.preferredWidth: Math.max(100, Math.floor((marketGrid.width - marketGrid.columnSpacing * 2) / 3))
                                Layout.maximumWidth: Layout.preferredWidth
                                Layout.preferredHeight: 236
                                implicitHeight: 236

                                StyledRect {
                                    anchors.fill: parent
                                    radius: Tokens.rounding.large

                                    color: storeCardDelegate.isHovered
                                        ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
                                        : root.normalCardBg

                                    border.width: 0
                                    border.color: "transparent"

                                    Behavior on color { CAnim {} }
                                    Behavior on border.color { CAnim {} }

                                    MouseArea {
                                        id: storeCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openThemeDetails(modelData, storeCardDelegate)
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Tokens.padding.normal
                                        spacing: Tokens.spacing.small

                                        // Cursor Preview / Thumbnail Container (Clipped to Rounded Bento Frame)
                                        StyledClippingRect {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 114
                                            radius: Tokens.rounding.normal
                                            color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.5)
                                            antialiasing: true

                                            Image {
                                                id: previewImg
                                                anchors.fill: parent
                                                source: {
                                                    const _ = root.thumbEpoch;
                                                    const p = modelData.preview || "";
                                                    if (!p) return "";
                                                    if (p.startsWith("/")) {
                                                        if (typeof CUtils !== "undefined" && CUtils.fileExists(p)) {
                                                            return "file://" + p;
                                                        }
                                                        return "";
                                                    }
                                                    return p;
                                                }
                                                fillMode: Image.PreserveAspectCrop
                                                sourceSize.width: 480
                                                sourceSize.height: 320
                                                cache: true
                                                asynchronous: true
                                                smooth: true
                                                antialiasing: true
                                                mipmap: true
                                                visible: status === Image.Ready

                                                Behavior on opacity { Anim { type: Anim.FastEffects } }
                                            }

                                            // Fallback Icon when preview is loading or absent
                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                visible: previewImg.status !== Image.Ready
                                                text: "mouse"
                                                iconPointSize: 36
                                                color: Colours.palette.m3onSurfaceVariant
                                            }

                                            // Rating and Download Badges
                                            RowLayout {
                                                anchors.top: parent.top
                                                anchors.topMargin: 6
                                                anchors.left: parent.left
                                                anchors.leftMargin: 6
                                                anchors.right: parent.right
                                                anchors.rightMargin: 6
                                                spacing: 4

                                                // Rating Pill
                                                StyledRect {
                                                    visible: modelData.rating > 0
                                                    implicitHeight: 22
                                                    implicitWidth: ratingRow.implicitWidth + 12
                                                    radius: Tokens.rounding.full
                                                    color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.85)
                                                    border.color: "transparent"
                                                    border.width: 0

                                                    RowLayout {
                                                        id: ratingRow
                                                        anchors.centerIn: parent
                                                        spacing: 3

                                                        MaterialIcon {
                                                            text: "star"
                                                            iconPointSize: 11
                                                            color: "#f5a623"
                                                        }

                                                        StyledText {
                                                            text: modelData.rating + "%"
                                                            textPointSize: Tokens.font.size.smaller
                                                            font.weight: Font.DemiBold
                                                            color: Colours.palette.m3onSurface
                                                        }
                                                    }
                                                }

                                                Item { Layout.fillWidth: true }

                                                // Download Count Pill
                                                StyledRect {
                                                    visible: modelData.downloads > 0
                                                    implicitHeight: 22
                                                    implicitWidth: dlRow.implicitWidth + 12
                                                    radius: Tokens.rounding.full
                                                    color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.85)
                                                    border.color: "transparent"
                                                    border.width: 0

                                                    RowLayout {
                                                        id: dlRow
                                                        anchors.centerIn: parent
                                                        spacing: 3

                                                        MaterialIcon {
                                                            text: "download"
                                                            iconPointSize: 11
                                                            color: Colours.palette.m3primary
                                                        }

                                                        StyledText {
                                                            text: root.formatNumber(modelData.downloads)
                                                            textPointSize: Tokens.font.size.smaller
                                                            font.weight: Font.DemiBold
                                                            color: Colours.palette.m3onSurface
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Info: Title and Author
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: modelData.name
                                                textPointSize: Tokens.font.size.normal
                                                font.weight: Font.DemiBold
                                                color: Colours.palette.m3onSurface
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: modelData.author ? (qsTr("by ") + modelData.author) : qsTr("Store")
                                                textPointSize: Tokens.font.size.small
                                                font.weight: Font.Normal
                                                color: Colours.palette.m3onSurfaceVariant
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Item {
                                            Layout.fillHeight: true
                                        }

                                        // Action Row: Install / Uninstall Button (direct continuous spatial interpolation, zero RowLayout snapping)
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 34
                                            height: 34
                                            z: 10

                                            readonly property bool showDelete: storeCardDelegate.isThemeInstalled && !storeCardDelegate.isBeingInstalled
                                            property real deleteProgress: showDelete ? 1.0 : 0.0
                                            Behavior on deleteProgress { Anim { type: Anim.DefaultSpatial } }

                                            // Main Install / Installed Button
                                            StyledClippingRect {
                                                id: installBtn
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                anchors.right: parent.right
                                                anchors.rightMargin: parent.deleteProgress * (34 + Tokens.spacing.small)
                                                radius: height / 2

                                                color: storeCardDelegate.isBeingInstalled ? Qt.alpha(Colours.palette.m3primary, 0.14) :
                                                       storeCardDelegate.isThemeInstalled ? Colours.palette.m3secondaryContainer :
                                                       installBtnMa.containsMouse ? Colours.layer(Colours.palette.m3primary, 1) : Colours.palette.m3primary

                                                // Progress Bar during installation (strictly masked by StyledClippingRect with rounded cap)
                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    width: Math.max(0, Math.min(parent.width, Math.round(parent.width * (storeCardDelegate.currentProgress / 100.0))))
                                                    radius: height / 2
                                                    color: Colours.palette.m3primary
                                                    clip: true
                                                    z: 2
                                                    visible: storeCardDelegate.isBeingInstalled
                                                    Behavior on width { Anim { type: Anim.StandardLarge } }

                                                    RowLayout {
                                                        width: cursorInstallBaseContent.width
                                                        height: cursorInstallBaseContent.height
                                                        x: (installBtn.width - width) / 2
                                                        y: (installBtn.height - height) / 2
                                                        spacing: Tokens.spacing.small

                                                        MaterialIcon {
                                                            text: "downloading"
                                                            iconPointSize: 16
                                                            color: Colours.palette.m3onPrimary
                                                        }

                                                        StyledText {
                                                            text: qsTr("Installing... %1%").arg(storeCardDelegate.currentProgress)
                                                            font.weight: Font.Medium
                                                            textPointSize: Tokens.font.size.small
                                                            color: Colours.palette.m3onPrimary
                                                        }
                                                    }
                                                }

                                                // State 1: "Installed" Content (Fades out cleanly without text re-layout)
                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    spacing: Tokens.spacing.small
                                                    opacity: (storeCardDelegate.isThemeInstalled && !storeCardDelegate.isBeingInstalled) ? 1.0 : 0.0
                                                    visible: opacity > 0.01

                                                    Behavior on opacity { Anim { type: Anim.FastEffects } }

                                                    MaterialIcon {
                                                        text: "check"
                                                        iconPointSize: 16
                                                        color: Colours.palette.m3onSecondaryContainer
                                                    }

                                                    StyledText {
                                                        text: qsTr("Installed")
                                                        font.weight: Font.Medium
                                                        textPointSize: Tokens.font.size.small
                                                        color: Colours.palette.m3onSecondaryContainer
                                                    }
                                                }

                                                // State 2: "Install" Content (Fades in cleanly without text re-layout)
                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    spacing: Tokens.spacing.small
                                                    opacity: (!storeCardDelegate.isThemeInstalled && !storeCardDelegate.isBeingInstalled) ? 1.0 : 0.0
                                                    visible: opacity > 0.01

                                                    Behavior on opacity { Anim { type: Anim.FastEffects } }

                                                    MaterialIcon {
                                                        text: "download"
                                                        iconPointSize: 16
                                                        color: Colours.palette.m3onPrimary
                                                    }

                                                    StyledText {
                                                        text: qsTr("Install")
                                                        font.weight: Font.Medium
                                                        textPointSize: Tokens.font.size.small
                                                        color: Colours.palette.m3onPrimary
                                                    }
                                                }

                                                // State 3: "Installing... %1%" Content
                                                RowLayout {
                                                    id: cursorInstallBaseContent
                                                    anchors.centerIn: parent
                                                    spacing: Tokens.spacing.small
                                                    opacity: storeCardDelegate.isBeingInstalled ? 1.0 : 0.0
                                                    visible: opacity > 0.01

                                                    Behavior on opacity { Anim { type: Anim.FastEffects } }

                                                    MaterialIcon {
                                                        text: "downloading"
                                                        iconPointSize: 16
                                                        color: Colours.palette.m3primary
                                                    }

                                                    StyledText {
                                                        text: qsTr("Installing... %1%").arg(storeCardDelegate.currentProgress)
                                                        font.weight: Font.Medium
                                                        textPointSize: Tokens.font.size.small
                                                        color: Colours.palette.m3primary
                                                    }
                                                }

                                                MouseArea {
                                                    id: installBtnMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: (storeCardDelegate.isBeingInstalled || storeCardDelegate.isThemeInstalled) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                    enabled: !storeCardDelegate.isBeingInstalled && !storeCardDelegate.isThemeInstalled && !!modelData.downloadUrl
                                                    onPressed: (mouse) => { mouse.accepted = true; }
                                                    onClicked: (mouse) => {
                                                        mouse.accepted = true;
                                                        root.installPack(modelData);
                                                    }
                                                }
                                            }

                                            // Uninstall Button (for installed market packs - smoothly appears on install / disappears on delete)
                                            StyledRect {
                                                id: uninstallStoreBtn
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: parent.deleteProgress * 34
                                                radius: Tokens.rounding.full
                                                z: 10
                                                opacity: parent.deleteProgress
                                                visible: width > 0.5 && opacity > 0.01
                                                clip: true

                                                color: uninstallBtnMa.pressed ? Colours.layer(Colours.palette.m3error, 1) :
                                                       uninstallBtnMa.containsMouse ? Colours.palette.m3error :
                                                       Qt.alpha(Colours.palette.m3error, 0.14)
                                                border.width: 0
                                                border.color: "transparent"

                                                Behavior on color { CAnim {} }

                                                MaterialIcon {
                                                    anchors.centerIn: parent
                                                    text: "delete"
                                                    iconPointSize: 16
                                                    color: (uninstallBtnMa.pressed || uninstallBtnMa.containsMouse) ? Colours.palette.m3onError : Colours.palette.m3error
                                                    Behavior on color { CAnim {} }
                                                }

                                                MouseArea {
                                                    id: uninstallBtnMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onPressed: (mouse) => { mouse.accepted = true; }
                                                    onClicked: (mouse) => {
                                                        mouse.accepted = true;
                                                        root.promptDeleteTheme({
                                                            id: modelData.installedThemeId || modelData.name,
                                                            name: modelData.name,
                                                            marketId: modelData.id
                                                        });
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Auto-loading bottom indicator
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        Layout.topMargin: Tokens.spacing.normal
                        Layout.bottomMargin: Tokens.spacing.large
                        visible: root.marketList.length > 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small

                            RowLayout {
                                visible: root.marketLoading
                                Layout.alignment: Qt.AlignHCenter
                                spacing: Tokens.spacing.normal

                                LoadingIndicator {
                                    implicitSize: 24
                                    color: Colours.palette.m3primary
                                    animated: root.marketLoading
                                }

                                StyledText {
                                    text: qsTr("Loading more cursor packs...")
                                    color: Colours.palette.m3onSurfaceVariant
                                    textPointSize: Tokens.font.size.normal
                                }
                            }

                            StyledText {
                                visible: !root.marketLoading && !root.marketHasMore
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("All %1 cursor packs loaded").arg(root.marketList.length)
                                color: Colours.palette.m3onSurfaceVariant
                                textPointSize: Tokens.font.size.smaller
                            }
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // THEME DETAILS CONTAINER TRANSFORM OVERLAY
    // ══════════════════════════════════════════════════════════════════════
    property var detailTheme: null
    property rect detailSourceRect: Qt.rect(0, 0, 0, 0)
    property bool detailVisible: false

    readonly property color normalCardBg: {
        const c = Colours.layer(Colours.palette.m3surfaceContainer, 1);
        return Qt.rgba(c.r, c.g, c.b, 1.0);
    }

    property real morphProgress: 0.0
    readonly property real clampedMorph: Math.max(0.0, Math.min(1.0, morphProgress))
    readonly property real expandedHeroHeight: Math.min(250, Math.round(detailCard.targetHeight * 0.48))
    property real expandedExtrasOpacity: 0.0
    property int detailImgIndex: 0

    // Pre-calculated Hero Image bounds for zero-overhead per-frame rendering
    property real imgCropW: 0
    property real imgCropH: 0
    property real imgFitW: 0
    property real imgFitH: 0

    function getPreviewUrl(idx) {
        if (!root.detailTheme) return "";
        const plist = root.detailTheme.previews;
        if (plist && plist.length > 0) {
            const i = Math.max(0, Math.min(plist.length - 1, idx));
            const p = plist[i] || "";
            if (p.startsWith("/") && typeof CUtils !== "undefined" && CUtils.fileExists(p)) {
                return "file://" + p;
            }
            return p;
        }
        const p0 = root.detailTheme.preview || "";
        if (p0.startsWith("/") && typeof CUtils !== "undefined" && CUtils.fileExists(p0)) {
            return "file://" + p0;
        }
        return p0;
    }

    function updateHeroImgBounds() {
        const aspect = (detailHeroImg.implicitWidth > 0 && detailHeroImg.implicitHeight > 0)
            ? (detailHeroImg.implicitWidth / detailHeroImg.implicitHeight)
            : (350.0 / 250.0);
        const startW = Math.max(1, detailSourceRect.width - 2 * Tokens.padding.normal);
        const startH = 114;
        imgCropW = Math.max(startW, startH * aspect);
        imgCropH = Math.max(startH, startW / aspect);

        const endW = Math.max(1, detailCard.targetWidth - 2 * Tokens.padding.normal - 8);
        const endH = Math.max(1, root.expandedHeroHeight - 8);
        imgFitW = Math.min(endW, endH * aspect);
        imgFitH = Math.min(endH, endW / aspect);
    }

    function openThemeDetails(theme, cardItem) {
        if (!theme || !cardItem) return;
        collapseAnimation.stop();
        expandAnimation.stop();

        if (typeof heroSlideAnim !== "undefined" && heroSlideAnim.running) heroSlideAnim.stop();
        if (typeof heroCarousel !== "undefined") {
            heroCarousel.activeHeroSlot = 0;
            heroCarousel.slideHeroProgress = 0.0;
        }
        detailImgIndex = 0;

        const pt = cardItem.mapToItem(root, 0, 0);
        detailSourceRect = Qt.rect(pt.x, pt.y, cardItem.width, cardItem.height);

        morphProgress = 0.0;
        expandedExtrasOpacity = 0.0;
        detailElevation.opacity = 0.0;

        detailTheme = theme;
        detailVisible = true;
        updateHeroImgBounds();
        expandAnimation.restart();
    }

    function closeThemeDetails() {
        if (!root.detailVisible || collapseAnimation.running) return;
        expandAnimation.stop();
        if (typeof heroSlideAnim !== "undefined" && heroSlideAnim.running) heroSlideAnim.stop();
        if (typeof heroCarousel !== "undefined") {
            heroCarousel.activeHeroSlot = 0;
            heroCarousel.slideHeroProgress = 0.0;
        }
        detailImgIndex = 0;
        detailElevation.opacity = 0.0;
        collapseAnimation.restart();
    }

    // ── M3 Expressive Tokens (Smooth Bouncy Container Transform) ──
    readonly property int expandDur: 380
    readonly property int collapseDur: 300
    readonly property var spatialEasing: Tokens.anim.expressiveDefaultSpatial
    readonly property var spatialEasingDecel: Tokens.anim.emphasizedDecel
    readonly property var collapseSpatialEasing: Tokens.anim.emphasized

    ParallelAnimation {
        id: expandAnimation
        NumberAnimation {
            target: root
            property: "morphProgress"
            to: 1.0
            duration: root.expandDur
            easing: root.spatialEasing
        }
        NumberAnimation {
            target: root
            property: "expandedExtrasOpacity"
            to: 1.0
            duration: Math.round(root.expandDur * 0.85)
            easing: root.spatialEasingDecel
        }
        NumberAnimation {
            target: detailElevation
            property: "opacity"
            to: 1.0
            duration: root.expandDur
            easing: root.spatialEasingDecel
        }
        onFinished: {
            root.morphProgress = 1.0;
            root.expandedExtrasOpacity = 1.0;
            detailElevation.opacity = 1.0;
        }
    }

    ParallelAnimation {
        id: collapseAnimation
        NumberAnimation {
            target: root
            property: "morphProgress"
            to: 0.0
            duration: root.collapseDur
            easing: root.collapseSpatialEasing
        }
        NumberAnimation {
            target: root
            property: "expandedExtrasOpacity"
            to: 0.0
            duration: Math.round(root.collapseDur * 0.55)
            easing: Tokens.anim.standardDecel
        }
        NumberAnimation {
            target: detailElevation
            property: "opacity"
            to: 0.0
            duration: Math.round(root.collapseDur * 0.4)
            easing: Tokens.anim.standardDecel
        }
        onFinished: {
            root.morphProgress = 0.0;
            root.expandedExtrasOpacity = 0.0;
            root.detailVisible = false;
            root.detailTheme = null;
        }
    }

    Item {
        id: detailOverlay
        anchors.fill: parent
        z: 9998
        visible: root.detailVisible

        Shortcut {
            sequence: "Escape"
            enabled: root.detailVisible && !deleteModal.visible
            onActivated: root.closeThemeDetails()
        }

        // Scrim background covering the full details pane card without border gaps
        Rectangle {
            id: detailScrim
            anchors.fill: parent
            anchors.leftMargin: -Tokens.padding.normal
            anchors.rightMargin: -Tokens.padding.normal
            anchors.topMargin: -Tokens.padding.normal
            anchors.bottomMargin: -Tokens.padding.normal
            radius: Tokens.rounding.large
            color: Colours.palette.m3scrim
            opacity: root.expandedExtrasOpacity * (Colours.light ? 0.42 : 0.62)

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeThemeDetails()
                onWheel: wheel => { wheel.accepted = true; }
            }
        }

        // Morphing Transform Viewport Clipping Boundary (Strictly pinned to scrollViewport ceiling)
        ClippingRectangle {
            id: detailClipBoundary
            x: scrollViewport.x
            y: scrollViewport.y
            width: scrollViewport.width
            height: scrollViewport.height
            radius: Tokens.rounding.large
            color: "transparent"
            clip: true

            // Elevation Shadow Level 4 (Resting only for 60 FPS flight)
            Elevation {
                id: detailElevation
                x: detailCard.x
                y: detailCard.y
                width: detailCard.width
                height: detailCard.height
                radius: detailCard.radius
                level: 4
                opacity: 0.0
                visible: !expandAnimation.running && !collapseAnimation.running && root.detailVisible && opacity > 0.01
            }

            // Morphing Transform Card
            Rectangle {
                id: detailCard

                readonly property real targetWidth: Math.min(scrollViewport.width - 48, 540)
                readonly property real targetHeight: Math.min(scrollViewport.height - 32, 480)
                readonly property real targetX: scrollViewport.x + Math.round((scrollViewport.width - targetWidth) / 2)
                readonly property real targetY: scrollViewport.y + Math.round((scrollViewport.height - targetHeight) / 2)

                readonly property real screenX: root.detailSourceRect.x + (targetX - root.detailSourceRect.x) * root.morphProgress
                readonly property real screenY: root.detailSourceRect.y + (targetY - root.detailSourceRect.y) * root.morphProgress

                x: screenX - detailClipBoundary.x
                y: screenY - detailClipBoundary.y
                width: Math.max(100, root.detailSourceRect.width + (targetWidth - root.detailSourceRect.width) * root.morphProgress)
                height: Math.max(100, root.detailSourceRect.height + (targetHeight - root.detailSourceRect.height) * root.morphProgress)

            radius: Tokens.rounding.large
            color: root.normalCardBg
            border.width: 0
            border.color: "transparent"
            clip: true
            antialiasing: true
            smooth: true

            // Prevent clicks/scrolls inside card from leaking to background grid
            MouseArea {
                anchors.fill: parent
                onWheel: wheel => { wheel.accepted = true; }
            }

            Item {
                id: detailContentArea
                anchors.fill: parent
                anchors.margins: Tokens.padding.normal

                // Top: High-Res Preview Hero (Unified Zooming Thumbnail)
                ClippingRectangle {
                    id: detailHeroContainer
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(60, 114 + (root.expandedHeroHeight - 114) * root.morphProgress)
                    radius: Tokens.rounding.normal

                    readonly property color compactHeroColor: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.5)
                    readonly property color expandedHeroColor: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.85)
                    color: Qt.rgba(
                        compactHeroColor.r + (expandedHeroColor.r - compactHeroColor.r) * root.clampedMorph,
                        compactHeroColor.g + (expandedHeroColor.g - compactHeroColor.g) * root.clampedMorph,
                        compactHeroColor.b + (expandedHeroColor.b - compactHeroColor.b) * root.clampedMorph,
                        compactHeroColor.a + (expandedHeroColor.a - compactHeroColor.a) * root.clampedMorph
                    )
                    antialiasing: true
                    clip: true

                    // Carousel with smooth slide transitions between preview images
                    Item {
                        id: heroCarousel
                        anchors.fill: parent
                        clip: true

                        property int activeHeroSlot: 0
                        property int incomingHeroIndex: 0
                        property int slideHeroDir: 1
                        property real slideHeroProgress: 0.0
                        readonly property real baseHeroX: (width - detailHeroImg.width) / 2

                        Anim {
                            id: heroSlideAnim
                            target: heroCarousel
                            property: "slideHeroProgress"
                            type: Anim.DefaultSpatial
                            duration: 320
                            from: 0.0
                            to: 1.0
                            onFinished: {
                                root.detailImgIndex = heroCarousel.incomingHeroIndex;
                                heroCarousel.activeHeroSlot = (heroCarousel.activeHeroSlot === 0 ? 1 : 0);
                                heroCarousel.slideHeroProgress = 0.0;
                                if (heroCarousel.activeHeroSlot === 0) {
                                    detailHeroImg2.visible = false;
                                    detailHeroImg2.source = "";
                                } else {
                                    detailHeroImg.visible = false;
                                    detailHeroImg.source = "";
                                }
                            }
                        }

                        function transitionToImage(targetIdx, dir) {
                            if (heroSlideAnim.running) {
                                heroSlideAnim.stop();
                                root.detailImgIndex = incomingHeroIndex;
                                activeHeroSlot = (activeHeroSlot === 0 ? 1 : 0);
                                slideHeroProgress = 0.0;
                            }
                            incomingHeroIndex = targetIdx;
                            slideHeroDir = dir;
                            const nextUrl = root.getPreviewUrl(targetIdx);
                            if (activeHeroSlot === 0) {
                                detailHeroImg2.source = nextUrl;
                                detailHeroImg2.visible = true;
                            } else {
                                detailHeroImg.source = nextUrl;
                                detailHeroImg.visible = true;
                            }
                            heroSlideAnim.restart();
                        }

                        // Slot 0 Hero Image
                        Image {
                            id: detailHeroImg
                            y: (parent.height - height) / 2
                            width: root.imgCropW + (root.imgFitW - root.imgCropW) * root.clampedMorph
                            height: root.imgCropH + (root.imgFitH - root.imgCropH) * root.clampedMorph

                            x: heroCarousel.activeHeroSlot === 0
                                ? (heroCarousel.baseHeroX - (heroCarousel.slideHeroDir * heroCarousel.slideHeroProgress * heroCarousel.width))
                                : (heroCarousel.baseHeroX + (heroCarousel.slideHeroDir * (1.0 - heroCarousel.slideHeroProgress) * heroCarousel.width))

                            opacity: heroCarousel.activeHeroSlot === 0
                                ? (1.0 - 0.35 * heroCarousel.slideHeroProgress)
                                : (0.65 + 0.35 * (1.0 - heroCarousel.slideHeroProgress))

                            onStatusChanged: {
                                if (status === Image.Ready) root.updateHeroImgBounds();
                            }

                            source: root.getPreviewUrl(root.detailImgIndex)
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 480
                            sourceSize.height: 320
                            cache: true
                            asynchronous: true
                            smooth: true
                            antialiasing: true
                            mipmap: true
                            visible: status === Image.Ready
                        }

                        // Slot 1 Hero Image (Incoming during slide)
                        Image {
                            id: detailHeroImg2
                            y: (parent.height - height) / 2
                            width: root.imgCropW + (root.imgFitW - root.imgCropW) * root.clampedMorph
                            height: root.imgCropH + (root.imgFitH - root.imgCropH) * root.clampedMorph

                            x: heroCarousel.activeHeroSlot === 1
                                ? (heroCarousel.baseHeroX - (heroCarousel.slideHeroDir * heroCarousel.slideHeroProgress * heroCarousel.width))
                                : (heroCarousel.baseHeroX + (heroCarousel.slideHeroDir * (1.0 - heroCarousel.slideHeroProgress) * heroCarousel.width))

                            opacity: heroCarousel.activeHeroSlot === 1
                                ? (1.0 - 0.35 * heroCarousel.slideHeroProgress)
                                : (0.65 + 0.35 * (1.0 - heroCarousel.slideHeroProgress))

                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 480
                            sourceSize.height: 320
                            cache: true
                            asynchronous: true
                            smooth: true
                            antialiasing: true
                            mipmap: true
                            visible: false
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: (detailHeroImg.status !== Image.Ready) && (detailHeroImg2.status !== Image.Ready)
                            text: "mouse"
                            iconPointSize: 36 + 12 * root.clampedMorph
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    // Left: Previous Image Button (if multiple images)
                    Rectangle {
                        id: prevImgBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 16
                        z: 10
                        visible: root.detailTheme && root.detailTheme.previews && root.detailTheme.previews.length > 1 && (root.expandedExtrasOpacity > 0.01)
                        opacity: root.expandedExtrasOpacity
                        scale: 0.7 + 0.3 * root.clampedMorph
                        color: prevImgMa.pressed ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) :
                               prevImgMa.containsMouse ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 1) :
                               Colours.palette.m3surfaceContainerHighest
                        border.color: prevImgMa.containsMouse ? Colours.palette.m3outline : Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
                        border.width: 1
                        antialiasing: true

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "chevron_left"
                            iconPointSize: 18
                            color: Colours.palette.m3onSurface
                        }

                        MouseArea {
                            id: prevImgMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const len = root.detailTheme.previews.length;
                                const prevIdx = (root.detailImgIndex - 1 + len) % len;
                                heroCarousel.transitionToImage(prevIdx, -1);
                            }
                        }
                    }

                    // Right: Next Image Button (if multiple images)
                    Rectangle {
                        id: nextImgBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 16
                        z: 10
                        visible: root.detailTheme && root.detailTheme.previews && root.detailTheme.previews.length > 1 && (root.expandedExtrasOpacity > 0.01)
                        opacity: root.expandedExtrasOpacity
                        scale: 0.7 + 0.3 * root.clampedMorph
                        color: nextImgMa.pressed ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) :
                               nextImgMa.containsMouse ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 1) :
                               Colours.palette.m3surfaceContainerHighest
                        border.color: nextImgMa.containsMouse ? Colours.palette.m3outline : Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
                        border.width: 1
                        antialiasing: true

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "chevron_right"
                            iconPointSize: 18
                            color: Colours.palette.m3onSurface
                        }

                        MouseArea {
                            id: nextImgMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const len = root.detailTheme.previews.length;
                                const nextIdx = (root.detailImgIndex + 1) % len;
                                heroCarousel.transitionToImage(nextIdx, 1);
                            }
                        }
                    }

                    // Bottom Center: Image Counter Pill (e.g. 1 / 4)
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitHeight: 22
                        implicitWidth: imgCounterText.implicitWidth + 14
                        radius: Tokens.rounding.full
                        z: 10
                        visible: root.detailTheme && root.detailTheme.previews && root.detailTheme.previews.length > 1 && (root.expandedExtrasOpacity > 0.01)
                        opacity: root.expandedExtrasOpacity
                        scale: 0.7 + 0.3 * root.clampedMorph
                        color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.88)
                        border.color: "transparent"
                        border.width: 0
                        antialiasing: true

                        StyledText {
                            id: imgCounterText
                            anchors.centerIn: parent
                            text: {
                                if (!root.detailTheme || !root.detailTheme.previews) return "";
                                const displayIdx = heroSlideAnim.running ? heroCarousel.incomingHeroIndex : root.detailImgIndex;
                                return (displayIdx + 1) + " / " + root.detailTheme.previews.length;
                            }
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.smaller
                            color: Colours.palette.m3onSurface
                        }
                    }

                    // Top Left: Rating Badge (glides smoothly from grid card topMargin 6 to expanded topMargin 10)
                    Rectangle {
                        id: detailRatePill
                        anchors.top: parent.top
                        anchors.topMargin: 6 + 4 * root.clampedMorph
                        anchors.left: parent.left
                        anchors.leftMargin: 6 + 4 * root.clampedMorph
                        visible: root.detailTheme && root.detailTheme.rating > 0
                        implicitHeight: 22 + 4 * root.clampedMorph
                        implicitWidth: detailRateRow.implicitWidth + 12 + 2 * root.clampedMorph
                        radius: Tokens.rounding.full
                        color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.88)
                        border.color: "transparent"
                        border.width: 0
                        antialiasing: true

                        RowLayout {
                            id: detailRateRow
                            anchors.centerIn: parent
                            spacing: 3

                            MaterialIcon {
                                text: "star"
                                iconPointSize: 11 + 2 * root.clampedMorph
                                color: "#f5a623"
                            }

                            StyledText {
                                text: (root.detailTheme ? root.detailTheme.rating : "") + "%"
                                textPointSize: Tokens.font.size.smaller
                                font.weight: Font.DemiBold
                                color: Colours.palette.m3onSurface
                            }
                        }
                    }

                    // Top Right: Downloads Badge (starts at rightMargin 6 matching grid card, smoothly glides left 42px as close button blooms in)
                    Rectangle {
                        id: detailDlPill
                        anchors.top: parent.top
                        anchors.topMargin: 6 + 4 * root.clampedMorph
                        anchors.right: parent.right
                        anchors.rightMargin: 6 + 42 * root.clampedMorph
                        visible: root.detailTheme && root.detailTheme.downloads > 0
                        implicitHeight: 22 + 4 * root.clampedMorph
                        implicitWidth: detailDlRow.implicitWidth + 12 + 2 * root.clampedMorph
                        radius: Tokens.rounding.full
                        color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.88)
                        border.color: "transparent"
                        border.width: 0
                        antialiasing: true

                        RowLayout {
                            id: detailDlRow
                            anchors.centerIn: parent
                            spacing: 3

                            MaterialIcon {
                                text: "download"
                                iconPointSize: 11 + 2 * root.clampedMorph
                                color: Colours.palette.m3primary
                            }

                            StyledText {
                                text: root.detailTheme ? root.formatNumber(root.detailTheme.downloads) : "0"
                                textPointSize: Tokens.font.size.smaller
                                font.weight: Font.DemiBold
                                color: Colours.palette.m3onSurface
                            }
                        }
                    }

                    // Top Right: Close (X) Button (blooms in smoothly at top-right)
                    Rectangle {
                        id: detailTopCloseBtn
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 16
                        z: 11
                        opacity: root.expandedExtrasOpacity
                        scale: 0.5 + 0.5 * root.clampedMorph
                        visible: opacity > 0.01
                        color: detailCloseMa.pressed ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) :
                               detailCloseMa.containsMouse ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 1) :
                               Colours.palette.m3surfaceContainerHighest
                        border.color: detailCloseMa.containsMouse ? Colours.palette.m3outline : Qt.alpha(Colours.palette.m3outlineVariant, 0.5)
                        border.width: 1
                        antialiasing: true

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            iconPointSize: 16
                            color: Colours.palette.m3onSurface
                        }

                        MouseArea {
                            id: detailCloseMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeThemeDetails()
                        }
                    }
                }

                // Middle: Title, Author & Description
                Item {
                    id: detailMiddleArea
                    anchors.top: detailHeroContainer.bottom
                    anchors.topMargin: Tokens.spacing.small
                    anchors.bottom: detailBottomRow.top
                    anchors.bottomMargin: Tokens.spacing.small
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Item {
                        id: detailTitleCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: detailTitleLabel.height * detailTitleLabel.scale + 2 + detailAuthorLabel.height

                        StyledText {
                            id: detailTitleLabel
                            anchors.top: parent.top
                            anchors.left: parent.left
                            width: parent.width / scale
                            text: root.detailTheme ? root.detailTheme.name : ""
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.normal
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            transformOrigin: Item.TopLeft
                            scale: 1.0 + 0.14 * root.clampedMorph
                        }

                        StyledText {
                            id: detailAuthorLabel
                            anchors.top: parent.top
                            anchors.topMargin: detailTitleLabel.height * detailTitleLabel.scale + 2
                            anchors.left: parent.left
                            anchors.right: parent.right
                            text: (root.detailTheme && root.detailTheme.author) ? (qsTr("by ") + root.detailTheme.author) : qsTr("Store")
                            textPointSize: Tokens.font.size.small
                            font.weight: Font.Normal
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    // Description (Scrollable)
                    StyledFlickable {
                        id: detailDescFlickable
                        anchors.top: detailTitleCol.bottom
                        anchors.topMargin: Tokens.spacing.small + (1.0 - root.clampedMorph) * 6
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        opacity: root.expandedExtrasOpacity
                        visible: opacity > 0.01
                        contentWidth: width
                        contentHeight: detailDescText.implicitHeight
                        clip: true

                        StyledText {
                            id: detailDescText
                            width: detailCard.targetWidth - 2 * Tokens.padding.normal
                            text: {
                                if (!root.detailTheme) return "";
                                if (root.detailTheme.description && root.detailTheme.description.trim().length > 0)
                                    return root.detailTheme.description;
                                if (root.detailTheme.summary && root.detailTheme.summary.trim().length > 0)
                                    return root.detailTheme.summary;
                                return qsTr("Preview and download packages directly from the online community archive.");
                            }
                            textPointSize: Tokens.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Bottom: Action Buttons (Direct spatial interpolation, zero RowLayout snapping)
                Item {
                    id: detailBottomRow
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 34 + 4 * root.clampedMorph

                    readonly property bool hasDeleteBtn: detailActionBtn.isInst && !detailActionBtn.isInsting
                    property real deleteBtnProgress: hasDeleteBtn ? 1.0 : 0.0
                    Behavior on deleteBtnProgress { Anim { type: Anim.DefaultSpatial } }

                    readonly property real targetDeleteBtnW: 34 + 4 * root.clampedMorph
                    readonly property real deleteSlotW: deleteBtnProgress * (targetDeleteBtnW + Tokens.spacing.small + 2 * root.clampedMorph)
                    readonly property real compactActionW: Math.max(60, width - deleteSlotW)
                    readonly property real expandedActionW: detailActionBtn.isInsting ? Math.max(168, cursorDetailInstallBaseContent.implicitWidth + 32) : 140
                    property real animatedExpandedActionW: expandedActionW
                    Behavior on animatedExpandedActionW { Anim { type: Anim.DefaultSpatial } }

                    // Close Button (Smoothly expands width from 0 to 88 on left)
                    Rectangle {
                        id: detailCloseBtn
                        x: 0
                        y: 0
                        width: 88 * root.clampedMorph
                        height: parent.height
                        radius: height / 2
                        opacity: root.expandedExtrasOpacity
                        visible: opacity > 0.01 && width > 1
                        clip: true
                        color: detailCancelMa.pressed ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) :
                               detailCancelMa.containsMouse ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 1) :
                               Colours.palette.m3surfaceContainerHighest
                        border.width: 1
                        border.color: detailCancelMa.containsMouse ? Colours.palette.m3outline : Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
                        antialiasing: true

                        StyledText {
                            anchors.centerIn: parent
                            text: qsTr("Close")
                            font.weight: Font.Medium
                            textPointSize: Tokens.font.size.small
                            color: Colours.palette.m3onSurface
                        }

                        MouseArea {
                            id: detailCancelMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeThemeDetails()
                        }
                    }

                    // Install / Installed Button (Morphs smoothly between compact full width at x=0 and expandedActionW on right)
                    ClippingRectangle {
                        id: detailActionBtn
                        width: detailBottomRow.compactActionW + (detailBottomRow.animatedExpandedActionW - detailBottomRow.compactActionW) * root.clampedMorph
                        height: parent.height
                        x: detailBottomRow.width - detailBottomRow.deleteSlotW - width
                        y: 0
                        radius: height / 2
                        antialiasing: true
                        smooth: true
                        clip: true

                        readonly property bool isInst: {
                            if (!root.detailTheme) return false;
                            const override = (root.installedOverrides[root.detailTheme.id] !== undefined)
                                ? root.installedOverrides[root.detailTheme.id]
                                : ((root.detailTheme.installedThemeId && root.installedOverrides[root.detailTheme.installedThemeId] !== undefined)
                                    ? root.installedOverrides[root.detailTheme.installedThemeId]
                                    : ((root.detailTheme.name && root.installedOverrides[root.detailTheme.name] !== undefined)
                                        ? root.installedOverrides[root.detailTheme.name]
                                        : undefined));
                            if (override !== undefined) return Boolean(override);
                            return Boolean(root.detailTheme.isInstalled);
                        }
                        readonly property bool isInsting: root.detailTheme ? Boolean(root.installingThemes[root.detailTheme.id]) : false
                        readonly property int currentProg: root.detailTheme ? (root.installProgress[root.detailTheme.id] || 0) : 0
                        readonly property bool isHov: detailBtnMa.containsMouse

                        color: isInsting
                            ? Qt.alpha(Colours.palette.m3primary, 0.14)
                            : (isInst
                                ? Colours.palette.m3secondaryContainer
                                : (isHov ? Colours.layer(Colours.palette.m3primary, 1) : Colours.palette.m3primary))

                        Behavior on color {
                            enabled: !expandAnimation.running && !collapseAnimation.running && root.detailVisible
                            CAnim {}
                        }

                        // Dynamic Progress Fill (clipped cleanly inside ClippingRectangle)
                        Rectangle {
                            visible: detailActionBtn.isInsting
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, Math.min(detailActionBtn.width, Math.round(detailActionBtn.width * (detailActionBtn.currentProg / 100.0))))
                            radius: height / 2
                            color: Colours.palette.m3primary
                            clip: true
                            z: 2
                            Behavior on width { Anim { type: Anim.StandardLarge } }

                            RowLayout {
                                width: cursorDetailInstallBaseContent.width
                                height: cursorDetailInstallBaseContent.height
                                x: (detailActionBtn.width - width) / 2
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    iconPointSize: 16
                                    color: Colours.palette.m3onPrimary
                                    text: "downloading"
                                }

                                StyledText {
                                    font.weight: Font.Medium
                                    textPointSize: Tokens.font.size.small
                                    color: Colours.palette.m3onPrimary
                                    text: qsTr("Installing... %1%").arg(detailActionBtn.currentProg)
                                }
                            }
                        }

                        // State 1: "Installed" Content (Fades out cleanly without text re-layout)
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small
                            opacity: (detailActionBtn.isInst && !detailActionBtn.isInsting) ? 1.0 : 0.0
                            visible: opacity > 0.01

                            Behavior on opacity { Anim { type: Anim.FastEffects } }

                            MaterialIcon {
                                iconPointSize: 16
                                color: Colours.palette.m3onSecondaryContainer
                                text: "check"
                            }

                            StyledText {
                                font.weight: Font.Medium
                                textPointSize: Tokens.font.size.small
                                color: Colours.palette.m3onSecondaryContainer
                                text: qsTr("Installed")
                            }
                        }

                        // State 2: "Install" Content (Fades in cleanly without text re-layout)
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small
                            opacity: (!detailActionBtn.isInst && !detailActionBtn.isInsting) ? 1.0 : 0.0
                            visible: opacity > 0.01

                            Behavior on opacity { Anim { type: Anim.FastEffects } }

                            MaterialIcon {
                                iconPointSize: 16
                                color: Colours.palette.m3onPrimary
                                text: "download"
                            }

                            StyledText {
                                font.weight: Font.Medium
                                textPointSize: Tokens.font.size.small
                                color: Colours.palette.m3onPrimary
                                text: qsTr("Install")
                            }
                        }

                        // State 3: "Installing... %1%" Content
                        RowLayout {
                            id: cursorDetailInstallBaseContent
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small
                            opacity: detailActionBtn.isInsting ? 1.0 : 0.0
                            visible: opacity > 0.01

                            Behavior on opacity { Anim { type: Anim.FastEffects } }

                            MaterialIcon {
                                iconPointSize: 16
                                color: Colours.palette.m3primary
                                text: "downloading"
                            }

                            StyledText {
                                font.weight: Font.Medium
                                textPointSize: Tokens.font.size.small
                                color: Colours.palette.m3primary
                                text: qsTr("Installing... %1%").arg(detailActionBtn.currentProg)
                            }
                        }

                        MouseArea {
                            id: detailBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !detailActionBtn.isInst && !detailActionBtn.isInsting
                            onClicked: {
                                if (root.detailTheme && !detailActionBtn.isInst) {
                                    root.installPack(root.detailTheme);
                                }
                            }
                        }
                    }

                    // Delete / Uninstall button if installed (Anchored at right edge, matches storeCardDelegate position!)
                    Rectangle {
                        id: detailDeleteBtn
                        visible: width > 0.5 && opacity > 0.01
                        width: detailBottomRow.targetDeleteBtnW * detailBottomRow.deleteBtnProgress
                        height: parent.height
                        x: detailBottomRow.width - width
                        y: 0
                        radius: height / 2
                        opacity: detailBottomRow.deleteBtnProgress
                        clip: true
                        color: detailDelMa.pressed ? Colours.layer(Colours.palette.m3error, 1) :
                               detailDelMa.containsMouse ? Colours.palette.m3error :
                               Qt.alpha(Colours.palette.m3error, 0.14)
                        border.width: 0
                        border.color: "transparent"
                        antialiasing: true

                        Behavior on color { CAnim {} }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "delete"
                            iconPointSize: 16 + 2 * root.clampedMorph
                            color: (detailDelMa.pressed || detailDelMa.containsMouse) ? Colours.palette.m3onError : Colours.palette.m3error
                            Behavior on color { CAnim {} }
                        }

                        MouseArea {
                            id: detailDelMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.detailTheme) {
                                    root.uninstallPack(root.detailTheme);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

    // ══════════════════════════════════════════════════════════════════════
    // DELETE THEME CONFIRMATION MODAL
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: deleteModal
        anchors.fill: parent
        anchors.leftMargin: -Tokens.padding.normal
        anchors.rightMargin: -Tokens.padding.normal
        anchors.topMargin: -Tokens.padding.normal
        anchors.bottomMargin: -Tokens.padding.normal
        z: 9999
        visible: false

        Shortcut {
            sequence: "Escape"
            enabled: deleteModal.visible
            onActivated: {
                if (!root.isDeleting) {
                    deleteModal.visible = false;
                    root.pendingDeleteTheme = null;
                }
            }
        }

        // Scrim background covering the full details pane card without border gaps
        Rectangle {
            anchors.fill: parent
            radius: Tokens.rounding.large
            color: Colours.palette.m3scrim
            opacity: deleteModal.visible ? (Colours.light ? 0.42 : 0.62) : 0.0
            Behavior on opacity { Anim { type: Anim.FastEffects } }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (!root.isDeleting) {
                        deleteModal.visible = false;
                        root.pendingDeleteTheme = null;
                    }
                }
            }
        }

        // Dialog Card
        StyledRect {
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 420)
            implicitHeight: modalCol.implicitHeight + 48
            radius: 28
            color: Colours.light ? Colours._tileSurfaceRgb : Colours.palette.m3surfaceBright
            border.width: 0
            border.color: "transparent"

            ColumnLayout {
                id: modalCol
                anchors.fill: parent
                anchors.topMargin: 24
                anchors.bottomMargin: 24
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Layout.alignment: Qt.AlignVCenter

                    StyledRect {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 22
                        color: Colours.palette.m3errorContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "delete"
                            color: Colours.palette.m3onErrorContainer
                            iconPointSize: 22
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Delete Cursor Theme?")
                            font.weight: Font.SemiBold
                            textPointSize: Tokens.font.size.large
                            color: Colours.palette.m3onSurface
                        }
                    }
                }

                // Target theme pill/chip
                StyledRect {
                    visible: root.pendingDeleteTheme && (root.pendingDeleteTheme.name || "").length > 0
                    Layout.fillWidth: false
                    implicitHeight: 28
                    implicitWidth: Math.min(parent.width, themeChipRow.implicitWidth + 24)
                    radius: 14
                    color: Qt.alpha(Colours.palette.m3primary, 0.14)
                    border.width: 0

                    RowLayout {
                        id: themeChipRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialIcon {
                            iconPointSize: 14
                            text: "mouse"
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            text: root.pendingDeleteTheme ? root.pendingDeleteTheme.name : ""
                            font.weight: Font.Medium
                            textPointSize: Tokens.font.size.small
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.pendingDeleteTheme
                        ? qsTr("Are you sure you want to permanently delete <b>%1</b> from your system? This action cannot be undone.").arg(root.pendingDeleteTheme.name || "")
                        : qsTr("Are you sure you want to permanently delete this cursor theme from your system? This action cannot be undone.")
                    textFormat: Text.StyledText
                    textPointSize: Tokens.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }

                Item { Layout.preferredHeight: 8 }

                // Action Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Item { Layout.fillWidth: true }

                    // Cancel Button
                    StyledRect {
                        implicitWidth: 88
                        implicitHeight: 38
                        radius: 19
                        color: cancelMa.pressed ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) :
                               cancelMa.containsMouse ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 1) :
                               Colours.palette.m3surfaceContainerHighest
                        border.width: 1
                        border.color: cancelMa.containsMouse ? Qt.alpha(Colours.palette.m3outlineVariant, 0.4) : Qt.alpha(Colours.palette.m3outlineVariant, 0.2)

                        StyledText {
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            font.weight: Font.Medium
                            textPointSize: Tokens.font.size.small
                            color: Colours.palette.m3onSurface
                        }

                        MouseArea {
                            id: cancelMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                deleteModal.visible = false;
                                root.pendingDeleteTheme = null;
                            }
                        }
                    }

                    // Confirm Delete Button
                    StyledRect {
                        implicitWidth: 96
                        implicitHeight: 38
                        radius: 19
                        color: confirmDeleteMa.pressed ? Colours.layer(Colours.palette.m3error, 2) :
                               confirmDeleteMa.containsMouse ? Colours.layer(Colours.palette.m3error, 1) :
                               Colours.palette.m3error

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            LoadingIndicator {
                                visible: root.isDeleting
                                implicitSize: 16
                                color: Colours.palette.m3onError
                                animated: root.isDeleting
                            }

                            StyledText {
                                text: root.isDeleting ? qsTr("Deleting…") : qsTr("Delete")
                                font.weight: Font.DemiBold
                                textPointSize: Tokens.font.size.small
                                color: Colours.palette.m3onError
                            }
                        }

                        MouseArea {
                            id: confirmDeleteMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.isDeleting
                            onClicked: root.confirmDeleteTheme()
                        }
                    }
                }
            }
        }
    }
}


