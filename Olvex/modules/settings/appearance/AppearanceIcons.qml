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

            Section {
                id: installedSection
                anchors.fill: parent
                visible: root.currentTab === 0
            Layout.fillWidth: true
            title: qsTr("System Icon Theme")
            description: qsTr("Applications, launcher, and desktop icon set")
            icon: "palette"
            headerControl: RowLayout {
                spacing: Tokens.spacing.small

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

                    Item {
                        id: scanIconHost
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: scanThemesBtn.hovered ? 12 : Math.round((38 - scanIconHost.implicitWidth) / 2)
                        implicitWidth: scanIcon.implicitWidth
                        implicitHeight: scanIcon.implicitHeight
                        width: implicitWidth
                        height: implicitHeight
                        transformOrigin: Item.Center
                        rotation: 0

                        Behavior on anchors.leftMargin { Anim { type: Anim.DefaultSpatial } }

                        MaterialIcon {
                            id: scanIcon
                            anchors.centerIn: parent
                            text: "refresh"
                            iconPointSize: 18
                            renderType: Text.QtRendering
                            antialiasing: true
                            color: Colours.palette.m3onSurface
                            Behavior on color { CAnim {} }
                        }

                        RotationAnimation on rotation {
                            running: root.isScanning
                            from: 0; to: 360; duration: 800; loops: Animation.Infinite
                        }

                        Connections {
                            target: root
                            function onIsScanningChanged() {
                                if (!root.isScanning)
                                    scanIconHost.rotation = 0;
                            }
                        }
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
        }

            // ── Toolbar: Sort Segmented + Expandable Search Pill (Icon => Bar) + Refresh ──
        RowLayout {
                id: marketToolbarRow
                anchors.fill: parent
                visible: root.currentTab === 1
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            // Sort by label
            StyledText {
                text: qsTr("Sort by:")
                color: Colours.palette.m3onSurfaceVariant
                font.weight: Font.Medium
                textPointSize: Tokens.font.size.normal
            }

            // Sort Filter OptionPicker
            OptionPicker {
                id: sortPicker
                Layout.alignment: Qt.AlignVCenter
                model: [
                    { label: qsTr("Downloads"), value: "downloads" },
                    { label: qsTr("Rating"), value: "rating" },
                    { label: qsTr("Newest"), value: "new" }
                ]
                currentIndex: root.marketSort === "rating" ? 1 : (root.marketSort === "new" ? 2 : 0)
                onSelected: i => {
                    root.marketSort = sortPicker.model[i].value;
                    root.applySorting();
                }
            }

            // Ascending / Descending Direction Toggle
            IconButton {
                icon: root.marketSortOrder === "asc" ? "arrow_upward" : "arrow_downward"
                type: IconButton.Tonal
                onClicked: {
                    root.marketSortOrder = (root.marketSortOrder === "asc") ? "desc" : "asc";
                    root.applySorting();
                }
            }

            Item { Layout.fillWidth: true }

            // ── Expandable Search Pill (Circle 40px → 290px input field, border.width: 0) ──
            StyledRect {
                id: searchPill

                property bool searchExpanded: false
                readonly property bool searchActive: searchExpanded || (marketSearchInput && (marketSearchInput.text.length > 0 || marketSearchInput.activeFocus))

                implicitWidth: searchActive ? 290 : 40
                implicitHeight: 40
                radius: Tokens.rounding.full
                clip: true

                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                border.width: 0
                border.color: "transparent"

                Behavior on implicitWidth { Anim { type: Anim.DefaultSpatial } }
                Behavior on color { CAnim {} }

                HoverHandler {
                    id: searchHover
                    cursorShape: searchPill.searchActive ? Qt.IBeamCursor : Qt.PointingHandCursor
                }

                // Collapsed Click-to-Expand Trigger
                MouseArea {
                    anchors.fill: parent
                    visible: !searchPill.searchActive
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        searchPill.searchExpanded = true;
                        Qt.callLater(() => marketSearchInput.forceActiveFocus());
                    }
                }

                // Single Persistent Search Icon
                MaterialIcon {
                    id: searchIcon
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: searchPill.searchActive ? 12 : Math.round((40 - searchIcon.implicitWidth) / 2)
                    text: "search"
                    fill: 1
                    iconPointSize: Tokens.font.size.normal
                    color: marketSearchInput.activeFocus ? Colours.palette.m3primary : (searchPill.searchActive ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface)

                    Behavior on anchors.leftMargin { Anim { type: Anim.DefaultSpatial } }
                    Behavior on color { CAnim {} }
                }

                // Text Input & Placeholder Holder
                Item {
                    id: inputHolder
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 8
                    anchors.right: clearBtn.left
                    anchors.rightMargin: 4
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    clip: true
                    opacity: searchPill.searchActive ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity { Anim { type: Anim.FastEffects } }

                    TextInput {
                        id: marketSearchInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: Colours.palette.m3onSurface
                        selectionColor: Qt.alpha(Colours.palette.m3primary, 0.3)
                        selectedTextColor: Colours.palette.m3onSurface
                        font.family: Tokens.font.family.sans
                        font.pixelSize: Math.max(12, Math.round(Tokens.font.size.normal * 96 / 72))
                        selectByMouse: true
                        cursorVisible: activeFocus
                        text: root.marketSearch

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

                        cursorDelegate: Rectangle {
                            width: 2
                            height: marketSearchInput.font.pixelSize * 1.2
                            radius: 1
                            color: Colours.palette.m3primary
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: marketSearchInput.activeFocus
                                NumberAnimation { to: 1.0; duration: 80 }
                                PauseAnimation   { duration: 520 }
                                NumberAnimation { to: 0.0; duration: 80 }
                                PauseAnimation   { duration: 380 }
                            }
                        }
                    }

                    StyledText {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: qsTr("Search icon packs…")
                        color: Colours.palette.m3outline
                        font.family: Tokens.font.family.sans
                        font.pixelSize: Math.max(12, Math.round(Tokens.font.size.normal * 96 / 72))
                        visible: marketSearchInput.text.length === 0 && !marketSearchInput.inputMethodComposing
                        opacity: marketSearchInput.text.length === 0 ? 0.75 : 0
                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                    }
                }

                // Clear / Close Button
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

            // Expanding "Refresh" Button
            StyledRect {
                id: refreshMarketBtn
                readonly property bool hovered: refreshMarketMa.containsMouse
                implicitHeight: 38
                implicitWidth: hovered ? (marketRotHost.implicitWidth + refreshText.implicitWidth + 28) : 38
                radius: Tokens.rounding.full
                color: refreshMarketMa.pressed ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) :
                       Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                border.width: 1
                border.color: hovered ? "transparent" : Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                clip: true

                Behavior on implicitWidth { Anim { type: Anim.DefaultSpatial } }
                Behavior on color { CAnim {} }
                Behavior on border.color { CAnim {} }

                Item {
                    id: marketRotHost
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: refreshMarketBtn.hovered ? 12 : Math.round((38 - marketRotHost.implicitWidth) / 2)
                    implicitWidth: refreshIcon.implicitWidth
                    implicitHeight: refreshIcon.implicitHeight
                    width: implicitWidth
                    height: implicitHeight
                    transformOrigin: Item.Center
                    rotation: 0

                    Behavior on anchors.leftMargin { Anim { type: Anim.DefaultSpatial } }

                    MaterialIcon {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: "refresh"
                        iconPointSize: 18
                        renderType: Text.QtRendering
                        antialiasing: true
                        color: Colours.palette.m3onSurface
                        Behavior on color { CAnim {} }
                    }

                    RotationAnimation on rotation {
                        id: marketSpinAnim
                        running: root.marketLoading
                        from: 0; to: 360; duration: 800; loops: Animation.Infinite
                    }

                    Connections {
                        target: root
                        function onMarketLoadingChanged() {
                            if (!root.marketLoading)
                                marketRotHost.rotation = 0;
                        }
                    }
                }

                StyledText {
                    id: refreshText
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: marketRotHost.right
                    anchors.leftMargin: 6
                    text: qsTr("Refresh")
                    textPointSize: Tokens.font.size.smaller
                    font.weight: Font.Medium
                    color: Colours.palette.m3onSurface
                    visible: opacity > 0.01
                    opacity: refreshMarketBtn.hovered ? 1.0 : 0.0
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                }

                MouseArea {
                    id: refreshMarketMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        marketSpinAnim.restart();
                        root.refreshMarket();
                    }
                }
            }
        }
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
                                    font.weight: cardDelegate.isSelected ? Font.SemiBold : Font.Medium
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
            visible: root.marketList.length > 0
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

                    Layout.fillWidth: true
                    Layout.preferredHeight: 244
                    implicitHeight: 244

                    StyledRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.large
                        color: Colours.palette.m3surfaceContainerLow
                        border.color: marketCard.isHovered ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.25)
                        border.width: 1

                        Behavior on border.color { CAnim { duration: Tokens.anim.durations.small } }

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
                                    sourceSize.width: 320
                                    sourceSize.height: 160
                                    cache: true
                                    asynchronous: true
                                    smooth: true
                                    antialiasing: true
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
                                Layout.fillHeight: true
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

                                Item { Layout.fillHeight: true }

                                // Action Row: Dual-mode Install Button & Uninstall Button
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    spacing: 6

                                    StyledRect {
                                        id: actionBtn
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 34
                                        radius: Tokens.rounding.full
                                        clip: true

                                        readonly property bool isInstalled: modelData.isInstalled
                                        readonly property bool isInstalling: marketCard.isThisInstalling
                                        readonly property bool isHovered: btnMa.containsMouse

                                        color: isInstalling
                                            ? Qt.alpha(Colours.palette.m3primary, 0.14)
                                            : (isInstalled
                                                ? (isHovered ? Colours.layer(Colours.palette.m3secondaryContainer, 2) : Colours.palette.m3secondaryContainer)
                                                : (isHovered ? Colours.layer(Colours.palette.m3primary, 2) : Colours.palette.m3primary))

                                        Behavior on color { CAnim { duration: Tokens.anim.durations.small } }

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
                                                font.weight: Font.SemiBold
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
                                        StyledClippingRect {
                                            id: progressFill
                                            visible: actionBtn.isInstalling
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: Math.max(0, Math.min(actionBtn.width, Math.round(actionBtn.width * (root.installProgress / 100))))
                                            radius: Tokens.rounding.full
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
                                                    font.weight: Font.SemiBold
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
                                            onClicked: {
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
                                            onClicked: {
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
                        }

                        MouseArea {
                            id: marketCardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
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

        // M3 Elevation Shadow Level 4
        Elevation {
            x: dialogCard.x
            y: dialogCard.y
            width: dialogCard.width
            height: dialogCard.height
            radius: dialogCard.radius
            level: 4
            scale: dialogCard.scale
            opacity: dialogCard.opacity
            z: 1

            Behavior on scale { Anim { type: Anim.DefaultSpatial } }
            Behavior on opacity { Anim { type: Anim.FastEffects } }
        }

        // Dialog Card (100% opaque, zero alpha/transparency)
        StyledRect {
            id: dialogCard
            anchors.centerIn: parent
            implicitWidth: Math.min(parent.width - 48, 410)
            implicitHeight: dialogCol.implicitHeight + (Tokens.padding.large * 2)
            radius: (Tokens.rounding && Tokens.rounding.large) ? Tokens.rounding.large : 24
            color: Qt.rgba(Colours.palette.m3surfaceContainerHigh.r, Colours.palette.m3surfaceContainerHigh.g, Colours.palette.m3surfaceContainerHigh.b, 1.0)
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.22)
            scale: deleteModal.visible ? 1.0 : 0.94
            opacity: deleteModal.visible ? 1.0 : 0.0
            z: 2
            clip: true

            Behavior on scale { Anim { type: Anim.DefaultSpatial } }
            Behavior on opacity { Anim { type: Anim.FastEffects } }

            // Prevent clicks inside card from closing modal
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: dialogCol
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.normal

                // Top Icon: M3 Expressive Warning/Delete icon container
                StyledRect {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 52
                    implicitHeight: 52
                    radius: Tokens.rounding.full
                    color: Qt.alpha(Colours.palette.m3error, 0.14)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "delete"
                        iconPointSize: 24
                        color: Colours.palette.m3error
                    }
                }

                // Title
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Delete Icon Pack?")
                    font.weight: Font.SemiBold
                    textPointSize: Tokens.font.size.large
                    color: Colours.palette.m3onSurface
                }

                // Theme Name Chip
                StyledRect {
                    visible: root.pendingDeleteTheme !== null
                    Layout.alignment: Qt.AlignHCenter
                    implicitHeight: 32
                    implicitWidth: Math.min(dialogCard.width - 48, themeChipRow.implicitWidth + 24)
                    radius: Tokens.rounding.full
                    color: Qt.rgba(Colours.palette.m3surfaceContainerHighest.r, Colours.palette.m3surfaceContainerHighest.g, Colours.palette.m3surfaceContainerHighest.b, 1.0)

                    RowLayout {
                        id: themeChipRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialIcon {
                            text: "palette"
                            iconPointSize: 15
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            text: root.pendingDeleteTheme ? (root.pendingDeleteTheme.name || root.pendingDeleteTheme.id) : ""
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.small
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }
                    }
                }

                // Subtitle / Confirmation Notice
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: qsTr("This icon pack will be permanently removed from your system.")
                    textPointSize: Tokens.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                Item { Layout.preferredHeight: Tokens.spacing.small }

                // Actions: Cancel & Delete Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.normal

                    // Cancel Button
                    StyledRect {
                        id: cancelBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Tokens.rounding.full
                        color: cancelMa.pressed ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) :
                               cancelMa.containsMouse ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 1) :
                               Qt.rgba(Colours.palette.m3surfaceContainerHighest.r, Colours.palette.m3surfaceContainerHighest.g, Colours.palette.m3surfaceContainerHighest.b, 1.0)
                        border.width: 0

                        Behavior on color { CAnim {} }

                        StyledText {
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            font.weight: Font.Medium
                            textPointSize: Tokens.font.size.normal
                            color: Colours.palette.m3onSurface
                        }

                        StateLayer {
                            radius: parent.radius
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
                        id: deleteConfirmBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Tokens.rounding.full
                        color: deleteConfirmMa.pressed ? Colours.layer(Colours.palette.m3error, 2) :
                               deleteConfirmMa.containsMouse ? Colours.layer(Colours.palette.m3error, 1) :
                               Qt.rgba(Colours.palette.m3error.r, Colours.palette.m3error.g, Colours.palette.m3error.b, 1.0)
                        border.width: 0

                        Behavior on color { CAnim {} }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIcon {
                                text: "delete"
                                iconPointSize: 16
                                color: Colours.palette.m3onError
                            }

                            StyledText {
                                text: qsTr("Delete")
                                font.weight: Font.SemiBold
                                textPointSize: Tokens.font.size.normal
                                color: Colours.palette.m3onError
                            }
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onError
                        }

                        MouseArea {
                            id: deleteConfirmMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.confirmDeleteTheme()
                        }
                    }
                }
            }
        }
    }
}