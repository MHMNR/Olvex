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
    }

    ParallelAnimation {
        id: revealAnim
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: yTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutCubic }
    }

    // ── Tab state ──
    property int currentTab: 0 // 0: Installed, 1: Get Online Packs

    // ── Installed Themes Data ──
    property var themesList: []
    property string activeThemeId: ""
    property bool isScanning: false
    property bool isApplying: false

    function getMarketScriptPath() {
        if (typeof CUtils !== "undefined" && typeof CUtils.fileExists === "function") {
            const local = Paths.home + "/.local/Olvex/scripts/src/olvex/utils/icon_market.py";
            if (CUtils.fileExists(local)) return local;
        }
        return Paths.home + "/.local/Olvex/scripts/src/olvex/utils/icon_market.py";
    }

    function getThemesScriptPath() {
        if (typeof CUtils !== "undefined" && typeof CUtils.fileExists === "function") {
            const local = Paths.home + "/.local/Olvex/scripts/src/olvex/utils/icon_themes.py";
            if (CUtils.fileExists(local)) return local;
        }
        return Paths.home + "/.local/Olvex/scripts/src/olvex/utils/icon_themes.py";
    }

    function refreshThemes() {
        if (isScanning) return;
        isScanning = true;
        try {
            scannerProc.command = ["python3", getThemesScriptPath()];
            scannerProc.running = false;
            scannerProc.running = true;
        } catch (e) {
            console.warn("[AppearanceIcons] refreshThemes error:", e);
            isScanning = false;
        }
    }

    function applyTheme(themeId) {
        if (!themeId) return;
        activeThemeId = themeId;
        // Instantly reload icons across the shell without waiting for subprocess
        Icons.reloadIcons(themeId);
        isApplying = true;
        try {
            applyProc.command = ["python3", getThemesScriptPath(), "set", themeId];
            applyProc.running = false;
            applyProc.running = true;
        } catch (e) {
            console.warn("[AppearanceIcons] applyTheme error:", e);
            isApplying = false;
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
                    console.warn("[AppearanceIcons] Failed to parse icon themes:", e);
                }
            }
        }
    }

    function onThemeApplied() {
        if (!root.activeThemeId) return;
        Icons.reloadIcons(root.activeThemeId);
        if (typeof Toaster !== "undefined" && Toaster.toast) {
            Toaster.toast(
                qsTr("Icon Theme Applied"),
                qsTr("Switched icon theme to %1").arg(root.activeThemeId),
                "check_circle"
            );
        }
        root.refreshThemes();
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

    // ── Delete Icon Theme Operations ──
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
        const targetId = pendingDeleteTheme.id;
        deleteModal.visible = false;
        isDeleting = true;
        try {
            deleteProc.command = ["python3", getThemesScriptPath(), "delete", targetId];
            deleteProc.running = false;
            deleteProc.running = true;
        } catch (e) {
            console.warn("[AppearanceIcons] delete error:", e);
            isDeleting = false;
        }
    }

    function onThemeDeleted() {
        const deletedName = pendingDeleteTheme ? (pendingDeleteTheme.name || pendingDeleteTheme.id) : "";
        if (typeof Toaster !== "undefined" && Toaster.toast) {
            Toaster.toast(
                qsTr("Icon Pack Deleted"),
                deletedName ? qsTr("Removed \"%1\"").arg(deletedName) : qsTr("Icon pack removed"),
                "delete"
            );
        }
        if (root.detailTheme && (root.detailTheme.name === deletedName || root.detailTheme.id === deletedName)) {
            root.closeThemeDetails();
        }
        pendingDeleteTheme = null;
        root.refreshThemes();
        root.refreshMarket();
        Icons.reloadIcons();
    }

    Process {
        id: deleteProc
        onExited: (exitCode, exitStatus) => {
            if (root.isDeleting) {
                root.isDeleting = false;
                if (exitCode === 0) {
                    root.onThemeDeleted();
                } else if (typeof Toaster !== "undefined" && Toaster.toast) {
                    Toaster.toast(qsTr("Failed to Delete"), qsTr("Could not delete icon pack"), "error");
                }
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.isDeleting) {
                    root.isDeleting = false;
                    root.onThemeDeleted();
                }
            }
        }
    }

    // ── Online Market Data ──
    property var marketList: []
    property bool marketLoading: false
    property string marketSort: "downloads"
    property string marketSortOrder: "desc" // "desc" or "asc"
    property string marketSearch: ""
    property string installingId: ""
    property int installProgress: 0
    property int marketPage: 0
    property bool marketHasMore: true
    property bool marketAppendMode: false
    property int thumbEpoch: 0
    property int thumbTicksLeft: 0

    function applySorting() {
        if (root.marketList && root.marketList.length > 0) {
            const sorted = root.marketList.slice();
            const order = root.marketSortOrder === "asc" ? 1 : -1;
            if (root.marketSort === "downloads") {
                sorted.sort((a, b) => order * ((a.downloads || 0) - (b.downloads || 0)));
            } else if (root.marketSort === "rating") {
                sorted.sort((a, b) => order * ((a.rating || 0) - (b.rating || 0)));
            } else if (root.marketSort === "new") {
                sorted.sort((a, b) => order * (parseInt(a.id || 0) - parseInt(b.id || 0)));
            }
            root.marketList = sorted;
        }
        root.refreshMarket();
    }

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
            const script = getMarketScriptPath();
            const args = [
                "python3", script, "list",
                "--sort", marketSort,
                "--order", marketSortOrder,
                "--pagesize", "30",
                "--page", String(page)
            ];
            if (marketSearch && marketSearch.trim() !== "") {
                args.push("--search");
                args.push(marketSearch.trim());
            }
            marketProc.command = args;
            marketProc.running = false;
            marketProc.running = true;
        } catch (e) {
            console.warn("[AppearanceIcons] fetchMarket error:", e);
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
                        root.marketHasMore = parsed.items.length >= 10;
                        root.thumbTicksLeft = 18;
                        root.thumbEpoch++;
                    } else {
                        if (!root.marketAppendMode) root.marketList = [];
                        root.marketHasMore = false;
                    }
                } catch(e) {
                    console.warn("[AppearanceIcons] Market parse error:", e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "") {
                    console.warn("[AppearanceIcons] Market stderr:", text);
                }
            }
        }
    }

    function installMarketPack(url, name, id) {
        if (!url || installingId) return;
        installingId = id;
        installProgress = 0;
        try {
            installProc.command = ["python3", getMarketScriptPath(), "install", url, name || ""];
            installProc.running = false;
            installProc.running = true;
        } catch (e) {
            console.warn("[AppearanceIcons] installMarketPack error:", e);
            installingId = "";
            installProgress = 0;
        }
    }

    Process {
        id: installProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.installProgress < 100) {
                root.installingId = "";
                root.installProgress = 0;
            }
        }
        stdout: SplitParser {
            onRead: line => {
                if (!line) return;
                const trimmed = line.trim();
                if (trimmed.startsWith("PROGRESS:")) {
                    const p = parseInt(trimmed.substring(9).trim());
                    if (!isNaN(p)) {
                        root.installProgress = Math.min(100, Math.max(0, p));
                    }
                } else if (trimmed.startsWith("{")) {
                    root.installProgress = 100;
                    try {
                        const res = JSON.parse(trimmed);
                        if (res.success) {
                            if (typeof Toaster !== "undefined" && Toaster.toast) {
                                Toaster.toast(
                                    qsTr("Icon Pack Installed"),
                                    qsTr("Installed %1").arg(res.installedThemes ? res.installedThemes.join(", ") : "icon pack"),
                                    "download_done"
                                );
                            }
                            root.refreshThemes();
                            root.refreshMarket();
                        } else {
                            if (typeof Toaster !== "undefined" && Toaster.toast) {
                                Toaster.toast(
                                    qsTr("Install Failed"),
                                    res.error || qsTr("Failed to install icon pack"),
                                    "error"
                                );
                            }
                        }
                    } catch(e) {
                        console.warn("[AppearanceIcons] Install parse error:", e);
                    }
                    root.installingId = "";
                    root.installProgress = 0;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "") {
                    console.warn("[AppearanceIcons] Install stderr:", text);
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // STATIONARY TOP HEADER (Pinned / Does NOT scroll)
    // ══════════════════════════════════════════════════════════════════════
    ColumnLayout {
        id: headerContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.normal
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
                    radius: Tokens.rounding.normal
                    color: Qt.alpha(Colours.palette.m3primary, 0.12)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "palette"
                        color: Colours.palette.m3primary
                        iconPointSize: 20
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: qsTr("System Icon Theme")
                        font.weight: Font.DemiBold
                        textPointSize: Tokens.font.size.large
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        text: qsTr("Applications, launcher, and desktop icon set")
                        textPointSize: Tokens.font.size.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                // Expanding "Open Folder" button
                StyledRect {
                    id: openFolderBtn
                    readonly property bool hovered: openFolderMa.containsMouse
                    implicitHeight: 38
                    implicitWidth: hovered ? (folderIcon.implicitWidth + folderText.implicitWidth + 28) : 38
                    radius: Tokens.rounding.full
                    color: openFolderMa.pressed ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) :
                           Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                    border.width: 1
                    border.color: hovered ? "transparent" : Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                    clip: true

                    Behavior on implicitWidth { Anim { type: Anim.DefaultSpatial } }
                    Behavior on color { CAnim {} }
                    Behavior on border.color { CAnim {} }

                    MaterialIcon {
                        id: folderIcon
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: openFolderBtn.hovered ? 12 : Math.round((38 - folderIcon.implicitWidth) / 2)
                        text: "folder_open"
                        iconPointSize: 18
                        renderType: Text.QtRendering
                        antialiasing: true
                        color: Colours.palette.m3onSurface

                        Behavior on anchors.leftMargin { Anim { type: Anim.DefaultSpatial } }
                        Behavior on color { CAnim {} }
                    }

                    StyledText {
                        id: folderText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: folderIcon.right
                        anchors.leftMargin: 6
                        text: qsTr("Open Folder")
                        textPointSize: Tokens.font.size.smaller
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurface
                        visible: opacity > 0.01
                        opacity: openFolderBtn.hovered ? 1.0 : 0.0
                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                    }

                    MouseArea {
                        id: openFolderMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["xdg-open", Paths.home + "/.icons"])
                    }
                }

                // Expanding "Scan Themes" (rebuild) button
                StyledRect {
                    id: scanThemesBtn
                    readonly property bool hovered: scanThemesMa.containsMouse
                    implicitHeight: 38
                    implicitWidth: hovered ? (scanIconHost.implicitWidth + scanText.implicitWidth + 28) : 38
                    radius: Tokens.rounding.full
                    color: scanThemesMa.pressed ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) :
                           Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                    border.width: 1
                    border.color: hovered ? "transparent" : Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                    clip: true

                    Behavior on implicitWidth { Anim { type: Anim.DefaultSpatial } }
                    Behavior on color { CAnim {} }
                    Behavior on border.color { CAnim {} }

                    LoadingIndicator {
                        anchors.centerIn: parent
                        implicitSize: 20
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
                        Behavior on color { CAnim {} }
                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                    }

                    StyledText {
                        id: scanText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: scanIconHost.right
                        anchors.leftMargin: 6
                        text: qsTr("Scan Themes")
                        textPointSize: Tokens.font.size.smaller
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurface
                        visible: opacity > 0.01
                        opacity: scanThemesBtn.hovered ? 1.0 : 0.0
                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                    }

                    MouseArea {
                        id: scanThemesMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refreshThemes()
                    }
                }
            }

            // Tab 1: Store Toolbar Row
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
                        { label: qsTr("Newest"), val: "new" }
                    ]
                    currentIndex: root.marketSort === "rating" ? 1 : (root.marketSort === "new" ? 2 : 0)
                    onSelected: i => {
                        const keys = ["downloads", "rating", "new"];
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
                            text: qsTr("Search icon packs…")
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
    // SCROLLABLE BODY (Only cards scroll!)
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
        contentHeight: scrollContent.implicitHeight + Tokens.padding.large

        Item {
            id: scrollContent
            width: contentFlickable.width
            implicitHeight: root.currentTab === 0 ? installedGrid.implicitHeight : marketContentCol.implicitHeight

            // Bento Grid of Installed Themes
        GridLayout {
                id: installedGrid
                width: parent.width
                visible: root.currentTab === 0
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Tokens.spacing.normal
            rowSpacing: Tokens.spacing.normal

            Repeater {
                model: root.themesList

                delegate: Item {
                    id: cardDelegate
                    required property var modelData
                    required property int index

                    readonly property bool isSelected: root.activeThemeId === modelData.id
                    readonly property bool isHovered: installedCardMouse.containsMouse
                    readonly property bool isDeletable: (modelData.isDeletable !== undefined)
                        ? modelData.isDeletable
                        : (!modelData.path.startsWith("/usr") && modelData.id !== "default" && modelData.id !== "hicolor")

                    Layout.fillWidth: true
                    Layout.preferredWidth: Math.max(100, Math.floor((installedGrid.width - installedGrid.columnSpacing * 2) / 3))
                    Layout.maximumWidth: Layout.preferredWidth
                    Layout.preferredHeight: 154
                    implicitHeight: 154

                    StyledRect {
                        id: cardBg
                        anchors.fill: parent
                        radius: Tokens.rounding.large
                        color: cardDelegate.isSelected
                            ? Colours.layer(Colours.palette.m3secondaryContainer, 1)
                            : (cardDelegate.isHovered ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 1) : Colours.layer(Colours.palette.m3surfaceContainerHigh, 1))
                        border.color: cardDelegate.isSelected
                            ? Colours.palette.m3primary
                            : (cardDelegate.isHovered ? Qt.alpha(Colours.palette.m3outlineVariant, 0.45) : Qt.alpha(Colours.palette.m3outlineVariant, 0.20))
                        border.width: cardDelegate.isSelected ? 2 : 1

                        Behavior on color { CAnim { duration: Tokens.anim.durations.small } }
                        Behavior on border.color { CAnim { duration: Tokens.anim.durations.small } }

                        // Top Right Control Row: Delete button (if deletable) + Active check badge
                        RowLayout {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            spacing: 6
                            z: 10

                            // Delete Button (only for user-installed themes)
                            StyledRect {
                                id: deleteThemeBtn
                                visible: cardDelegate.isDeletable
                                opacity: (cardDelegate.isHovered || deleteThemeMa.containsMouse) ? 1.0 : 0.0
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: Tokens.rounding.full
                                color: deleteThemeMa.pressed ? Qt.alpha(Colours.palette.m3error, 0.28) :
                                       deleteThemeMa.containsMouse ? Qt.alpha(Colours.palette.m3error, 0.16) :
                                       Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6)
                                border.width: 0
                                border.color: "transparent"

                                Behavior on opacity { Anim { type: Anim.FastEffects } }
                                Behavior on color { CAnim {} }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    iconPointSize: 14
                                    color: deleteThemeMa.containsMouse ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
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

                            // Active M3 shape badge with M3 checkmark
                            Item {
                                visible: cardDelegate.isSelected
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26

                                MaterialShape {
                                    anchors.fill: parent
                                    shape: MaterialShape.Cookie12Sided
                                    color: Colours.palette.m3primary
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "check"
                                    iconPointSize: 14
                                    color: Colours.palette.m3onPrimary
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.normal
                            spacing: Tokens.spacing.small

                            // Preview pedestal for icons (borderless)
                            StyledRect {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 62
                                radius: Tokens.rounding.small
                                color: cardDelegate.isSelected
                                    ? Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.50)
                                    : Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.40)
                                border.width: 0
                                border.color: "transparent"

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.larger

                                    Repeater {
                                        model: (modelData.previews && modelData.previews.length > 0)
                                            ? modelData.previews.slice(0, 4)
                                             : []

                                        delegate: Image {
                                            required property string modelData
                                            source: modelData.startsWith("/") ? ("file://" + modelData) : modelData
                                            sourceSize.width: 36
                                            sourceSize.height: 36
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            mipmap: true
                                        }
                                    }

                                    MaterialIcon {
                                        visible: !modelData.previews || modelData.previews.length === 0
                                        text: "palette"
                                        iconPointSize: 24
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }
                            }

                            // Info
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.name || modelData.id
                                    font.weight: cardDelegate.isSelected ? Font.DemiBold : Font.Medium
                                    textPointSize: Tokens.font.size.normal
                                    color: cardDelegate.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.comment ? modelData.comment : (modelData.path.startsWith("/usr") ? qsTr("System") : qsTr("User (~/.icons)"))
                                    textPointSize: Tokens.font.size.small
                                    font.weight: Font.Normal
                                    color: cardDelegate.isSelected ? Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.70) : Colours.palette.m3onSurfaceVariant
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

            // TAB 1: Online Icon Pack Market Content
            ColumnLayout {
                id: marketContentCol
                width: parent.width
                visible: root.currentTab === 1
                spacing: Tokens.spacing.normal

                // Loading indicator (Shape-morphing LoadingIndicator from QS Panel)
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
                    text: qsTr("Fetching online icon themes from Store...")
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.normal
                    font.weight: Font.Medium
                }
            }
        }

        // Empty / No results state
        Item {
            visible: !root.marketLoading && root.marketList.length === 0
            Layout.fillWidth: true
            Layout.preferredHeight: 160

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.normal

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "cloud_off"
                    iconPointSize: 44
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No icon packs found. Check your search query or internet connection.")
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.normal
                }

                IconTextButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Retry")
                    icon: "refresh"
                    type: IconTextButton.Filled
                    onClicked: root.refreshMarket()
                }
            }
        }

        // Market Cards Bento Grid
        GridLayout {
            id: marketGrid
            visible: root.marketList.length > 0
            width: parent.width
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Tokens.spacing.normal
            rowSpacing: Tokens.spacing.normal

            Repeater {
                model: root.marketList

                delegate: Item {
                    id: marketCard
                    required property var modelData
                    required property int index

                    readonly property bool isThisInstalling: root.installingId === modelData.id
                    readonly property bool isHovered: marketCardMouse.containsMouse
                    readonly property bool isSelectedForDetail: root.detailTheme && (root.detailTheme.id === modelData.id) && root.detailVisible

                    opacity: isSelectedForDetail ? 0.0 : 1.0

                    Layout.fillWidth: true
                    Layout.preferredWidth: Math.max(100, Math.floor((marketGrid.width - marketGrid.columnSpacing * 2) / 3))
                    Layout.maximumWidth: Layout.preferredWidth
                    Layout.preferredHeight: 236
                    implicitHeight: 236

                    StyledRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.large
                        color: marketCard.isHovered
                            ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
                            : root.normalCardBg

                        border.width: 1
                        border.color: marketCard.isHovered
                            ? Qt.alpha(Colours.palette.m3outline, 0.4)
                            : Qt.alpha(Colours.palette.m3outlineVariant, 0.25)

                        Behavior on color { CAnim {} }
                        Behavior on border.color { CAnim {} }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.normal
                            spacing: Tokens.spacing.small

                            // Top preview banner (Inset Bento Plate)
                            StyledClippingRect {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 114
                                radius: Tokens.rounding.small
                                color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.5)
                                antialiasing: true

                                Image {
                                    id: marketCardImg
                                    anchors.fill: parent
                                    source: {
                                        const _ = root.thumbEpoch;
                                        const p = modelData.preview || "";
                                        if (!p || !p.startsWith("/")) return "";
                                        if (typeof CUtils !== "undefined" && CUtils.fileExists(p)) {
                                            return "file://" + p;
                                        }
                                        return "";
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
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: !modelData.preview || marketCardImg.status !== Image.Ready
                                    text: "palette"
                                    iconPointSize: 32
                                    color: Colours.palette.m3onSurfaceVariant
                                }

                                // Top left: Rating pill
                                StyledRect {
                                    visible: modelData.rating > 0
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: 6
                                    Layout.preferredHeight: 22
                                    implicitHeight: 22
                                    implicitWidth: rateRow.implicitWidth + 12
                                    radius: Tokens.rounding.full
                                    color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.85)
                                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.2)
                                    border.width: 1

                                    RowLayout {
                                        id: rateRow
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

                                // Top right: Downloads pill
                                StyledRect {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    Layout.preferredHeight: 22
                                    implicitHeight: 22
                                    implicitWidth: dlRow.implicitWidth + 12
                                    radius: Tokens.rounding.full
                                    color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.85)
                                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.2)
                                    border.width: 1

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

                            // Card Content
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

                            // Action Row: Dual-mode Install Button & Uninstall Button
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                spacing: 6
                                z: 10

                                StyledClippingRect {
                                    id: actionBtn
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    radius: height / 2
                                    clip: true

                                    readonly property bool isInstalled: modelData.isInstalled
                                    readonly property bool isInstalling: marketCard.isThisInstalling
                                    readonly property bool isHovered: btnMa.containsMouse

                                    color: isInstalling
                                        ? Qt.alpha(Colours.palette.m3primary, 0.14)
                                        : (isInstalled
                                            ? (isHovered ? Colours.layer(Colours.palette.m3secondaryContainer, 2) : Colours.palette.m3secondaryContainer)
                                            : (isHovered ? Colours.layer(Colours.palette.m3primary, 2) : Colours.palette.m3primary))

                                    // 1. Base Layer (visible on unfilled track)
                                    RowLayout {
                                        id: baseContent
                                        anchors.centerIn: parent
                                        spacing: 6
                                        z: 1

                                        MaterialIcon {
                                            iconPointSize: 15
                                            color: actionBtn.isInstalling ? Colours.palette.m3primary : (actionBtn.isInstalled ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onPrimary)
                                            text: {
                                                if (actionBtn.isInstalling) return "downloading";
                                                if (actionBtn.isInstalled) return "check";
                                                return "download";
                                            }
                                            Behavior on color { CAnim {} }
                                        }

                                        StyledText {
                                            font.weight: Font.DemiBold
                                            textPointSize: Tokens.font.size.normal
                                            color: actionBtn.isInstalling ? Colours.palette.m3primary : (actionBtn.isInstalled ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onPrimary)
                                            text: {
                                                if (actionBtn.isInstalling) {
                                                    return qsTr("Installing... %1%").arg(root.installProgress);
                                                }
                                                if (actionBtn.isInstalled) return qsTr("Installed");
                                                return qsTr("Install");
                                            }
                                            Behavior on color { CAnim {} }
                                        }
                                    }

                                    // 2. Dynamic Progress Fill (clipped) with StandardLarge CPU meter behavior
                                    Rectangle {
                                        id: progressFill
                                        visible: actionBtn.isInstalling
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: Math.max(0, Math.min(actionBtn.width, Math.round(actionBtn.width * (root.installProgress / 100))))
                                        radius: actionBtn.radius
                                        color: Colours.palette.m3primary
                                        z: 2
                                        clip: true

                                        Behavior on width {
                                            Anim {
                                                type: Anim.StandardLarge
                                            }
                                        }

                                        // 3. Inverted content layer inside the fill (high contrast onPrimary)
                                        RowLayout {
                                            width: baseContent.width
                                            height: baseContent.height
                                            x: (actionBtn.width - width) / 2
                                            y: (actionBtn.height - height) / 2
                                            spacing: 6

                                            MaterialIcon {
                                                iconPointSize: 15
                                                color: Colours.palette.m3onPrimary
                                                text: "downloading"
                                            }

                                            StyledText {
                                                font.weight: Font.DemiBold
                                                textPointSize: Tokens.font.size.normal
                                                color: Colours.palette.m3onPrimary
                                                text: qsTr("Installing... %1%").arg(root.installProgress)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: btnMa
                                        anchors.fill: parent
                                        hoverEnabled: !actionBtn.isInstalling
                                        cursorShape: actionBtn.isInstalling ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        enabled: !actionBtn.isInstalling && (modelData.downloadUrl || modelData.isInstalled)
                                        onPressed: (mouse) => { mouse.accepted = true; }
                                        onClicked: (mouse) => {
                                            mouse.accepted = true;
                                            if (actionBtn.isInstalled) {
                                                root.currentTab = 0;
                                            } else {
                                                root.installMarketPack(modelData.downloadUrl, modelData.downloadName, modelData.id);
                                            }
                                        }
                                    }
                                }

                                // Uninstall Button (visible when installed)
                                StyledRect {
                                    id: marketUninstallBtn
                                    visible: actionBtn.isInstalled && !actionBtn.isInstalling
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: Tokens.rounding.full
                                    color: marketUninstallMa.pressed ? Qt.alpha(Colours.palette.m3error, 0.28) :
                                           marketUninstallMa.containsMouse ? Qt.alpha(Colours.palette.m3error, 0.16) :
                                           Colours.palette.m3surfaceContainerHighest
                                    border.width: 0
                                    border.color: "transparent"

                                    Behavior on color { CAnim { duration: Tokens.anim.durations.small } }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "delete"
                                        iconPointSize: 16
                                        color: marketUninstallMa.containsMouse ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                                        Behavior on color { CAnim {} }
                                    }

                                    MouseArea {
                                        id: marketUninstallMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPressed: (mouse) => { mouse.accepted = true; }
                                        onClicked: (mouse) => {
                                            mouse.accepted = true;
                                            const thId = modelData.installedThemeId || modelData.name;
                                            root.promptDeleteTheme({
                                                id: thId,
                                                name: modelData.name,
                                                path: ""
                                            });
                                        }
                                    }
                                }
                            }
                            }

                        MouseArea {
                            id: marketCardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 0
                            onClicked: root.openThemeDetails(modelData, marketCard)
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
                        text: qsTr("Loading more icon packs...")
                        color: Colours.palette.m3onSurfaceVariant
                        textPointSize: Tokens.font.size.normal
                    }
                }

                StyledText {
                    visible: !root.marketLoading && !root.marketHasMore
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("All %1 icon packs loaded").arg(root.marketList.length)
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.smaller
                }
            }
        }
            }
        }
    }
    }


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

    function openThemeDetails(theme, cardItem) {
        if (!theme || !cardItem) return;
        collapseAnimation.stop();
        expandAnimation.stop();

        detailImgIndex = 0;

        const pt = cardItem.mapToItem(root, 0, 0);
        detailSourceRect = Qt.rect(pt.x, pt.y, cardItem.width, cardItem.height);

        morphProgress = 0.0;
        expandedExtrasOpacity = 0.0;
        detailElevation.opacity = 0.0;

        detailTheme = theme;
        detailVisible = true;
        expandAnimation.restart();
    }

    function closeThemeDetails() {
        if (!root.detailVisible || collapseAnimation.running) return;
        expandAnimation.stop();
        detailImgIndex = 0;
        detailElevation.opacity = 0.0;
        collapseAnimation.restart();
    }

    // ── M3 Expressive Tokens (Smooth Bouncy Container Transform) ──
    readonly property int expandDur: 420
    readonly property int collapseDur: 360
    readonly property var spatialEasing: Tokens.anim.legacyMorphSpatial
    readonly property var spatialEasingDecel: Tokens.anim.emphasizedDecel

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
            duration: root.expandDur
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
            easing: root.spatialEasing
        }
        NumberAnimation {
            target: root
            property: "expandedExtrasOpacity"
            to: 0.0
            duration: Math.round(root.collapseDur * 0.72)
            easing: Tokens.anim.standardDecel
        }
        NumberAnimation {
            target: detailElevation
            property: "opacity"
            to: 0.0
            duration: Math.round(root.collapseDur * 0.45)
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
            color: Colours.palette.m3scrim ? Qt.alpha(Colours.palette.m3scrim, 0.65) : Qt.alpha("#000000", 0.65)
            opacity: root.expandedExtrasOpacity

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeThemeDetails()
                onWheel: wheel => { wheel.accepted = true; }
            }
        }

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
        StyledRect {
            id: detailCard

            readonly property real targetWidth: Math.min(detailOverlay.width - 48, 540)
            readonly property real targetHeight: Math.min(detailOverlay.height - 48, 510)
            readonly property real targetX: Math.round((detailOverlay.width - targetWidth) / 2)
            readonly property real targetY: Math.round((detailOverlay.height - targetHeight) / 2)

            x: root.detailSourceRect.x + (targetX - root.detailSourceRect.x) * root.morphProgress
            y: root.detailSourceRect.y + (targetY - root.detailSourceRect.y) * root.morphProgress
            width: Math.max(100, root.detailSourceRect.width + (targetWidth - root.detailSourceRect.width) * root.morphProgress)
            height: Math.max(100, root.detailSourceRect.height + (targetHeight - root.detailSourceRect.height) * root.morphProgress)

            radius: Tokens.rounding.large
            color: root.normalCardBg
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.25 + 0.05 * root.clampedMorph)
            clip: true

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
                StyledClippingRect {
                    id: detailHeroContainer
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(60, 114 + (root.expandedHeroHeight - 114) * root.morphProgress)
                    radius: Tokens.rounding.small + (Tokens.rounding.normal - Tokens.rounding.small) * root.clampedMorph

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

                    // Unified Image: smoothly zooms from PreserveAspectCrop (t=0) to PreserveAspectFit (t=1)
                    Image {
                        id: detailHeroImg
                        anchors.centerIn: parent

                        readonly property real containerW: Math.max(1, detailHeroContainer.width)
                        readonly property real containerH: Math.max(1, detailHeroContainer.height)
                        readonly property real imgAspect: (implicitWidth > 0 && implicitHeight > 0)
                            ? (implicitWidth / implicitHeight)
                            : (350.0 / 250.0)

                        readonly property real cropW: Math.max(containerW, containerH * imgAspect)
                        readonly property real cropH: Math.max(containerH, containerW / imgAspect)

                        readonly property real fitAvailW: Math.max(1, containerW - 8)
                        readonly property real fitAvailH: Math.max(1, containerH - 8)
                        readonly property real fitW: Math.min(fitAvailW, fitAvailH * imgAspect)
                        readonly property real fitH: Math.min(fitAvailH, fitAvailW / imgAspect)

                        width: cropW + (fitW - cropW) * root.clampedMorph
                        height: cropH + (fitH - cropH) * root.clampedMorph

                        source: {
                            if (!root.detailTheme) return "";
                            const plist = root.detailTheme.previews;
                            if (plist && plist.length > 0) {
                                const idx = Math.max(0, Math.min(plist.length - 1, root.detailImgIndex));
                                const p = plist[idx] || "";
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

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: detailHeroImg.status !== Image.Ready
                        text: "palette"
                        iconPointSize: 32 + 16 * root.clampedMorph
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    // Left: Previous Image Button (if multiple images)
                    StyledRect {
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
                                root.detailImgIndex = (root.detailImgIndex - 1 + len) % len;
                            }
                        }
                    }

                    // Right: Next Image Button (if multiple images)
                    StyledRect {
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
                                root.detailImgIndex = (root.detailImgIndex + 1) % len;
                            }
                        }
                    }

                    // Bottom Center: Image Counter Pill (e.g. 1 / 4)
                    StyledRect {
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
                        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.25)
                        border.width: 1

                        StyledText {
                            id: imgCounterText
                            anchors.centerIn: parent
                            text: {
                                if (!root.detailTheme || !root.detailTheme.previews) return "";
                                return (root.detailImgIndex + 1) + " / " + root.detailTheme.previews.length;
                            }
                            textPointSize: Tokens.font.size.smaller
                            font.weight: Font.DemiBold
                            color: Colours.palette.m3onSurface
                        }
                    }

                    // Top Left: Rating Badge (glides smoothly from grid card topMargin 6 to expanded topMargin 10)
                    StyledRect {
                        id: detailRatePill
                        anchors.top: parent.top
                        anchors.topMargin: 6 + 4 * root.clampedMorph
                        anchors.left: parent.left
                        anchors.leftMargin: 6 + 4 * root.clampedMorph
                        visible: root.detailTheme && root.detailTheme.rating > 0
                        implicitHeight: 22 + 4 * root.clampedMorph
                        implicitWidth: detailRateRow.implicitWidth + 12 + 2 * root.clampedMorph
                        radius: Tokens.rounding.full
                        color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.85 + 0.03 * root.clampedMorph)
                        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.2 + 0.05 * root.clampedMorph)
                        border.width: 1

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
                    StyledRect {
                        id: detailDlPill
                        anchors.top: parent.top
                        anchors.topMargin: 6 + 4 * root.clampedMorph
                        anchors.right: parent.right
                        anchors.rightMargin: 6 + 42 * root.clampedMorph
                        visible: root.detailTheme !== null
                        implicitHeight: 22 + 4 * root.clampedMorph
                        implicitWidth: detailDlRow.implicitWidth + 12 + 2 * root.clampedMorph
                        radius: Tokens.rounding.full
                        color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.85 + 0.03 * root.clampedMorph)
                        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.2 + 0.05 * root.clampedMorph)
                        border.width: 1

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
                    StyledRect {
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
                    clip: true

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
                            width: parent.width
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

                    readonly property bool hasDeleteBtn: root.detailTheme ? (Boolean(root.detailTheme.isInstalled) && !detailActionBtn.isInsting) : false
                    readonly property real deleteSlotW: hasDeleteBtn ? (detailDeleteBtn.width + 6 + 2 * root.clampedMorph) : 0
                    readonly property real compactActionW: Math.max(60, width - deleteSlotW)
                    readonly property real expandedActionW: 140

                    // Close Button (Smoothly expands width from 0 to 88 on left)
                    StyledRect {
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

                    // Install / Installed Button (Morphs smoothly between compact full width at x=0 and 140px on right)
                    StyledClippingRect {
                        id: detailActionBtn
                        width: detailBottomRow.compactActionW + (detailBottomRow.expandedActionW - detailBottomRow.compactActionW) * root.clampedMorph
                        height: parent.height
                        x: detailBottomRow.width - detailBottomRow.deleteSlotW - width
                        y: 0
                        radius: height / 2
                        clip: true

                        readonly property bool isInst: root.detailTheme ? Boolean(root.detailTheme.isInstalled) : false
                        readonly property bool isInsting: root.detailTheme ? (root.installingId === root.detailTheme.id) : false
                        readonly property bool isHov: detailBtnMa.containsMouse

                        color: isInsting
                            ? Qt.alpha(Colours.palette.m3primary, 0.14)
                            : (isInst
                                ? (isHov ? Colours.layer(Colours.palette.m3secondaryContainer, 2) : Colours.palette.m3secondaryContainer)
                                : (isHov ? Colours.layer(Colours.palette.m3primary, 2) : Colours.palette.m3primary))

                        // Base Content
                        RowLayout {
                            id: detailActionBaseContent
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIcon {
                                iconPointSize: 15
                                color: detailActionBtn.isInsting ? Colours.palette.m3primary : (detailActionBtn.isInst ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onPrimary)
                                text: detailActionBtn.isInsting ? "downloading" : (detailActionBtn.isInst ? "check" : "download")
                                Behavior on color { CAnim {} }
                            }

                            StyledText {
                                font.weight: Font.DemiBold
                                textPointSize: Tokens.font.size.normal
                                color: detailActionBtn.isInsting ? Colours.palette.m3primary : (detailActionBtn.isInst ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onPrimary)
                                text: {
                                    if (detailActionBtn.isInsting) {
                                        return qsTr("Installing... %1%").arg(root.installProgress);
                                    }
                                    if (detailActionBtn.isInst) return qsTr("Installed");
                                    return qsTr("Install");
                                }
                                Behavior on color { CAnim {} }
                            }
                        }

                        // Dynamic Progress Fill
                        Rectangle {
                            visible: detailActionBtn.isInsting
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, Math.min(detailActionBtn.width, Math.round(detailActionBtn.width * (root.installProgress / 100))))
                            radius: detailActionBtn.radius
                            color: Colours.palette.m3primary
                            z: 2
                            clip: true

                            Behavior on width { Anim { type: Anim.StandardLarge } }

                            RowLayout {
                                width: detailActionBaseContent.width
                                height: detailActionBaseContent.height
                                x: (detailActionBtn.width - width) / 2
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                MaterialIcon {
                                    iconPointSize: 15
                                    color: Colours.palette.m3onPrimary
                                    text: "downloading"
                                }

                                StyledText {
                                    font.weight: Font.DemiBold
                                    textPointSize: Tokens.font.size.normal
                                    color: Colours.palette.m3onPrimary
                                    text: qsTr("Installing... %1%").arg(root.installProgress)
                                }
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
                                    root.installMarketPack(root.detailTheme.downloadUrl, root.detailTheme.downloadName, root.detailTheme.id);
                                }
                            }
                        }
                    }

                    // Delete / Uninstall button if installed (Anchored at right edge, matches marketCard position!)
                    StyledRect {
                        id: detailDeleteBtn
                        visible: detailBottomRow.hasDeleteBtn
                        width: 34 + 4 * root.clampedMorph
                        height: parent.height
                        x: detailBottomRow.width - width
                        y: 0
                        radius: height / 2
                        color: detailDelMa.pressed ? Qt.alpha(Colours.palette.m3error, 0.28) :
                               detailDelMa.containsMouse ? Qt.alpha(Colours.palette.m3error, 0.16) :
                               Colours.palette.m3surfaceContainerHighest

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "delete"
                            iconPointSize: 16 + 2 * root.clampedMorph
                            color: detailDelMa.containsMouse ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        }

                        MouseArea {
                            id: detailDelMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.detailTheme) {
                                    const thId = root.detailTheme.installedThemeId || root.detailTheme.name;
                                    root.promptDeleteTheme({
                                        id: thId,
                                        name: root.detailTheme.name,
                                        path: ""
                                    });
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── M3 Confirmation Modal for Deleting Icon Pack ──
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
                deleteModal.visible = false;
                root.pendingDeleteTheme = null;
            }
        }

        // Scrim background covering the full details pane card without border gaps
        Rectangle {
            anchors.fill: parent
            radius: Tokens.rounding.large
            color: Colours.palette.m3scrim ? Qt.alpha(Colours.palette.m3scrim, 0.60) : Qt.alpha("#000000", 0.60)
            opacity: deleteModal.visible ? 1.0 : 0.0
            Behavior on opacity { Anim { type: Anim.FastEffects } }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    deleteModal.visible = false;
                    root.pendingDeleteTheme = null;
                }
            }
        }

        // Dialog Card
        StyledRect {
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 420)
            implicitHeight: modalCol.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.large
            color: root.normalCardBg
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)

            ColumnLayout {
                id: modalCol
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.normal

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.normal

                    StyledRect {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: Qt.alpha(Colours.palette.m3error, 0.15)

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "delete"
                            color: Colours.palette.m3error
                            iconPointSize: 20
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: qsTr("Delete Icon Pack?")
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.large
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            text: root.pendingDeleteTheme ? (root.pendingDeleteTheme.name || root.pendingDeleteTheme.id) : ""
                            textPointSize: Tokens.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Are you sure you want to permanently delete this icon pack from your system? This action cannot be undone.")
                    textPointSize: Tokens.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                }

                Item { Layout.preferredHeight: Tokens.spacing.small }

                // Action Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.normal

                    Item { Layout.fillWidth: true }

                    // Cancel Button
                    StyledRect {
                        implicitWidth: 88
                        implicitHeight: 36
                        radius: 18
                        color: cancelMa.pressed ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) :
                               cancelMa.containsMouse ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 1) :
                               "transparent"
                        border.width: 1
                        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.5)

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
                        implicitHeight: 36
                        radius: 18
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