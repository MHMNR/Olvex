import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.services
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects

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

    // ── Full Comprehensive 72-Shortcut System Registry Grouped By Category ──
    readonly property var sectionsData: [
        {
            id: "olvex",
            title: qsTr("Olvex Shell"),
            icon: "desktop_windows",
            items: [
                { title: qsTr("Application Launcher"), desc: qsTr("Search apps, files & math"), icon: "apps", mods: ["Super"], key: "Space" },
                { title: qsTr("Shell Sidebar"), desc: qsTr("Notifications & quick toggles flyout"), icon: "side_navigation", mods: ["Super"], key: "N" },
                { title: qsTr("Quick Settings"), desc: qsTr("Media, network & volume panel"), icon: "tune", mods: ["Super"], key: "K" },
                { title: qsTr("Shortcuts Cheatsheet"), desc: qsTr("Toggle this keyboard guide"), icon: "help_outline", mods: ["Super"], key: "/" },
                { title: qsTr("Wallpaper Selector"), desc: qsTr("Browse local & online wallpapers"), icon: "wallpaper", mods: ["Super"], key: "W" },
                { title: qsTr("Lock Screen"), desc: qsTr("Lock current session immediately"), icon: "lock", mods: ["Super"], key: "L" },
                { title: qsTr("Restore Lock Screen"), desc: qsTr("Re-engage lock screen surface"), icon: "lock_reset", mods: ["Super", "Alt"], key: "L" },
                { title: qsTr("Suspend / Sleep"), desc: qsTr("Enter low-power sleep mode"), icon: "bedtime", mods: ["Super", "Shift"], key: "L" },
                { title: qsTr("Power & Session"), desc: qsTr("Shutdown, restart & logout dialog"), icon: "power_settings_new", mods: ["Ctrl", "Alt"], key: "Del" },
                { title: qsTr("Clipboard History"), desc: qsTr("Browse & paste copied clips"), icon: "content_paste", mods: ["Super"], key: "V" },
                { title: qsTr("Clear Clipboard Item"), desc: qsTr("Delete selected clip from history"), icon: "delete_sweep", mods: ["Super", "Alt"], key: "V" },
                { title: qsTr("Paste Latest Clip"), desc: qsTr("Direct type latest copied text"), icon: "keyboard_double_arrow_right", mods: ["Ctrl", "Shift", "Alt"], key: "V" },
                { title: qsTr("Emoji Picker"), desc: qsTr("Insert symbols and emojis"), icon: "sentiment_satisfied", mods: ["Super"], key: "." },
                { title: qsTr("Clear Notifications"), desc: qsTr("Dismiss unread notification alerts"), icon: "notifications_off", mods: ["Ctrl", "Alt"], key: "C" }
            ]
        },
        {
            id: "window",
            title: qsTr("Window Management"),
            icon: "crop_square",
            items: [
                { title: qsTr("Close Focused Window"), desc: qsTr("Close active application"), icon: "close", mods: ["Super"], key: "Q" },
                { title: qsTr("Toggle Fullscreen"), desc: qsTr("Maximize window to full screen"), icon: "fullscreen", mods: ["Super"], key: "F" },
                { title: qsTr("Bordered Fullscreen"), desc: qsTr("Maximize window preserving bar"), icon: "aspect_ratio", mods: ["Super", "Alt"], key: "F" },
                { title: qsTr("Toggle Floating"), desc: qsTr("Switch between tiling and float"), icon: "filter_none", mods: ["Super", "Alt"], key: "Space" },
                { title: qsTr("Center Window"), desc: qsTr("Center floating window on screen"), icon: "center_focus_strong", mods: ["Ctrl", "Super"], key: "\\" },
                { title: qsTr("Normalize Window"), desc: qsTr("Reset window to 55×70 ratio"), icon: "crop_free", mods: ["Ctrl", "Super", "Alt"], key: "\\" },
                { title: qsTr("Picture-in-Picture (PiP)"), desc: qsTr("Pin floating PiP window to corner"), icon: "picture_in_picture_alt", mods: ["Super", "Alt"], key: "\\" },
                { title: qsTr("Pin to All Desktops"), desc: qsTr("Keep window sticky on all workspaces"), icon: "push_pin", mods: ["Super"], key: "P" },
                { title: qsTr("Cycle Windows"), desc: qsTr("Switch between recent windows"), icon: "sync_alt", mods: ["Alt"], key: "Tab" },
                { title: qsTr("Reverse Cycle Windows"), desc: qsTr("Switch windows backwards"), icon: "history", mods: ["Shift", "Alt"], key: "Tab" },
                { title: qsTr("Focus Window (Left / Right)"), desc: qsTr("Move focus to adjacent window"), icon: "arrow_back", mods: ["Super"], key: "← / →" },
                { title: qsTr("Focus Window (Up / Down)"), desc: qsTr("Move focus to adjacent window"), icon: "arrow_upward", mods: ["Super"], key: "↑ / ↓" },
                { title: qsTr("Swap Window Direction"), desc: qsTr("Swap window position in layout"), icon: "swap_horiz", mods: ["Super", "Shift"], key: "Arrows" },
                { title: qsTr("Resize Window Width"), desc: qsTr("Grow or shrink width (-10/+10)"), icon: "straighten", mods: ["Super"], key: "- / =" },
                { title: qsTr("Resize Window Height"), desc: qsTr("Grow or shrink height (-10/+10)"), icon: "height", mods: ["Super", "Shift"], key: "- / =" },
                { title: qsTr("Interactive Move"), desc: qsTr("Drag floating or tiled window"), icon: "open_with", mods: ["Super"], key: "LMB" },
                { title: qsTr("Interactive Resize"), desc: qsTr("Drag window border to resize"), icon: "pinch", mods: ["Super"], key: "RMB" },
                { title: qsTr("Toggle Window Group"), desc: qsTr("Group windows into tabbed group"), icon: "tab", mods: ["Super"], key: "," }
            ]
        },
        {
            id: "workspace",
            title: qsTr("Workspaces"),
            icon: "view_carousel",
            items: [
                { title: qsTr("Switch Workspace 1–10"), desc: qsTr("Jump to workspace number"), icon: "looks_one", mods: ["Super"], key: "1 – 9, 0" },
                { title: qsTr("Move Window to Workspace"), desc: qsTr("Send window to workspace 1–10"), icon: "drive_file_move", mods: ["Super", "Shift"], key: "1 – 9, 0" },
                { title: qsTr("Switch Workspace Group"), desc: qsTr("Jump between monitor groups"), icon: "grid_view", mods: ["Ctrl", "Super"], key: "1 – 9, 0" },
                { title: qsTr("Move to Workspace Group"), desc: qsTr("Transfer window across groups"), icon: "move_up", mods: ["Ctrl", "Super", "Alt"], key: "1 – 9, 0" },
                { title: qsTr("Next / Prev Workspace"), desc: qsTr("Scroll through virtual desktops"), icon: "swipe", mods: ["Super"], key: "Scroll" },
                { title: qsTr("Next / Prev Group (+10)"), desc: qsTr("Step workspace group by 10"), icon: "fast_forward", mods: ["Ctrl", "Super"], key: "Scroll" },
                { title: qsTr("Move Window to Adjacent"), desc: qsTr("Shift window to next workspace"), icon: "arrow_forward", mods: ["Super", "Alt"], key: "Scroll" },
                { title: qsTr("Toggle Special Scratchpad"), desc: qsTr("Show or hide overlay scratchpad"), icon: "layers", mods: ["Super"], key: "S" },
                { title: qsTr("Move Window to Scratchpad"), desc: qsTr("Send active window to scratchpad"), icon: "archive", mods: ["Super", "Alt"], key: "S" },
                { title: qsTr("Music Workspace"), desc: qsTr("Toggle dedicated music workspace"), icon: "music_note", mods: ["Super"], key: "M" },
                { title: qsTr("Communication Workspace"), desc: qsTr("Toggle chat and messaging apps"), icon: "chat", mods: ["Super"], key: "D" },
                { title: qsTr("Tasks & Todo Workspace"), desc: qsTr("Toggle dedicated todo workspace"), icon: "task_alt", mods: ["Super"], key: "R" }
            ]
        },
        {
            id: "apps",
            title: qsTr("Applications"),
            icon: "launch",
            items: [
                { title: qsTr("Terminal Emulator"), desc: qsTr("Launch default Kitty GPU terminal"), icon: "terminal", mods: ["Super"], key: "T" },
                { title: qsTr("Web Browser"), desc: qsTr("Launch Mozilla Firefox browser"), icon: "public", mods: ["Super"], key: "B" },
                { title: qsTr("Code Editor"), desc: qsTr("Open development environment"), icon: "code", mods: ["Super"], key: "C" },
                { title: qsTr("File Manager (Dolphin)"), desc: qsTr("Open primary file manager"), icon: "folder_open", mods: ["Super"], key: "E" },
                { title: qsTr("Secondary File Explorer"), desc: qsTr("Launch Nemo file browser"), icon: "folder", mods: ["Super", "Alt"], key: "E" },
                { title: qsTr("GitHub Desktop"), desc: qsTr("Open Git repository client"), icon: "source", mods: ["Super"], key: "G" },
                { title: qsTr("Task Manager (Qps)"), desc: qsTr("Inspect system processes & CPU"), icon: "analytics", mods: ["Ctrl", "Alt"], key: "Esc" },
                { title: qsTr("System Monitor Workspace"), desc: qsTr("Fullscreen Btop resource monitor"), icon: "monitoring", mods: ["Ctrl", "Shift"], key: "Esc" },
                { title: qsTr("Audio Volume Mixer"), desc: qsTr("Open Pavucontrol sound manager"), icon: "volume_up", mods: ["Ctrl", "Alt"], key: "V" },
                { title: qsTr("Audio Equalizer"), desc: qsTr("Configure EasyEffects sound DSP"), icon: "graphic_eq", mods: ["Ctrl", "Alt"], key: "E" },
                { title: qsTr("Text Editor"), desc: qsTr("Launch Xed lightweight editor"), icon: "edit_note", mods: ["Super"], key: "J" },
                { title: qsTr("Restart Olvex Shell"), desc: qsTr("Hot-reload shell and components"), icon: "restart_alt", mods: ["Ctrl", "Super", "Alt"], key: "R" },
                { title: qsTr("Terminate Olvex Shell"), desc: qsTr("Force kill running shell daemon"), icon: "power_settings_new", mods: ["Ctrl", "Super", "Shift"], key: "R" },
                { title: qsTr("Test Notification"), desc: qsTr("Trigger test desktop toast"), icon: "notifications", mods: ["Super", "Alt"], key: "F12" }
            ]
        },
        {
            id: "media",
            title: qsTr("Media & System"),
            icon: "tune",
            items: [
                { title: qsTr("Screenshot Fullscreen"), desc: qsTr("Capture entire desktop to file"), icon: "screenshot", mods: [], key: "Print" },
                { title: qsTr("Screenshot Region"), desc: qsTr("Freeze screen & snip region"), icon: "crop", mods: ["Super", "Shift"], key: "S" },
                { title: qsTr("Direct Snip Region"), desc: qsTr("Immediate interactive screen snip"), icon: "crop_free", mods: ["Super", "Shift", "Alt"], key: "S" },
                { title: qsTr("Window Screenshot"), desc: qsTr("Capture currently focused window"), icon: "photo_camera", mods: ["Alt"], key: "Print" },
                { title: qsTr("Screen Recording (Sound)"), desc: qsTr("Record desktop video with audio"), icon: "videocam", mods: ["Super", "Alt"], key: "R" },
                { title: qsTr("Screen Recording (Region)"), desc: qsTr("Record selected region video"), icon: "video_camera_back", mods: ["Super", "Shift", "Alt"], key: "R" },
                { title: qsTr("Toggle Recording"), desc: qsTr("Start or stop active recording"), icon: "radio_button_checked", mods: ["Ctrl", "Alt"], key: "R" },
                { title: qsTr("Color Picker"), desc: qsTr("Sample pixel color to clipboard"), icon: "colorize", mods: ["Super", "Shift"], key: "C" },
                { title: qsTr("Volume Raise (+5%)"), desc: qsTr("Increase default output volume"), icon: "volume_up", mods: [], key: "Vol Up" },
                { title: qsTr("Volume Lower (-5%)"), desc: qsTr("Decrease default output volume"), icon: "volume_down", mods: [], key: "Vol Down" },
                { title: qsTr("Volume Mute Toggle"), desc: qsTr("Mute or unmute speaker output"), icon: "volume_off", mods: ["Super", "Shift"], key: "M" },
                { title: qsTr("Microphone Mute"), desc: qsTr("Toggle mic input hardware mute"), icon: "mic_off", mods: [], key: "Mic Mute" },
                { title: qsTr("Media Play / Pause"), desc: qsTr("Control active media playback"), icon: "play_arrow", mods: ["Ctrl", "Super"], key: "Space" },
                { title: qsTr("Media Next Track"), desc: qsTr("Skip to next audio track"), icon: "skip_next", mods: ["Ctrl", "Super"], key: "=" }
            ]
        }
    ]

    readonly property var categoryList: [
        { id: "all", title: qsTr("All"), icon: "grid_view", count: 72 },
        { id: "olvex", title: qsTr("Olvex Shell"), icon: "desktop_windows", count: 14 },
        { id: "window", title: qsTr("Window Tiling"), icon: "crop_square", count: 18 },
        { id: "workspace", title: qsTr("Workspaces"), icon: "view_carousel", count: 12 },
        { id: "apps", title: qsTr("Applications"), icon: "launch", count: 14 },
        { id: "media", title: qsTr("Media & System"), icon: "tune", count: 14 }
    ]

    property var sectionItemMap: ({})

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
                    const inDesc = item.desc && item.desc.toLowerCase().indexOf(q) !== -1;
                    const inKey = item.key.toLowerCase().indexOf(q) !== -1;
                    const inMods = item.mods.some(m => m.toLowerCase().indexOf(q) !== -1);
                    if (inTitle || inDesc || inKey || inMods) {
                        matchedItems.push(item);
                    }
                }
            }

            if (matchedItems.length > 0) {
                results.push({
                    id: sec.id,
                    title: sec.title,
                    icon: sec.icon,
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
            const targetY = Math.min(Math.max(0, targetItem.y - 6), maxScroll);
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
        duration: Tokens.anim.durations.normal || 280
        easing.type: Easing.OutCubic
        onFinished: {
            root.isProgrammaticScroll = false;
        }
    }

    // ── Glass Background Surface (Zero radius: Hyprland handles window corner clipping) ──
    StyledRect {
        anchors.fill: parent
        radius: 0
        color: Colours.shellTint
        border.width: 0

        Rectangle {
            anchors.fill: parent
            color: Colours.palette.m3primary
            opacity: 0.035
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // ── Clean Header Bar ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 64

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                spacing: 12

                // Header Title + Global Count Badge
                RowLayout {
                    spacing: 10
                    Layout.alignment: Qt.AlignVCenter

                    StyledText {
                        text: qsTr("Keyboard Shortcuts")
                        font.weight: Font.DemiBold
                        textPointSize: Tokens.font.size.large
                        color: Colours.palette.m3onSurface
                    }

                    StyledRect {
                        implicitHeight: 22
                        implicitWidth: totalBadgeTxt.implicitWidth + 14
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3surfaceContainerHigh
                        border.width: 0

                        StyledText {
                            id: totalBadgeTxt
                            anchors.centerIn: parent
                            text: qsTr("%1 Total").arg(root.getTotalFilteredCount())
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.smaller
                            color: Colours.palette.m3primary
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Right Actions: Expandable Search Pill + Close Button
                RowLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    // Expandable Search Pill (40px → 240px)
                    StyledRect {
                        id: searchPill

                        property bool searchExpanded: false
                        readonly property bool searchActive: searchExpanded || (searchInput && (searchInput.text.length > 0 || searchInput.activeFocus))

                        implicitWidth: searchActive ? 240 : 40
                        implicitHeight: 40
                        radius: Tokens.rounding.full
                        clip: true

                        color: searchActive
                            ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                            : (searchHover.hovered ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 1) : Colours.palette.m3surfaceContainerHigh)
                        border.width: 0

                        Behavior on implicitWidth { Anim { type: Anim.DefaultSpatial } }
                        Behavior on color { CAnim {} }

                        HoverHandler {
                            id: searchHover
                            cursorShape: searchPill.searchActive ? Qt.IBeamCursor : Qt.PointingHandCursor
                        }

                        MouseArea {
                            anchors.fill: parent
                            visible: !searchPill.searchActive
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchPill.searchExpanded = true;
                                Qt.callLater(() => searchInput.forceActiveFocus());
                            }
                        }

                        MaterialIcon {
                            id: searchIcon
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: searchPill.searchActive ? 12 : Math.round((40 - searchIcon.implicitWidth) / 2)
                            text: "search"
                            iconPointSize: 18
                            color: searchInput.activeFocus ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant

                            Behavior on anchors.leftMargin { Anim { type: Anim.DefaultSpatial } }
                            Behavior on color { CAnim {} }
                        }

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
                                font.pixelSize: Math.max(12, Math.round(Tokens.font.size.normal * 96 / 72))
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
                                text: qsTr("Search shortcuts…")
                                color: Colours.palette.m3outline
                                font.family: Tokens.font.family.sans
                                font.pixelSize: Math.max(12, Math.round(Tokens.font.size.normal * 96 / 72))
                                visible: searchInput.text.length === 0 && !searchInput.inputMethodComposing
                                opacity: searchInput.text.length === 0 ? 1.0 : 0
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
                            opacity: searchPill.searchActive && searchInput.text.length > 0 ? 1.0 : 0.0
                            visible: opacity > 0.01

                            Behavior on color { CAnim {} }
                            Behavior on opacity { Anim { type: Anim.FastEffects } }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                color: Colours.palette.m3onSurfaceVariant
                                iconPointSize: 14
                            }

                            MouseArea {
                                id: clearBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = "";
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }

                    // Circular Close Button
                    StyledRect {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: Tokens.rounding.full
                        color: closeBtnMa.pressed ? Qt.alpha(Colours.palette.m3onSurface, 0.16) :
                               closeBtnMa.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.10) :
                               Colours.palette.m3surfaceContainerHigh
                        border.width: 0

                        Behavior on color { CAnim {} }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            iconPointSize: 18
                            color: Colours.palette.m3onSurface
                        }

                        MouseArea {
                            id: closeBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested()
                        }
                    }
                }
            }
        }

        // ── Horizontally Scrollable Category Bar (With Safe Margins & Jump-on-Click) ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 42

            Flickable {
                id: catFlickable
                anchors.fill: parent
                contentWidth: chipsLayout.implicitWidth + 44
                contentHeight: height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                clip: true

                RowLayout {
                    id: chipsLayout
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    spacing: 8

                    Repeater {
                        model: root.categoryList

                        delegate: StyledRect {
                            id: catChip
                            required property var modelData

                            readonly property bool isSelected: root.activeCategory === modelData.id
                            implicitHeight: 34
                            implicitWidth: chipRow.implicitWidth + 20
                            radius: Tokens.rounding.full
                            border.width: 0

                            color: isSelected
                                ? Colours.palette.m3primary
                                : (chipMouse.containsMouse ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 2) : Colours.palette.m3surfaceContainer)

                            Behavior on color { CAnim {} }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialIcon {
                                    text: catChip.modelData.icon
                                    iconPointSize: 15
                                    color: catChip.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                    Behavior on color { CAnim {} }
                                }

                                StyledText {
                                    text: catChip.modelData.title
                                    font.weight: catChip.isSelected ? Font.DemiBold : Font.Normal
                                    textPointSize: Tokens.font.size.smaller
                                    color: catChip.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                    Behavior on color { CAnim {} }
                                }

                                // Count badge on each category chip
                                StyledRect {
                                    implicitHeight: 18
                                    implicitWidth: chipCntTxt.implicitWidth + 8
                                    radius: Tokens.rounding.full
                                    color: catChip.isSelected ? Qt.alpha(Colours.palette.m3onPrimary, 0.22) : Colours.palette.m3surfaceContainerHigh
                                    border.width: 0

                                    StyledText {
                                        id: chipCntTxt
                                        anchors.centerIn: parent
                                        text: String(catChip.modelData.count)
                                        font.weight: Font.Bold
                                        textPointSize: Tokens.font.size.smaller - 2
                                        color: catChip.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3outline
                                    }
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.scrollToCategory(catChip.modelData.id);
                                    const chipX = catChip.x;
                                    const chipW = catChip.width;
                                    if (chipX < catFlickable.contentX) {
                                        catFlickable.contentX = Math.max(0, chipX - 22);
                                    } else if (chipX + chipW > catFlickable.contentX + catFlickable.width) {
                                        catFlickable.contentX = Math.min(catFlickable.contentWidth - catFlickable.width, chipX + chipW - catFlickable.width + 22);
                                    }
                                }
                            }
                        }
                    }

                    // Spacer on the right to guarantee 22px margin
                    Item {
                        implicitWidth: 14
                        Layout.preferredHeight: 1
                    }
                }
            }
        }

        // ── Grouped Content Area with Smooth Section Scrolling ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            StyledFlickable {
                id: bentoFlickable
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                contentWidth: width
                contentHeight: groupsColumn.implicitHeight + 20
                visible: root.getTotalFilteredCount() > 0

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: bentoFlickable
                }

                onContentYChanged: {
                    if (root.isProgrammaticScroll || contentY <= 20) {
                        if (contentY <= 20 && !root.isProgrammaticScroll) {
                            root.activeCategory = "all";
                        }
                        return;
                    }
                    // Auto-update activeCategory chip on user manual scroll
                    const groups = root.getFilteredGroups();
                    let currentActive = "all";
                    for (let i = groups.length - 1; i >= 0; i--) {
                        const it = root.sectionItemMap[groups[i].id];
                        if (it && it.y <= contentY + 60) {
                            currentActive = groups[i].id;
                            break;
                        }
                    }
                    if (root.activeCategory !== currentActive) {
                        root.activeCategory = currentActive;
                    }
                }

                ColumnLayout {
                    id: groupsColumn
                    width: bentoFlickable.width - (bentoFlickable.showScrollBar ? 14 : 0)
                    spacing: 22

                    Repeater {
                        model: root.getFilteredGroups()

                        delegate: ColumnLayout {
                            id: secGroup
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 8

                            Component.onCompleted: {
                                root.sectionItemMap[secGroup.modelData.id] = secGroup;
                            }
                            Component.onDestruction: {
                                delete root.sectionItemMap[secGroup.modelData.id];
                            }

                            // ── Section Header ──
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                MaterialIcon {
                                    text: secGroup.modelData.icon
                                    iconPointSize: 18
                                    color: Colours.palette.m3primary
                                }

                                StyledText {
                                    text: secGroup.modelData.title
                                    font.weight: Font.DemiBold
                                    textPointSize: Tokens.font.size.normal
                                    color: Colours.palette.m3primary
                                }

                                StyledRect {
                                    implicitHeight: 20
                                    implicitWidth: cntTxt.implicitWidth + 12
                                    radius: Tokens.rounding.full
                                    color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                                    border.width: 0

                                    StyledText {
                                        id: cntTxt
                                        anchors.centerIn: parent
                                        text: String(secGroup.modelData.items.length)
                                        font.weight: Font.DemiBold
                                        textPointSize: Tokens.font.size.smaller - 1
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            // ── Column of Rounded Shortcut Cards ──
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: secGroup.modelData.items

                                    delegate: StyledRect {
                                        id: rowCard
                                        required property var modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        implicitHeight: 52
                                        // Prominently rounded item card corners (Tokens.rounding.large = 16px)
                                        radius: Tokens.rounding.large
                                        border.width: 0

                                        color: rowMouse.containsMouse
                                            ? Colours.layer(Colours.palette.m3surfaceContainer, 2)
                                            : Colours.palette.m3surfaceContainer

                                        Behavior on color { CAnim {} }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 14
                                            spacing: 12

                                            // 32×32 Category Avatar Badge
                                            StyledRect {
                                                implicitWidth: 32
                                                implicitHeight: 32
                                                radius: Tokens.rounding.full
                                                color: Colours.palette.m3secondaryContainer
                                                border.width: 0

                                                MaterialIcon {
                                                    anchors.centerIn: parent
                                                    text: rowCard.modelData.icon || "keyboard"
                                                    color: Colours.palette.m3onSecondaryContainer
                                                    iconPointSize: 16
                                                }
                                            }

                                            // Title & Context Description
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                StyledText {
                                                    text: rowCard.modelData.title
                                                    font.weight: Font.Medium
                                                    textPointSize: Tokens.font.size.normal
                                                    color: Colours.palette.m3onSurface
                                                }

                                                StyledText {
                                                    text: "·  " + rowCard.modelData.desc
                                                    textPointSize: Tokens.font.size.smaller
                                                    color: Colours.palette.m3onSurfaceVariant
                                                    opacity: 0.75
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }

                                            // Keycaps: Modifiers (Secondary) + Trigger Key (Primary)
                                            RowLayout {
                                                spacing: 5
                                                Layout.alignment: Qt.AlignVCenter

                                                Repeater {
                                                    model: rowCard.modelData.mods

                                                    delegate: StyledRect {
                                                        id: modPill
                                                        required property string modelData
                                                        implicitHeight: 26
                                                        implicitWidth: modLabel.implicitWidth + 14
                                                        radius: Tokens.rounding.small
                                                        color: Colours.palette.m3secondaryContainer
                                                        border.width: 0

                                                        StyledText {
                                                            id: modLabel
                                                            anchors.centerIn: parent
                                                            text: modPill.modelData
                                                            color: Colours.palette.m3onSecondaryContainer
                                                            font.weight: Font.Bold
                                                            textPointSize: Tokens.font.size.smaller - 1
                                                        }
                                                    }
                                                }

                                                StyledText {
                                                    visible: rowCard.modelData.mods && rowCard.modelData.mods.length > 0
                                                    text: "+"
                                                    font.weight: Font.Bold
                                                    textPointSize: Tokens.font.size.smaller - 1
                                                    color: Colours.palette.m3outline
                                                }

                                                StyledRect {
                                                    implicitHeight: 26
                                                    implicitWidth: Math.max(26, triggerLabel.implicitWidth + 14)
                                                    radius: Tokens.rounding.small
                                                    color: Colours.palette.m3primaryContainer
                                                    border.width: 0

                                                    StyledText {
                                                        id: triggerLabel
                                                        anchors.centerIn: parent
                                                        text: rowCard.modelData.key
                                                        color: Colours.palette.m3onPrimaryContainer
                                                        font.weight: Font.Bold
                                                        textPointSize: Tokens.font.size.smaller - 1
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
                spacing: 10

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    iconPointSize: 36
                    text: "search_off"
                    color: Colours.palette.m3outline
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No shortcuts found")
                    font.weight: Font.DemiBold
                    textPointSize: Tokens.font.size.normal
                    color: Colours.palette.m3onSurface
                }

                StyledRect {
                    Layout.alignment: Qt.AlignHCenter
                    implicitHeight: 32
                    implicitWidth: resetTxt.implicitWidth + 20
                    radius: Tokens.rounding.full
                    color: resetMa.containsMouse ? Colours.layer(Colours.palette.m3secondaryContainer, 1) : Colours.palette.m3secondaryContainer
                    border.width: 0

                    StyledText {
                        id: resetTxt
                        anchors.centerIn: parent
                        text: qsTr("Reset search")
                        font.weight: Font.DemiBold
                        textPointSize: Tokens.font.size.smaller
                        color: Colours.palette.m3onSecondaryContainer
                    }

                    MouseArea {
                        id: resetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.searchQuery = "";
                            searchInput.text = "";
                            root.activeCategory = "all";
                        }
                    }
                }
            }
        }

        // ── Minimal Footer Status ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 38

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22

                StyledText {
                    text: qsTr("Esc to close  •  Super + / to toggle")
                    textPointSize: Tokens.font.size.smaller
                    color: Colours.palette.m3onSurfaceVariant
                    opacity: 0.7
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: qsTr("%1 of 72 shortcuts active").arg(root.getTotalFilteredCount())
                    textPointSize: Tokens.font.size.smaller
                    color: Colours.palette.m3onSurfaceVariant
                    opacity: 0.7
                }
            }
        }
    }
}
