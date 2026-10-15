
import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.settings
import qs.modules.launcher.items
import qs.modules.launcher.services

Item {
    id: root

    property alias search: searchInput
    required property DrawerVisibilities visibilities
    required property var panels

    // Shared context menu state — single menu instance slides between items
    property DesktopEntry sharedMenuEntry: null
    property Item sharedMenuAttachTo: null
    property Item sharedMenuItem: null
    property bool keyboardHighlightActive: false

    readonly property int appsRowHeight: 120
    readonly property int appsColumns: 5
    readonly property int appsVisibleRows: 4
    readonly property int appsPaneHeight: appsVisibleRows * appsRowHeight + 10

    function isMathExpression(str) {
        if (!str || str.length === 0) return false;
        const t = str.trim();
        if (t.startsWith("calc ") || t.startsWith("=")) return true;

        if (/^(sin|cos|tan|asin|acos|atan|sqrt|cbrt|log|ln|exp|abs|floor|ceil|round)\s*\(.+\)$/i.test(t))
            return true;

        if (/^\d+(\.\d+)?\s*[a-zA-Z\$\€\£\¥\%\°]+\s+(to|in|as)\s+[a-zA-Z\$\€\£\¥\%\°]+$/i.test(t))
            return true;

        if (/^\d+(\.\d+)?\s*%\s*(of|on|\*|\+|\-)\s*\d+(\.\d+)?$/i.test(t))
            return true;

        const hasOperator = /[\+\-\*\/\^\%\=]/.test(t);
        const hasDigits = /\d/.test(t);
        if (hasOperator && hasDigits && /^[0-9\.\s\+\-\*\/\^\%\(\)\,\=]+$/.test(t)) {
            const opCount = (t.match(/[\+\-\*\/\^\%\=]/g) || []).length;
            if (opCount > 0 && !/^[a-zA-Z]/.test(t))
                return true;
        }

        return false;
    }

    function isTerminalCommand(str) {
        if (!str || str.length === 0) return false;
        const t = str.trim();
        if (t.startsWith("$") || t.startsWith("!") || t.startsWith(":") || t.startsWith("term ") || t.startsWith("run ") || t.startsWith("exec ") || t.startsWith("sh "))
            return true;
        return false;
    }

    function getTerminalCommand(str) {
        if (!str) return "";
        let t = str.trim();
        if (t.startsWith("$ ") || t.startsWith("! ") || t.startsWith(": "))
            return t.slice(2).trim();
        if (t.startsWith("$") || t.startsWith("!"))
            return t.slice(1).trim();
        if (t.startsWith("term ") || t.startsWith("exec "))
            return t.slice(5).trim();
        if (t.startsWith("run ") || t.startsWith("sh "))
            return t.slice(4).trim();
        return t;
    }

    function getCommandActionItems(cmd) {
        if (!cmd || cmd.length === 0)
            return [];
        return [
            {
                name: qsTr("Run '%1' in terminal").arg(cmd),
                desc: qsTr("Launch in default terminal"),
                icon: "terminal",
                onClicked: function(list) {
                    list.visibilities.launcher = false;
                    Quickshell.execDetached({
                        command: ["app2unit", "--", ...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, "sh", "-c", `${cmd}; exec $SHELL`]
                    });
                }
            },
            {
                name: qsTr("Run '%1' in background").arg(cmd),
                desc: qsTr("Execute command directly via shell"),
                icon: "play_arrow",
                onClicked: function(list) {
                    list.visibilities.launcher = false;
                    Quickshell.execDetached({
                        command: ["sh", "-c", cmd]
                    });
                }
            },
            {
                name: qsTr("Copy command '%1'").arg(cmd),
                desc: qsTr("Copy text to clipboard"),
                icon: "content_copy",
                onClicked: function(list) {
                    Quickshell.execDetached(["wl-copy", cmd]);
                    list.visibilities.launcher = false;
                }
            }
        ];
    }

    readonly property string state: {
        const text = search.text;

        if (isMathExpression(text))
            return "calc";

        if (isTerminalCommand(text))
            return "command";

        if (text.startsWith(">scheme") || text.startsWith("> scheme"))
            return "scheme";
        if (text.startsWith(">variant") || text.startsWith("> variant"))
            return "variant";

        if (text.trim().length > 0)
            return "search";

        return "apps";
    }

    onStateChanged: {
        suspended = false;
        keyboardHighlightActive = false;
        if (state === "scheme" || state === "variant")
            Schemes.reload();
    }

    property bool suspended: false
    property string sortMode: "recent" // "recent", "az", "za"

    onSortModeChanged: {
        if (state === "apps") {
            appGrid.currentIndex = 0;
            appGrid.contentY = 0;
        }
    }

    // Reactive model — auto-updates on search text change and sorting
    readonly property var rawModelValues: {
        if (state === "calc") return [0];
        if (state === "command") return getCommandActionItems(getTerminalCommand(search.text));
        if (state === "scheme") return Schemes.query(search.text);
        if (state === "variant") return M3Variants.query(search.text);
        if (state === "search") {
            const q = search.text.trim();
            if (!q) return [];

            // 1. Matching quick toggles
            const toggles = QuickToggles.search(q);

            // 2. Matching desktop apps
            const apps = Apps.search(q);
            const appItems = [];
            for (let i = 0; i < apps.length; i++) {
                const a = apps[i];
                if (!a) continue;
                appItems.push({
                    type: "app",
                    id: a.id,
                    name: a.name,
                    desc: a.comment || a.genericName || qsTr("Application"),
                    entry: a,
                    icon: a.icon || ""
                });
            }

            // 3. Matching settings items from PaneRegistry
            const matchedSettingIds = {};
            for (let i = 0; i < toggles.length; i++) {
                if (toggles[i].settingId)
                    matchedSettingIds[toggles[i].settingId] = true;
            }

            const rawSettings = PaneRegistry.search(q);
            const settingItems = [];
            for (let i = 0; i < rawSettings.length; i++) {
                const s = rawSettings[i];
                if (!s) continue;
                if (matchedSettingIds[s.id])
                    continue;

                settingItems.push({
                    type: "setting",
                    id: s.id,
                    pageId: s.pageId,
                    sectionId: s.sectionId,
                    title: s.title,
                    sub: s.sub,
                    breadcrumb: s.breadcrumb,
                    icon: s.icon,
                    accentRole: s.accentRole,
                    searchQuery: q,
                    score: s.score || 0
                });
            }

            // 4. Combine results:
            const highToggles = [];
            const lowToggles = [];
            for (let i = 0; i < toggles.length; i++) {
                if (toggles[i].score >= 140)
                    highToggles.push(toggles[i]);
                else
                    lowToggles.push(toggles[i]);
            }

            const combined = [];
            for (let i = 0; i < highToggles.length; i++) combined.push(highToggles[i]);
            for (let i = 0; i < appItems.length; i++) combined.push(appItems[i]);
            for (let i = 0; i < lowToggles.length; i++) combined.push(lowToggles[i]);
            for (let i = 0; i < settingItems.length; i++) combined.push(settingItems[i]);

            // 5. If no matches at all, fallback to terminal commands
            if (combined.length === 0)
                return getCommandActionItems(getTerminalCommand(search.text));

            return combined;
        }
        if (state === "apps") return Apps.search(search.text);
        return [];
    }

    readonly property var modelValues: {
        if (state === "apps" && rawModelValues && sortMode !== "recent") {
            const list = rawModelValues.slice();
            if (sortMode === "az") {
                return list.sort((a, b) => ((a && a.name) ? a.name : "").localeCompare((b && b.name) ? b.name : ""));
            } else if (sortMode === "za") {
                return list.sort((a, b) => ((b && b.name) ? b.name : "").localeCompare((a && a.name) ? a.name : ""));
            }
            return list;
        }
        return rawModelValues;
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            Apps.invalidateCatalog();
        }
    }

    readonly property int count: state === "apps" ? appGrid.count : actionList.count
    readonly property int currentIndex: state === "apps" ? appGrid.currentIndex : actionList.currentIndex
    readonly property var currentItem: state === "apps" ? appGrid.currentItem : actionList.currentItem

    function showKeyboardHighlight() {
        keyboardHighlightActive = true;
        appGrid.hoveredItem = null;
    }

    function showMouseHighlight(item: Item) {
        if (sharedContextMenu.expanded) return;
        keyboardHighlightActive = false;
        appGrid.currentIndex = item.index;
        appGrid.hoveredItem = item;
    }

    function decrementCurrentIndex() {
        if (sharedContextMenu.expanded)
            sharedContextMenu.expanded = false;
        if (state === "apps") {
            showKeyboardHighlight();
            appGrid.currentIndex = Math.max(0, appGrid.currentIndex - appsColumns);
            Qt.callLater(scrollToCurrentItem);
        } else {
            actionList.decrementCurrentIndex();
        }
    }

    function incrementCurrentIndex() {
        if (sharedContextMenu.expanded)
            sharedContextMenu.expanded = false;
        if (state === "apps") {
            showKeyboardHighlight();
            appGrid.currentIndex = Math.min(appGrid.count - 1, appGrid.currentIndex + appsColumns);
            Qt.callLater(scrollToCurrentItem);
        } else {
            actionList.incrementCurrentIndex();
        }
    }

    function moveLeft() {
        if (sharedContextMenu.expanded)
            sharedContextMenu.expanded = false;
        if (state === "apps") {
            showKeyboardHighlight();
            appGrid.currentIndex = Math.max(0, appGrid.currentIndex - 1);
            Qt.callLater(scrollToCurrentItem);
        } else {
            actionList.decrementCurrentIndex();
        }
    }

    function moveRight() {
        if (sharedContextMenu.expanded)
            sharedContextMenu.expanded = false;
        if (state === "apps") {
            showKeyboardHighlight();
            appGrid.currentIndex = Math.min(appGrid.count - 1, appGrid.currentIndex + 1);
            Qt.callLater(scrollToCurrentItem);
        } else {
            actionList.incrementCurrentIndex();
        }
    }

    // Smoothly scroll grid so the keyboard-selected item is fully visible
    function scrollToCurrentItem() {
        const item = appGrid.currentItem;
        if (!item) return;
        const itemTop = item.y;                        // content-space Y
        const itemBot = itemTop + item.height;
        const visTop = appGrid.contentY;
        const visBot = visTop + appGrid.height;
        const maxScroll = Math.max(0, appGrid.contentHeight - appGrid.height);
        let target = -1;
        if (itemTop < visTop) {
            target = Math.max(0, itemTop - 4);
        } else if (itemBot > visBot) {
            target = Math.min(maxScroll, itemBot - appGrid.height + 4);
        }
        if (target < 0) return;
        bounceBackSpring.stop();
        smoothScrollAnim.stop();
        smoothScrollAnim.from = appGrid.contentY;
        smoothScrollAnim.to = target;
        smoothScrollAnim.start();
    }

    property int revealEpoch: 0
    property bool revealPending: false

    readonly property var m3Emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]

    function playOpenReveal() {
        if (root.state !== "apps" || !root.visibilities.launcher)
            return;
        bounceBackSpring.stop();
        smoothScrollAnim.stop();
        revealDelay.stop();
        revealPending = true;
        keyboardHighlightActive = false;
        revealDelay.restart();
    }

    function suspend() {
        smoothScrollAnim.stop();
        bounceBackSpring.stop();
        touchpadReleaseTimer.stop();
        revealDelay.stop();
        revealPending = false;
        keyboardHighlightActive = false;
        appGrid.contentY = 0;
        appGrid.currentIndex = 0;
        actionList.currentIndex = 0;
    }

    function resume() {
        revealDelay.stop();
        revealPending = true;
        Qt.callLater(playOpenReveal);
    }

    Connections {
        target: visibilities
        function onLauncherChanged() {
            if (visibilities.launcher) {
                resume();
                if (visibilities.launcherSearchText) {
                    searchInput.text = visibilities.launcherSearchText;
                    visibilities.launcherSearchText = "";
                }
                Qt.callLater(() => searchInput.forceActiveFocus());
            } else {
                suspend();
                sortContainer.expanded = false;
                searchPill.searchExpanded = false;
                searchInput.text = "";
                searchInput.focus = false;
                // Dismiss context menu when launcher closes
                sharedContextMenu.expanded = false;
            }
        }
        function onLauncherSearchTextChanged() {
            if (visibilities.launcherSearchText) {
                searchInput.text = visibilities.launcherSearchText;
                visibilities.launcherSearchText = "";
                Qt.callLater(() => searchInput.forceActiveFocus());
            }
        }
    }

    // Material 3 Expressive Smooth and Bouncy Momentum Scroll
    NumberAnimation {
        id: smoothScrollAnim
        target: appGrid
        property: "contentY"
        duration: 260
        easing.type: Easing.OutCubic

        onStopped: root.checkOverscrollBounds()
    }

    // Elastic Overscroll Rebound Spring
    SpringAnimation {
        id: bounceBackSpring
        target: appGrid
        property: "contentY"
        spring: 4.8
        damping: 0.70
        epsilon: 0.15
    }

    Timer {
        id: touchpadReleaseTimer
        interval: 85
        repeat: false
        onTriggered: root.checkOverscrollBounds()
    }

    function checkOverscrollBounds() {
        const maxScroll = Math.max(0, appGrid.contentHeight - appGrid.height);
        if (appGrid.contentY < 0) {
            smoothScrollAnim.stop();
            bounceBackSpring.stop();
            bounceBackSpring.from = appGrid.contentY;
            bounceBackSpring.to = 0;
            bounceBackSpring.start();
        } else if (appGrid.contentY > maxScroll) {
            smoothScrollAnim.stop();
            bounceBackSpring.stop();
            bounceBackSpring.from = appGrid.contentY;
            bounceBackSpring.to = maxScroll;
            bounceBackSpring.start();
        }
    }

    Timer {
        id: revealDelay

        interval: 16
        repeat: false
        onTriggered: {
            root.revealPending = false;
            root.revealEpoch++;
        }
    }

    Component.onCompleted: {
        Apps.warmCatalog();
        // Initialize safe non-null default for sharedMenuAttachTo
        sharedMenuAttachTo = appGridHost;
    }

    implicitWidth: state === "apps" ? 590 : Tokens.sizes.launcher.itemWidth
    implicitHeight: {
        if (state === "apps")
            return appsPaneHeight;
        const maxShown = Config.launcher.maxShown ? Config.launcher.maxShown : 6;
        return (Tokens.sizes.launcher.itemHeight + 8) * Math.min(maxShown, count) + 36;
    }

    // Top Header Bar with Search Pill and Sort Button
    Item {
        id: headerBar

        visible: true
        width: 550
        height: 38
        z: 100
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 4

        StyledText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Applications")
            color: Colours.palette.m3onSurface
            textPointSize: Tokens.font.size.normal
            font.weight: Font.DemiBold
        }

        // Expandable Morphing Search Pill (Circle 38px -> 320px input field)
        Item {
            id: searchPillHost
            anchors.right: sortControlHost.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: searchPill.width
            height: searchPill.height
            z: searchPill.searchActive ? 98 : 1

            // Click-outside overlay: dismiss search when clicking anywhere outside searchbar
            MouseArea {
                anchors.fill: parent
                anchors.margins: -2000
                visible: searchPill.searchActive
                z: 0
                onClicked: {
                    searchPill.searchExpanded = false;
                    searchInput.text = "";
                    searchInput.focus = false;
                }
            }

            StyledRect {
                id: searchPill
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                z: 1

                property bool searchExpanded: false
                readonly property bool searchActive: searchExpanded || searchInput.text.length > 0 || (searchInput.activeFocus && (searchInput.text.length > 0 || searchExpanded))

                implicitWidth: searchActive ? 320 : 38
                implicitHeight: 38
                radius: 19
                clip: true

            color: searchActive ? Colours.palette.m3surfaceContainerHigh
                                : (searchPillHover.hovered ? Colours.palette.m3surfaceContainerHigh
                                                           : Colours.palette.m3surfaceContainer)
            border.width: 0

            Behavior on implicitWidth { Anim { type: Anim.Emphasized } }
            Behavior on color { CAnim {} }

            HoverHandler {
                id: searchPillHover
                cursorShape: searchPill.searchActive ? Qt.IBeamCursor : Qt.PointingHandCursor
            }

            // Collapsed Click-to-Expand Trigger
            MouseArea {
                anchors.fill: parent
                visible: !searchPill.searchActive
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    searchPill.searchExpanded = true;
                    Qt.callLater(() => searchInput.forceActiveFocus());
                }
            }

            // Single Search Icon
            MaterialIcon {
                id: searchPillIcon
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: searchPill.searchActive ? 12 : Math.round((38 - searchPillIcon.implicitWidth) / 2)
                text: "search"
                iconPointSize: 18
                color: searchInput.activeFocus ? Colours.palette.m3primary
                     : (searchPill.searchActive ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3primary)

                Behavior on anchors.leftMargin { Anim { type: Anim.Emphasized } }
                Behavior on color { CAnim {} }
            }

            // Text Input & Placeholder Holder
            Item {
                id: searchInputHolder
                anchors.left: searchPillIcon.right
                anchors.leftMargin: 6
                anchors.right: searchClearBtn.left
                anchors.rightMargin: 4
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                clip: true
                opacity: searchPill.searchActive ? 1.0 : 0.0
                visible: opacity > 0.01

                Behavior on opacity { Anim { type: Anim.FastEffects } }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colours.palette.m3onSurface
                    selectionColor: Qt.alpha(Colours.palette.m3primary, 0.3)
                    selectedTextColor: Colours.palette.m3onSurface
                    font.family: Tokens.font.family.sans
                    font.pixelSize: Math.max(12, Math.round(Tokens.font.size.normal * 96 / 72))
                    selectByMouse: true
                    cursorVisible: activeFocus

                    onAccepted: {
                        if (root.count > 0 && root.currentItem) {
                            const cur = root.currentItem;
                            if (cur.select) {
                                cur.select();
                            } else if (root.state === "calc" && cur.onClicked) {
                                cur.onClicked();
                            } else if (cur.modelData && cur.modelData.onClicked) {
                                cur.modelData.onClicked(root);
                            } else if (cur.modelData && cur.modelData.id) {
                                Apps.launch(cur.modelData);
                                root.visibilities.launcher = false;
                                Visibilities.launcherInterrupted = true;
                            }
                        }
                    }

                    Keys.priority: Keys.BeforeItem
                    Keys.onUpPressed: event => {
                        root.showKeyboardHighlight();
                        root.decrementCurrentIndex();
                        event.accepted = true;
                    }
                    Keys.onDownPressed: event => {
                        root.showKeyboardHighlight();
                        root.incrementCurrentIndex();
                        event.accepted = true;
                    }
                    Keys.onLeftPressed: event => {
                        root.showKeyboardHighlight();
                        root.moveLeft();
                        event.accepted = true;
                    }
                    Keys.onRightPressed: event => {
                        root.showKeyboardHighlight();
                        root.moveRight();
                        event.accepted = true;
                    }
                    Keys.onEscapePressed: event => {
                        if (text.length > 0) {
                            text = "";
                            event.accepted = true;
                        } else {
                            searchPill.searchExpanded = false;
                            focus = false;
                            root.visibilities.launcher = false;
                            event.accepted = true;
                        }
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Left) {
                            root.showKeyboardHighlight();
                            root.moveLeft();
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Right) {
                            root.showKeyboardHighlight();
                            root.moveRight();
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Up) {
                            root.showKeyboardHighlight();
                            root.decrementCurrentIndex();
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Down) {
                            root.showKeyboardHighlight();
                            root.incrementCurrentIndex();
                            event.accepted = true;
                            return;
                        }

                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.count > 0 && root.currentItem) {
                                const cur = root.currentItem;
                                if ((event.modifiers & Qt.ShiftModifier) && cur.openSettings) {
                                    cur.openSettings();
                                    event.accepted = true;
                                    return;
                                }

                                if (cur.select) {
                                    cur.select();
                                } else if (root.state === "calc" && cur.onClicked) {
                                    cur.onClicked();
                                } else if (cur.modelData && cur.modelData.onClicked) {
                                    cur.modelData.onClicked(root);
                                } else if (cur.modelData && cur.modelData.id) {
                                    Apps.launch(cur.modelData);
                                    root.visibilities.launcher = false;
                                    Visibilities.launcherInterrupted = true;
                                }
                            }
                            event.accepted = true;
                        }
                    }

                    cursorDelegate: Rectangle {
                        width: 2
                        height: searchInput.font.pixelSize * 1.2
                        radius: 1
                        color: Colours.palette.m3primary
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: searchInput.activeFocus
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
                    text: qsTr("Search apps, math...")
                    color: Colours.palette.m3outline
                    font.family: Tokens.font.family.sans
                    font.pixelSize: Math.max(12, Math.round(Tokens.font.size.normal * 96 / 72))
                    visible: searchInput.text.length === 0 && !searchInput.inputMethodComposing
                    opacity: searchInput.text.length === 0 ? 0.75 : 0
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                }
            }

            // Clear / Close Button
            StyledRect {
                id: searchClearBtn
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 26
                implicitHeight: 26
                radius: 13
                color: searchClearMa.pressed ? Qt.alpha(Colours.palette.m3onSurface, 0.12) :
                       searchClearMa.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : "transparent"
                opacity: searchPill.searchActive ? 1.0 : 0.0
                visible: opacity > 0.01

                Behavior on color { CAnim {} }
                Behavior on opacity { Anim { type: Anim.FastEffects } }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "close"
                    color: Colours.palette.m3onSurfaceVariant
                    iconPointSize: 15
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    id: searchClearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (searchInput.text.length > 0) {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        } else {
                            searchPill.searchExpanded = false;
                            searchInput.focus = false;
                        }
                    }
                }
            }
        }
    }

    // Container Transform Sort Control (Icon morphs into sorting list menu)
        Item {
            id: sortControlHost
            anchors.right: parent.right
            anchors.top: parent.top
            width: sortContainer.width
            height: 38
            z: sortContainer.expanded ? 99 : 1

            // Click-outside overlay to dismiss menu & block mouse focus/hover leaks
            MouseArea {
                anchors.fill: parent
                anchors.margins: -2000
                visible: sortContainer.expanded
                hoverEnabled: true
                preventStealing: true
                z: 0
                onClicked: sortContainer.expanded = false
            }

            StyledRect {
                id: sortContainer
                anchors.right: parent.right
                anchors.top: parent.top
                z: 1
                clip: true

                property bool expanded: false

                width: expanded ? 208 : 38
                height: expanded ? 124 : 38
                radius: expanded ? 16 : 19

                // Opaque Material 3 surface color (m3surfaceContainerHigh)
                color: expanded ? Colours.palette.m3surfaceContainerHigh
                                : (sortIconHover.hovered ? Colours.palette.m3surfaceContainerHigh
                                                         : Colours.palette.m3surfaceContainer)
                border.width: 0

                Behavior on width { Anim { type: Anim.Emphasized } }
                Behavior on height { Anim { type: Anim.Emphasized } }
                Behavior on radius { Anim { type: Anim.Emphasized } }
                Behavior on color { CAnim {} }
                Behavior on border.color { CAnim {} }

                // ── LAYER 1: Collapsed Icon State ──
                Item {
                    id: collapsedIcon
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: 38
                    height: 38
                    opacity: sortContainer.expanded ? 0 : 1
                    scale: sortContainer.expanded ? 0.5 : 1
                    visible: !sortContainer.expanded && opacity > 0.01

                    Behavior on opacity { Anim { duration: Tokens.anim.durations.small } }
                    Behavior on scale { Anim { duration: Tokens.anim.durations.small } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: root.sortMode === "az" ? "sort_by_alpha" : (root.sortMode === "za" ? "swap_vert" : "history")
                        color: Colours.palette.m3primary
                        iconPointSize: 16
                    }

                    HoverHandler {
                        id: sortIconHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: sortContainer.expanded = !sortContainer.expanded
                    }
                }

                // ── LAYER 2: Expanded Container Transform List Menu ──
                // Plain Item wrapper isolates sliding sortHoverHighlight from ColumnLayout (prevents re-layout glitch)
                Item {
                    id: expandedMenuArea
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    width: 196
                    height: 112
                    opacity: sortContainer.expanded ? 1 : 0
                    scale: sortContainer.expanded ? 1 : 0.85
                    visible: opacity > 0.01

                    property Item hoveredItem: null

                    Timer {
                        id: clearHoverTimer
                        interval: 75
                        onTriggered: expandedMenuArea.hoveredItem = null
                    }

                    Behavior on opacity { Anim { duration: sortContainer.expanded ? Tokens.anim.durations.normal : 100 } }
                    Behavior on scale { Anim { type: Anim.Emphasized } }

                    // Sliding hover highlight marker — exact Panels.qml context menu hover pill
                    StyledRect {
                        id: sortHoverHighlight

                        readonly property Item target: expandedMenuArea.hoveredItem

                        z: 0
                        visible: target !== null && sortContainer.expanded
                        opacity: visible ? 0.08 : 0
                        color: Colours.palette.m3onSurface
                        border.width: 0
                        radius: Tokens.rounding.small

                        x: target ? target.mapToItem(expandedMenuArea, 0, 0).x : x
                        y: target ? target.mapToItem(expandedMenuArea, 0, 0).y : y
                        width: target ? target.width : width
                        height: target ? target.height : height

                        Behavior on x {
                            enabled: sortHoverHighlight.opacity > 0
                            SpringAnimation {
                                spring: 7.0
                                damping: 0.8
                                mass: 1.0
                                epsilon: 0.005
                            }
                        }
                        Behavior on y {
                            enabled: sortHoverHighlight.opacity > 0
                            SpringAnimation {
                                spring: 7.0
                                damping: 0.8
                                mass: 1.0
                                epsilon: 0.005
                            }
                        }
                        Behavior on width {
                            enabled: sortHoverHighlight.opacity > 0
                            SpringAnimation {
                                spring: 7.0
                                damping: 0.8
                                mass: 1.0
                                epsilon: 0.005
                            }
                        }
                        Behavior on height {
                            enabled: sortHoverHighlight.opacity > 0
                            SpringAnimation {
                                spring: 7.0
                                damping: 0.8
                                mass: 1.0
                                epsilon: 0.005
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }

                    ColumnLayout {
                        id: expandedList
                        anchors.fill: parent
                        spacing: 2
                        z: 1

                        Repeater {
                            id: sortRepeater
                            model: [
                                { mode: "recent", label: qsTr("Recently Opened"), icon: "history" },
                                { mode: "az", label: qsTr("A  -  Z"), icon: "sort_by_alpha" },
                                { mode: "za", label: qsTr("Z  -  A"), icon: "swap_vert" }
                            ]

                            delegate: Item {
                                id: itemRect
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                z: 1

                                readonly property bool isActive: root.sortMode === modelData.mode

                                // Active selection background pill (m3primary)
                                StyledRect {
                                    anchors.fill: parent
                                    radius: Tokens.rounding.small
                                    color: itemRect.isActive ? Colours.palette.m3primary : "transparent"
                                    z: 0
                                    Behavior on color { CAnim {} }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8
                                    z: 2

                                    MaterialIcon {
                                        text: itemRect.modelData.icon
                                        color: itemRect.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                        iconPointSize: 14
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: itemRect.modelData.label
                                        color: itemRect.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                        textPointSize: Tokens.font.size.smaller
                                        font.weight: itemRect.isActive ? Font.Bold : Font.Normal
                                    }
                                }

                                HoverHandler {
                                    id: itemHover
                                    cursorShape: Qt.PointingHandCursor
                                    onHoveredChanged: {
                                        if (hovered) {
                                            clearHoverTimer.stop();
                                            expandedMenuArea.hoveredItem = itemRect;
                                        } else {
                                            clearHoverTimer.restart();
                                        }
                                    }
                                }

                                TapHandler {
                                    onTapped: {
                                        root.sortMode = itemRect.modelData.mode;
                                        sortContainer.expanded = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: appGridHost

        visible: root.state === "apps"
        width: 550
        height: root.appsPaneHeight - 44
        transformOrigin: Item.Bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: headerBar.bottom
        anchors.topMargin: 4
        clip: true

        Timer {
            id: clearGridHoverTimer
            interval: 75
            onTriggered: appGrid.hoveredItem = null
        }

        GridView {
            id: appGrid
            property Item hoveredItem: null
            readonly property var clearHoverTimer: clearGridHoverTimer

            anchors.fill: parent
            z: 1

            cellWidth: 110
            cellHeight: root.appsRowHeight
            cacheBuffer: root.appsRowHeight * 2
            reuseItems: true
            boundsBehavior: Flickable.DragAndOvershootBounds
            flickDeceleration: 2200
            maximumFlickVelocity: 3200
            // Focus chrome is a separate sliding marker (not built-in highlight)
            highlightFollowsCurrentItem: false
            keyNavigationEnabled: false

            model: root.state === "apps" ? root.modelValues : null
            delegate: gridAppItemComponent

            add: Transition {
                enabled: root.search.text.length > 0
                NumberAnimation {
                    properties: "opacity,scale"
                    from: 0.65
                    to: 1
                    duration: 160
                    easing.type: Easing.OutQuad
                }
            }

            remove: Transition {
                NumberAnimation {
                    properties: "opacity,scale"
                    from: 1
                    to: 0
                    duration: 150
                    easing.type: Easing.InQuad
                }
            }

            displaced: Transition {
                enabled: root.search.text.length > 0
                NumberAnimation {
                    properties: "x,y"
                    duration: 180
                    easing.type: Easing.OutQuad
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                onWheel: event => {
                    const delta = event.angleDelta.y;
                    if (!delta)
                        return;

                    const maxScroll = Math.max(0, appGrid.contentHeight - appGrid.height);
                    const isDiscrete = Math.abs(delta) >= 120;
                    const direction = delta > 0 ? -1 : 1;

                    if (isDiscrete) {
                        bounceBackSpring.stop();
                        touchpadReleaseTimer.stop();

                        const step = root.appsRowHeight;
                        const base = smoothScrollAnim.running ? smoothScrollAnim.to : appGrid.contentY;
                        let nextTarget = base + direction * step;

                        // Allow elastic overscroll bounce up to 36px past edge limits
                        const maxOvershoot = 36;
                        if (nextTarget < -maxOvershoot) {
                            nextTarget = -maxOvershoot;
                        } else if (nextTarget > maxScroll + maxOvershoot) {
                            nextTarget = maxScroll + maxOvershoot;
                        }

                        smoothScrollAnim.stop();
                        smoothScrollAnim.from = appGrid.contentY;
                        smoothScrollAnim.to = nextTarget;
                        smoothScrollAnim.start();
                    } else {
                        // Smooth pixel touchpad scrolling with elastic edge resistance
                        smoothScrollAnim.stop();
                        bounceBackSpring.stop();

                        const dy = -delta * 0.65;
                        let newY = appGrid.contentY + dy;

                        if (newY < 0) {
                            newY = appGrid.contentY + dy * 0.35;
                        } else if (newY > maxScroll) {
                            newY = appGrid.contentY + dy * 0.35;
                        }

                        appGrid.contentY = newY;
                        touchpadReleaseTimer.restart();
                    }

                    event.accepted = true;
                }
            }
        }

        // Unified sliding focus marker — springs between tiles (hover + keyboard)
        StyledRect {
            id: gridFocusMarker

            // Prefer hover; keyboard nav clears hover so currentItem wins; context menu locks focus on target item
            readonly property Item targetItem: {
                if (root.state !== "apps" || !root.visibilities.launcher)
                    return null;
                if (sharedContextMenu.expanded) {
                    if (root.sharedMenuItem)
                        return root.sharedMenuItem;
                    if (appGrid.currentItem)
                        return appGrid.currentItem;
                }
                if (appGrid.hoveredItem)
                    return appGrid.hoveredItem;
                if (appGrid.currentItem)
                    return appGrid.currentItem;
                return null;
            }
            readonly property bool active: targetItem !== null && !root.revealPending

            property bool springEnabled: false
            property real markerX: 0
            property real markerY: 0

            z: 0 // under GridView tiles
            width: 102
            height: 112
            radius: 16
            color: root.keyboardHighlightActive 
                ? Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.20 : 0.24)
                : Qt.alpha(Colours.palette.m3onSurface, Colours.light ? 0.12 : 0.08)
            border.width: 0
            x: markerX
            y: markerY
            opacity: active ? 1 : 0
            enabled: false

            function retarget(animate) {
                const item = targetItem;
                if (!item)
                    return;
                const nx = item.x + 4;
                const ny = item.y - appGrid.contentY + 4;
                springEnabled = animate && root.visibilities.launcher && !root.revealPending && opacity > 0.05;
                markerX = nx;
                markerY = ny;
                // Keep spring enabled for continuous movement
                gridFocusMarker.springEnabled = root.visibilities.launcher && !root.revealPending;
            }

            onTargetItemChanged: {
                if (targetItem !== null)
                    retarget(active && opacity > 0.05);
            }
            onActiveChanged: {
                if (active)
                    retarget(opacity > 0.05);
                else
                    springEnabled = false;
            }

            Connections {
                target: appGrid
                function onCurrentIndexChanged() {
                    gridFocusMarker.retarget(true);
                }
                function onHoveredItemChanged() {
                    gridFocusMarker.retarget(true);
                }
                function onContentYChanged() {
                    // Animate smoothly during smoothScrollAnim; stick directly only during manual drag
                    const animate = smoothScrollAnim.running;
                    gridFocusMarker.retarget(animate);
                }
            }

            Connections {
                target: root
                function onKeyboardHighlightActiveChanged() {
                    gridFocusMarker.retarget(true);
                }
                function onRevealPendingChanged() {
                    if (!root.revealPending && gridFocusMarker.targetItem)
                        gridFocusMarker.retarget(false);
                }
            }

            Behavior on color { CAnim {} }

            Behavior on markerX {
                enabled: gridFocusMarker.springEnabled
                SpringAnimation {
                    spring: 4.6
                    damping: 0.74
                    mass: 1.0
                    epsilon: 0.005
                }
            }
            Behavior on markerY {
                enabled: gridFocusMarker.springEnabled
                SpringAnimation {
                    spring: 4.6
                    damping: 0.74
                    mass: 1.0
                    epsilon: 0.005
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on border.color {
                CAnim {}
            }
        }
    }

    Component {
        id: gridAppItemComponent
        GridAppItem {
            visibilities: root.visibilities
            panels: root.panels
            gridView: appGrid
            revealEpoch: root.revealEpoch
            revealPending: root.revealPending
            contextMenuOpen: sharedContextMenu.expanded

            onMouseActivated: item => root.showMouseHighlight(item)

            onContextMenuRequested: (src, item) => {
                root.sharedMenuEntry = modelData;
                root.sharedMenuAttachTo = src;
                root.sharedMenuItem = item;
                sharedContextMenu.expanded = true;
            }
        }
    }

    // Shared context menu — single instance that slides between items (Panels.qml pattern)
    Menu {
        id: sharedContextMenu

        // Safe null-fallback: appGridHost is forward ref but resolved before first use
        attachTo: root.sharedMenuAttachTo ?? root

        items: [
            MenuItem {
                text: qsTr("Open")
                icon: "rocket_launch"
                onClicked: {
                    if (root.sharedMenuEntry) {
                        Apps.launch(root.sharedMenuEntry);
                        root.visibilities.launcher = false;
                    }
                }
            },
            MenuItem {
                readonly property bool isPinned: {
                    if (!root.sharedMenuEntry) return false;
                    const pApps = root.visibilities.pinnedApps || [];
                    for (let i = 0; i < pApps.length; i++) {
                        if (pApps[i] === root.sharedMenuEntry.id) return true;
                    }
                    return false;
                }
                text: isPinned ? qsTr("Remove from Panel") : qsTr("Add to Panel")
                icon: isPinned ? "keep_off" : "push_pin"
                onClicked: {
                    if (!root.sharedMenuEntry) return;
                    const id = root.sharedMenuEntry.id;
                    const rawPinned = root.visibilities.pinnedApps || [];
                    const pinned = [];
                    for (let i = 0; i < rawPinned.length; i++) pinned.push(rawPinned[i]);
                    const idx = pinned.indexOf(id);
                    if (idx > -1) pinned.splice(idx, 1);
                    else pinned.push(id);
                    root.visibilities.pinnedApps = pinned;
                }
            }
        ]
    }

    Connections {
        target: sharedContextMenu
        function onExpandedChanged() {
            if (!sharedContextMenu.expanded) {
                root.sharedMenuItem = null;
                appGrid.hoveredItem = null;
            }
            gridFocusMarker.retarget(true);
        }
    }

    StyledScrollBar {
        id: gridScrollBar
        flickable: appGrid
        anchors.right: appGridHost.right
        anchors.top: appGridHost.top
        anchors.bottom: appGridHost.bottom
        visible: appGridHost.visible && appGrid.contentHeight > appGrid.height
    }

    Item {
        id: actionListHost

        visible: root.state !== "apps"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: headerBar.bottom
        anchors.topMargin: 4
        clip: true

        // Sliding focus marker under list rows
        StyledRect {
            id: listFocusMarker

            readonly property Item targetItem: actionListHost.visible ? actionList.currentItem : null
            readonly property bool active: targetItem !== null

            property bool springEnabled: false
            property real markerY: 0
            property real markerH: Tokens.sizes.launcher.itemHeight || 56

            z: 0
            x: 0
            width: actionList.width
            y: markerY
            height: markerH
            radius: Tokens.rounding.normal
            color: Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.14 : 0.18)
            border.width: 0
            opacity: active ? 1 : 0
            enabled: false

            function retarget(animate) {
                const item = targetItem;
                if (!item)
                    return;
                const ny = item.y - actionList.contentY;
                const nh = item.height > 0 ? item.height : (Tokens.sizes.launcher.itemHeight || 56);
                springEnabled = animate && actionListHost.visible;
                markerY = ny;
                markerH = nh;
                if (!animate) {
                    Qt.callLater(() => {
                        if (listFocusMarker.targetItem)
                            listFocusMarker.springEnabled = actionListHost.visible;
                    });
                }
            }

            onTargetItemChanged: retarget(springEnabled && targetItem !== null)
            onActiveChanged: {
                if (active)
                    retarget(false);
                else
                    springEnabled = false;
            }

            Connections {
                target: actionList
                function onCurrentIndexChanged() {
                    listFocusMarker.retarget(true);
                }
                function onContentYChanged() {
                    listFocusMarker.retarget(false);
                }
                function onCountChanged() {
                    listFocusMarker.retarget(false);
                }
            }

            Connections {
                target: actionListHost
                function onVisibleChanged() {
                    if (actionListHost.visible)
                        listFocusMarker.retarget(false);
                    else
                        listFocusMarker.springEnabled = false;
                }
            }

            Behavior on markerY {
                enabled: listFocusMarker.springEnabled
                SpringAnimation {
                    spring: 4.6
                    damping: 0.74
                    mass: 1.0
                    epsilon: 0.005
                }
            }
            Behavior on markerH {
                enabled: listFocusMarker.springEnabled
                SpringAnimation {
                    spring: 5.0
                    damping: 0.78
                    mass: 1.0
                    epsilon: 0.005
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }

        StyledListView {
            id: actionList

            property var search: root.search
            property var visibilities: root.visibilities

            anchors.fill: parent
            z: 1
            clip: true
            spacing: 8

            model: root.state !== "apps" ? root.modelValues : null

            delegate: {
                if (root.state === "command")
                    return actionItem;
                if (root.state === "calc")
                    return calcItem;
                if (root.state === "scheme")
                    return schemeItem;
                if (root.state === "variant")
                    return variantItem;
                if (root.state === "search")
                    return searchResultItem;
                return null;
            }

            // Custom sliding marker — disable snap-jump built-in highlight
            highlightFollowsCurrentItem: false
            highlight: null

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: actionList
                visible: actionList.visible && actionList.contentHeight > actionList.height
            }
        }
    }

    Component {
        id: actionItem
        ActionItem {
            list: actionList
        }
    }

    Component {
        id: calcItem
        CalcItem {
            list: actionList
            visibilities: root.visibilities
        }
    }

    Component {
        id: schemeItem
        SchemeItem { list: actionList }
    }

    Component {
        id: variantItem
        VariantItem { list: actionList }
    }

    Component {
        id: searchResultItem
        SearchResultItem {
            list: actionList
            visibilities: root.visibilities
        }
    }
}
