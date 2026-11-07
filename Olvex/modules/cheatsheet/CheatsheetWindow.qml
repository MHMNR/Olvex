import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.services
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import "../settings/ui"

Item {
    id: root

    signal closeRequested()

    property string activeCategory: "all"
    property string searchQuery: ""
    property bool isProgrammaticScroll: false

    Shortcut {
        sequence: "Escape"
        onActivated: root.closeRequested()
    }

    Shortcut {
        sequence: "/"
        onActivated: {
            if (!searchInput.activeFocus) {
                searchPill.searchExpanded = true;
                Qt.callLater(() => searchInput.forceActiveFocus());
            }
        }
    }

    // ── Full Comprehensive System Registry (Exact Hyprland & Olvex Binds) ──
    readonly property var sectionsData: [
        {
            id: "olvex",
            title: qsTr("Olvex Shell"),
            items: [
                { title: qsTr("Application Launcher"), mods: [], key: "Super" },
                { title: qsTr("Shell Sidebar"), mods: ["Super"], key: "N" },
                { title: qsTr("Toggle All Drawers"), mods: ["Super"], key: "K" },
                { title: qsTr("Shortcuts Cheatsheet"), mods: ["Super"], key: "/" },
                { title: qsTr("Wallpaper Selector"), mods: ["Super"], key: "W" },
                { title: qsTr("Lock Screen"), mods: ["Super"], key: "L" },
                { title: qsTr("Restore Lock Screen"), mods: ["Super", "Alt"], key: "L" },
                { title: qsTr("Suspend / Sleep"), mods: ["Super", "Shift"], key: "L" },
                { title: qsTr("Power & Session"), mods: ["Ctrl", "Alt"], key: "Del" },
                { title: qsTr("Clipboard History"), mods: ["Super"], key: "V" },
                { title: qsTr("Clear Clipboard Item"), mods: ["Super", "Alt"], key: "V" },
                { title: qsTr("Paste Latest Clip"), mods: ["Ctrl", "Shift", "Alt"], key: "V" },
                { title: qsTr("Emoji Picker"), mods: ["Super"], key: "." },
                { title: qsTr("Clear Notifications"), mods: ["Ctrl", "Alt"], key: "C" }
            ]
        },
        {
            id: "window",
            title: qsTr("Window Management"),
            items: [
                { title: qsTr("Close Focused Window"), mods: ["Super"], key: "Q" },
                { title: qsTr("Toggle Fullscreen"), mods: ["Super"], key: "F" },
                { title: qsTr("Bordered Fullscreen"), mods: ["Super", "Alt"], key: "F" },
                { title: qsTr("Toggle Floating"), mods: ["Super", "Alt"], key: "Space" },
                { title: qsTr("Center Window"), mods: ["Ctrl", "Super"], key: "\\" },
                { title: qsTr("Normalize Window (55×70)"), mods: ["Ctrl", "Super", "Alt"], key: "\\" },
                { title: qsTr("Picture-in-Picture (PiP)"), mods: ["Super", "Alt"], key: "\\" },
                { title: qsTr("Pin to All Desktops"), mods: ["Super"], key: "P" },
                { title: qsTr("Cycle Windows"), mods: ["Alt"], key: "Tab" },
                { title: qsTr("Reverse Cycle Windows"), mods: ["Shift", "Alt"], key: "Tab" },
                { title: qsTr("Focus Window (Left / Right)"), mods: ["Super"], key: "← / →" },
                { title: qsTr("Focus Window (Up / Down)"), mods: ["Super"], key: "↑ / ↓" },
                { title: qsTr("Swap Window Direction"), mods: ["Super", "Shift"], key: "Arrows" },
                { title: qsTr("Resize Window Width"), mods: ["Super"], key: "- / =" },
                { title: qsTr("Resize Window Height"), mods: ["Super", "Shift"], key: "- / =" },
                { title: qsTr("Interactive Move Window"), mods: ["Super"], key: "Z / LMB" },
                { title: qsTr("Interactive Resize Window"), mods: ["Super"], key: "X / RMB" },
                { title: qsTr("Toggle Window Group"), mods: ["Super"], key: "," },
                { title: qsTr("Ungroup Window"), mods: ["Super"], key: "U" },
                { title: qsTr("Lock Window Group"), mods: ["Super", "Shift"], key: "," },
                { title: qsTr("Cycle Group Windows"), mods: ["Ctrl", "Alt"], key: "Tab" }
            ]
        },
        {
            id: "workspace",
            title: qsTr("Workspaces"),
            items: [
                { title: qsTr("Switch Workspace 1–10"), mods: ["Super"], key: "1 – 9, 0" },
                { title: qsTr("Move Window to Workspace"), mods: ["Super", "Shift"], key: "1 – 9, 0" },
                { title: qsTr("Switch Workspace Group"), mods: ["Ctrl", "Super"], key: "1 – 9, 0" },
                { title: qsTr("Move to Workspace Group"), mods: ["Ctrl", "Super", "Alt"], key: "1 – 9, 0" },
                { title: qsTr("Next / Prev Workspace"), mods: ["Super"], key: "Scroll / Arrows" },
                { title: qsTr("Next / Prev Group (+10)"), mods: ["Ctrl", "Super"], key: "Scroll" },
                { title: qsTr("Move Window to Adjacent"), mods: ["Super", "Alt"], key: "Scroll / Arrows" },
                { title: qsTr("Toggle Special Scratchpad"), mods: ["Super"], key: "S" },
                { title: qsTr("Move Window to Scratchpad"), mods: ["Super", "Alt"], key: "S" },
                { title: qsTr("Restore from Scratchpad"), mods: ["Ctrl", "Super", "Shift"], key: "↓" },
                { title: qsTr("Music Workspace"), mods: ["Super"], key: "M" },
                { title: qsTr("Communication Workspace"), mods: ["Super"], key: "D" },
                { title: qsTr("Tasks & Todo Workspace"), mods: ["Super"], key: "R" }
            ]
        },
        {
            id: "apps",
            title: qsTr("Applications"),
            items: [
                { title: qsTr("Terminal Emulator (Kitty)"), mods: ["Super"], key: "T" },
                { title: qsTr("Web Browser (Firefox)"), mods: ["Super"], key: "B" },
                { title: qsTr("Code Editor"), mods: ["Super"], key: "C" },
                { title: qsTr("File Manager (Thunar)"), mods: ["Super"], key: "E" },
                { title: qsTr("Secondary File Explorer (Nemo)"), mods: ["Super", "Alt"], key: "E" },
                { title: qsTr("GitHub Desktop"), mods: ["Super"], key: "G" },
                { title: qsTr("Task Manager (Qps)"), mods: ["Ctrl", "Alt"], key: "Esc" },
                { title: qsTr("System Monitor (Btop)"), mods: ["Ctrl", "Shift"], key: "Esc" },
                { title: qsTr("Audio Volume Mixer (Pavucontrol)"), mods: ["Ctrl", "Alt"], key: "V" },
                { title: qsTr("Text Editor (Xed)"), mods: ["Super"], key: "J" },
                { title: qsTr("Restart Olvex Shell"), mods: ["Ctrl", "Super", "Alt"], key: "R" },
                { title: qsTr("Terminate Olvex Shell"), mods: ["Ctrl", "Super", "Shift"], key: "R" },
                { title: qsTr("Test Notification"), mods: ["Super", "Alt"], key: "F12" }
            ]
        },
        {
            id: "media",
            title: qsTr("Media & System"),
            items: [
                { title: qsTr("Screenshot Fullscreen"), mods: [], key: "Print" },
                { title: qsTr("Screenshot Region"), mods: ["Super", "Shift"], key: "S" },
                { title: qsTr("Direct Snip Region"), mods: ["Super", "Shift", "Alt"], key: "S" },
                { title: qsTr("Screen Recording (Sound)"), mods: ["Super", "Alt"], key: "R" },
                { title: qsTr("Screen Recording (Region)"), mods: ["Super", "Shift", "Alt"], key: "R" },
                { title: qsTr("Toggle Recording"), mods: ["Ctrl", "Alt"], key: "R" },
                { title: qsTr("Color Picker (Hyprpicker)"), mods: ["Super", "Shift"], key: "C" },
                { title: qsTr("Volume Raise (+10%)"), mods: [], key: "Vol Up" },
                { title: qsTr("Volume Lower (-10%)"), mods: [], key: "Vol Down" },
                { title: qsTr("Volume Mute Toggle"), mods: ["Super", "Shift"], key: "M" },
                { title: qsTr("Microphone Mute"), mods: [], key: "Mic Mute" },
                { title: qsTr("Media Play / Pause"), mods: ["Ctrl", "Super"], key: "Space" },
                { title: qsTr("Media Next Track"), mods: ["Ctrl", "Super"], key: "=" },
                { title: qsTr("Media Previous Track"), mods: ["Ctrl", "Super"], key: "-" },
                { title: qsTr("Media Stop"), mods: ["Ctrl", "Super"], key: "Backspace" },
                { title: qsTr("Brightness Up / Down"), mods: [], key: "Brightness" }
            ]
        }
    ]

    readonly property var categoryList: [
        { id: "all", title: qsTr("All"), icon: "grid_view" },
        { id: "olvex", title: qsTr("Shell"), icon: "desktop_windows" },
        { id: "window", title: qsTr("Windows"), icon: "crop_square" },
        { id: "workspace", title: qsTr("Workspaces"), icon: "view_carousel" },
        { id: "apps", title: qsTr("Apps"), icon: "launch" },
        { id: "media", title: qsTr("Media"), icon: "tune" }
    ]

    readonly property int activeCategoryIdx: {
        for (let i = 0; i < categoryList.length; i++) {
            if (categoryList[i].id === activeCategory) return i;
        }
        return 0;
    }

    function selectCategoryByIndex(idx) {
        idx = Math.max(0, Math.min(categoryList.length - 1, idx));
        if (categorySegmented) categorySegmented.currentIndex = idx;
        scrollToCategory(categoryList[idx].id);
    }

    property var sectionItemMap: ({})

    // Returns a consolidated list of keycaps
    function getAllKeys(item) {
        const list = [];
        if (item.mods && item.mods.length > 0) {
            for (let i = 0; i < item.mods.length; i++) {
                list.push({ text: item.mods[i], isTrigger: false });
            }
        }
        if (item.key) {
            list.push({ text: item.key, isTrigger: true });
        }
        return list;
    }

    function getFilteredGroups() {
        const q = root.searchQuery.trim().toLowerCase();
        const results = [];

        for (let i = 0; i < sectionsData.length; i++) {
            const sec = sectionsData[i];
            const matchedItems = [];

            for (let j = 0; j < sec.items.length; j++) {
                const item = sec.items[j];
                if (!q) {
                    matchedItems.push(item);
                } else {
                    const inTitle = item.title.toLowerCase().indexOf(q) !== -1;
                    const inKey = item.key.toLowerCase().indexOf(q) !== -1;
                    const inMods = item.mods.some(m => m.toLowerCase().indexOf(q) !== -1);
                    if (inTitle || inKey || inMods) {
                        matchedItems.push(item);
                    }
                }
            }

            if (matchedItems.length > 0) {
                results.push({
                    id: sec.id,
                    title: sec.title,
                    items: matchedItems
                });
            }
        }
        return results;
    }

    function getTotalFilteredCount() {
        const groups = getFilteredGroups();
        let total = 0;
        for (let i = 0; i < groups.length; i++) {
            total += groups[i].items.length;
        }
        return total;
    }

    function scrollToCategory(catId) {
        root.activeCategory = catId;
        if (catId === "all") {
            scrollAnimTo(0);
            return;
        }
        const targetItem = sectionItemMap[catId];
        if (targetItem) {
            const maxScroll = Math.max(0, bentoFlickable.contentHeight - bentoFlickable.height);
            const targetY = Math.min(Math.max(0, targetItem.y - 8), maxScroll);
            scrollAnimTo(targetY);
        }
    }

    function scrollAnimTo(destY) {
        root.isProgrammaticScroll = true;
        smoothScrollAnim.stop();
        smoothScrollAnim.to = Math.max(0, destY);
        smoothScrollAnim.start();
    }

    NumberAnimation {
        id: smoothScrollAnim
        target: bentoFlickable
        property: "contentY"
        duration: 220
        easing.type: Easing.OutCubic
        onFinished: {
            root.isProgrammaticScroll = false;
        }
    }

    // ── Glass Background Surface (Zero radius: Hyprland handles window corner clipping) ──
    StyledRect {
        anchors.fill: parent
        radius: 0
        color: Colours.palette.m3surfaceContainerLow
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.20)

        // Ambient primary depth tint
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3primary, 0.02)
        }
    }

    // ── Click outside searchbar anywhere in the window to collapse it ──
    MouseArea {
        anchors.fill: parent
        z: 80
        visible: searchPill.searchActive
        onClicked: {
            searchPill.searchExpanded = false;
            searchInput.focus = false;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // ── Top Header Bar (Settings Style: Title + Search Pill + Mini Close Button) ──
        Item {
            id: topHeader
            z: 90
            Layout.fillWidth: true
            Layout.preferredHeight: 56

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16
                spacing: 12

                // Left: Title + Shortcuts Count
                RowLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    MaterialIcon {
                        text: "keyboard"
                        iconPointSize: 19
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        text: qsTr("Keyboard Shortcuts")
                        font.weight: Font.DemiBold
                        textPointSize: Tokens.font.size.normal + 0.5
                        color: Colours.palette.m3onSurface
                    }
                }

                Item { Layout.fillWidth: true }

                // Right: Search Pill + Mini Close Button
                RowLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    // ── Expandable Search Pill (Settings Style: Circle 36px → 260px input field) ──
                    StyledRect {
                        id: searchPill

                        property bool searchExpanded: false
                        readonly property bool searchActive: searchExpanded || (searchInput && (searchInput.text.length > 0 || searchInput.activeFocus))

                        implicitWidth: searchActive ? 260 : 36
                        implicitHeight: 36
                        radius: Tokens.rounding.full
                        clip: true

                        color: searchActive
                            ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
                            : Colours.palette.m3surfaceContainerHigh
                        border.width: 0

                        Behavior on implicitWidth { Anim { type: Anim.DefaultSpatial } }

                        // Collapsed StateLayer for smooth M3 hover & click
                        StateLayer {
                            anchors.fill: parent
                            radius: parent.radius
                            visible: !searchPill.searchActive
                            onClicked: {
                                searchPill.searchExpanded = true;
                                Qt.callLater(() => searchInput.forceActiveFocus());
                            }
                        }

                        // Single Persistent Search Icon (Smoothly transitions position & tint)
                        MaterialIcon {
                            id: searchIcon
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: searchPill.searchActive ? 12 : Math.round((36 - searchIcon.implicitWidth) / 2)
                            text: "search"
                            iconPointSize: 16
                            color: searchInput.activeFocus ? Colours.palette.m3primary : (searchPill.searchActive ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface)

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
                                id: searchInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: Colours.palette.m3onSurface
                                selectionColor: Qt.alpha(Colours.palette.m3primary, 0.3)
                                selectedTextColor: Colours.palette.m3onSurface
                                font.family: Tokens.font.family.sans
                                font.pixelSize: 13
                                selectByMouse: true
                                cursorVisible: activeFocus

                                onTextChanged: {
                                    root.searchQuery = text;
                                }

                                Keys.onEscapePressed: event => {
                                    if (text.length > 0) {
                                        text = "";
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
                                text: qsTr("Search shortcuts... (/)")
                                color: Colours.palette.m3outline
                                font.family: Tokens.font.family.sans
                                font.pixelSize: 13
                                visible: searchInput.text.length === 0 && !searchInput.inputMethodComposing
                                opacity: searchInput.text.length === 0 ? 0.70 : 0
                                Behavior on opacity { Anim { type: Anim.FastEffects } }
                            }
                        }

                        // Clear / Collapse Button
                        StyledRect {
                            id: clearBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: Tokens.rounding.full
                            color: "transparent"
                            border.width: 0
                            opacity: searchPill.searchActive ? 1.0 : 0.0
                            visible: opacity > 0.01

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                color: Colours.palette.m3onSurfaceVariant
                                iconPointSize: 14
                                verticalAlignment: Text.AlignVCenter
                            }

                            StateLayer {
                                radius: parent.radius
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

                    // Mini Close Button (Matches search circle)
                    StyledRect {
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3surfaceContainerHigh
                        border.width: 0

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            iconPointSize: 16
                            color: Colours.palette.m3onSurface
                        }

                        StateLayer {
                            radius: parent.radius
                            onClicked: root.closeRequested()
                        }
                    }
                }
            }
        }

        // Hairline Divider below header
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.12)
        }

        // ── Category Selector using Olvex Segmented Sliding Pill Control ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 46

            Segmented {
                id: categorySegmented
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                model: [
                    { label: qsTr("All"), icon: "grid_view" },
                    { label: qsTr("Shell"), icon: "desktop_windows" },
                    { label: qsTr("Windows"), icon: "crop_square" },
                    { label: qsTr("Workspaces"), icon: "view_carousel" },
                    { label: qsTr("Apps"), icon: "launch" },
                    { label: qsTr("Media"), icon: "tune" }
                ]
                currentIndex: root.activeCategoryIdx
                onSelected: index => {
                    root.selectCategoryByIndex(index);
                }
            }
        }

        // Hairline Divider below category slider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.10)
        }

        // ── High-Density 2-Column Content Area (Linear / Raycast Style) ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            StyledFlickable {
                id: bentoFlickable
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                contentWidth: width
                contentHeight: groupsColumn.implicitHeight + 16
                visible: root.getTotalFilteredCount() > 0

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: bentoFlickable
                }

                onContentYChanged: {
                    if (root.isProgrammaticScroll || contentY <= 15) {
                        if (contentY <= 15 && !root.isProgrammaticScroll) {
                            root.activeCategory = "all";
                        }
                        return;
                    }
                    const groups = root.getFilteredGroups();
                    let currentActive = "all";
                    for (let i = groups.length - 1; i >= 0; i--) {
                        const it = root.sectionItemMap[groups[i].id];
                        if (it && it.y <= contentY + 40) {
                            currentActive = groups[i].id;
                            break;
                        }
                    }
                    if (root.activeCategory !== currentActive) {
                        root.activeCategory = currentActive;
                        if (categorySegmented) {
                            categorySegmented.currentIndex = root.activeCategoryIdx;
                        }
                    }
                }

                ColumnLayout {
                    id: groupsColumn
                    width: bentoFlickable.width - (bentoFlickable.showScrollBar ? 14 : 0)
                    spacing: 20

                    Repeater {
                        model: root.getFilteredGroups()

                        delegate: ColumnLayout {
                            id: secGroup
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 4

                            Component.onCompleted: {
                                root.sectionItemMap[secGroup.modelData.id] = secGroup;
                            }
                            Component.onDestruction: {
                                delete root.sectionItemMap[secGroup.modelData.id];
                            }

                            // Clean Minimal Category Heading
                            StyledText {
                                Layout.topMargin: 4
                                Layout.bottomMargin: 2
                                text: secGroup.modelData.title.toUpperCase()
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.2
                                textPointSize: 9
                                color: Colours.palette.m3primary
                                opacity: 0.90
                            }

                            // 2-Column Clean Rows Grid
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 14
                                rowSpacing: 2

                                Repeater {
                                    model: secGroup.modelData.items

                                    delegate: StyledRect {
                                        id: rowItem
                                        required property var modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        implicitHeight: 32
                                        radius: 6

                                        color: rowMouse.containsMouse
                                            ? Qt.alpha(Colours.palette.m3onSurface, 0.05)
                                            : "transparent"

                                        Behavior on color { CAnim {} }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            // Action Title (Single Clean Line)
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: rowItem.modelData.title
                                                font.weight: Font.Normal
                                                textPointSize: 10.5
                                                color: Colours.palette.m3onSurface
                                                elide: Text.ElideRight
                                            }

                                            // Minimal Chiclet Keycaps
                                            RowLayout {
                                                spacing: 3
                                                Layout.alignment: Qt.AlignVCenter

                                                Repeater {
                                                    model: root.getAllKeys(rowItem.modelData)

                                                    delegate: RowLayout {
                                                        id: keyItemDelegate
                                                        required property var modelData
                                                        required property int index
                                                        readonly property int totalCount: root.getAllKeys(rowItem.modelData).length
                                                        spacing: 3

                                                        StyledRect {
                                                            implicitHeight: 20
                                                            implicitWidth: Math.max(20, keyLabel.implicitWidth + 8)
                                                            radius: 4
                                                            color: keyItemDelegate.modelData.isTrigger
                                                                ? Colours.palette.m3surfaceContainerHighest
                                                                : Colours.palette.m3surfaceContainerHigh
                                                            border.width: 1
                                                            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.22)

                                                            StyledText {
                                                                id: keyLabel
                                                                anchors.centerIn: parent
                                                                text: keyItemDelegate.modelData.text
                                                                color: Colours.palette.m3onSurface
                                                                font.family: Tokens.font.family.mono || "monospace"
                                                                font.weight: Font.Medium
                                                                textPointSize: 8.5
                                                            }
                                                        }

                                                        // Subtle '+' separator
                                                        StyledText {
                                                            visible: keyItemDelegate.index < keyItemDelegate.totalCount - 1
                                                            text: "+"
                                                            font.weight: Font.Medium
                                                            textPointSize: 8
                                                            color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.35)
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: rowMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Empty State
            ColumnLayout {
                anchors.centerIn: parent
                visible: root.getTotalFilteredCount() === 0
                spacing: 8

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    iconPointSize: 32
                    text: "search_off"
                    color: Colours.palette.m3outline
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No shortcuts found")
                    font.weight: Font.Medium
                    textPointSize: Tokens.font.size.normal - 1
                    color: Colours.palette.m3onSurface
                }
            }
        }

        // Hairline Divider above footer
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.12)
        }

        // ── Ultra-Minimal Footer ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 32

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20

                StyledText {
                    text: qsTr("%1 shortcuts").arg(root.getTotalFilteredCount())
                    textPointSize: 9
                    color: Colours.palette.m3outline
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    StyledText {
                        text: qsTr("Toggle this window")
                        textPointSize: 9
                        color: Colours.palette.m3outline
                    }

                    StyledRect {
                        implicitHeight: 18
                        implicitWidth: Math.max(18, footerSuperTxt.implicitWidth + 8)
                        radius: 4
                        color: Colours.palette.m3surfaceContainerHigh
                        border.width: 1
                        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.22)

                        StyledText {
                            id: footerSuperTxt
                            anchors.centerIn: parent
                            text: "Super"
                            color: Colours.palette.m3onSurface
                            font.family: Tokens.font.family.mono || "monospace"
                            font.weight: Font.Medium
                            textPointSize: 8
                        }
                    }

                    StyledText {
                        text: "+"
                        font.weight: Font.Medium
                        textPointSize: 8
                        color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.35)
                    }

                    StyledRect {
                        implicitHeight: 18
                        implicitWidth: Math.max(18, footerSlashTxt.implicitWidth + 8)
                        radius: 4
                        color: Colours.palette.m3surfaceContainerHighest
                        border.width: 1
                        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.22)

                        StyledText {
                            id: footerSlashTxt
                            anchors.centerIn: parent
                            text: "/"
                            color: Colours.palette.m3onSurface
                            font.family: Tokens.font.family.mono || "monospace"
                            font.weight: Font.Medium
                            textPointSize: 8
                        }
                    }
                }
            }
        }
    }
}
