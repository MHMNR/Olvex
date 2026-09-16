import ".."
import "."
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import "../../../components/effects"
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Olvex
import Olvex.Config
import qs.services
import qs.utils

Item {
    id: root

    property var model: []
    property int currentIndex: 0
    property bool menuOnTop: false
    property real menuMaxHeight: 400
    property bool expanded: false
    property string searchQuery: ""
    property string activeCategory: "all"

    signal selected(int index)

    readonly property int count: model ? model.length : 0
    readonly property bool animating: morphState !== "closed" || closeGrace.running
    property string morphState: "closed" // "closed", "open"

    readonly property int morphDuration: (Tokens && Tokens.anim && Tokens.anim.durations) ? Tokens.anim.durations.expressiveDefaultSpatial : 450
    readonly property var morphEasing: (Tokens && Tokens.anim) ? Tokens.anim.expressiveDefaultSpatial : Easing.OutCubic

    implicitWidth: face.implicitWidth
    implicitHeight: face.implicitHeight

    readonly property var categories: [
        { id: "all", label: qsTr("All") },
        { id: "distros", label: qsTr("Distros") },
        { id: "os", label: qsTr("OS") },
        { id: "tools", label: qsTr("Tools") },
        { id: "icons", label: qsTr("Icons") }
    ]

    function categoryOf(val, item) {
        if (item && item.category) return item.category;
        const v = (val || "").toLowerCase();
        if (v === "apple" || v === "windows" || v === "android") return "os";
        if (v === "hyprland" || v === "wayland" || v === "terminal" || v === "code" ||
            v === "git" || v === "github" || v === "docker" || v === "neovim" ||
            v === "rust" || v === "python" || v === "flathub" || v === "qt") return "tools";
        if (v === "rocket" || v === "fire" || v === "sparkles" || v === "lightning" ||
            v === "heart" || v === "star" || v === "coffee" || v === "diamond" ||
            v === "ghost" || v === "music" || v === "gamepad") return "icons";
        return "distros";
    }

    readonly property var filteredModel: {
        if (!root.model) return [];
        const q = (root.searchQuery || "").trim().toLowerCase();
        const cat = root.activeCategory || "all";

        let res = [];
        for (let i = 0; i < root.model.length; i++) {
            const raw = root.model[i];
            const label = root.displayName(raw);
            const val = (raw && raw.value !== undefined) ? String(raw.value) : String(raw);
            const itemCat = root.categoryOf(val, raw);

            if (cat !== "all" && itemCat !== cat) continue;

            if (q) {
                const matchLabel = label.toLowerCase().includes(q);
                const matchVal = val.toLowerCase().includes(q);
                if (!matchLabel && !matchVal) continue;
            }

            res.push({ val: raw, orig: i, label: label, value: val, category: itemCat });
        }
        return res;
    }

    // ── Safe overlay retrieval ──
    readonly property Item overlayParent: {
        const win = QsWindow.window;
        if (win) {
            if (win.interactionWrapper) return win.interactionWrapper;
            return win.contentItem ?? null;
        }
        let p = root;
        while (p && p.parent) p = p.parent;
        return p;
    }

    function displayName(v) {
        if (v === undefined || v === null || v === "") return qsTr("Auto");
        if (v.label !== undefined) return v.label;
        return String(v);
    }

    function pick(i) {
        if (i < 0 || i >= root.count) return;
        if (root.currentIndex !== i) root.currentIndex = i;
        root.selected(i);
        root.expanded = false;
        root.morphState = "closed";
        closeGrace.restart();
    }

    // Tracker to ensure we know EXACTLY where the button is in the overlay
    TransformWatcher {
        id: watcher
        a: root.overlayParent
        b: root
    }

    // Geometric calculations based on the watcher
    readonly property point mappedPos: {
        watcher.transform;
        if (!root.overlayParent) return Qt.point(0, 0);
        return root.mapToItem(root.overlayParent, 0, 0);
    }
    readonly property real currentX: mappedPos.x
    readonly property real currentY: mappedPos.y
    readonly property real startW: root.implicitWidth
    readonly property real startH: 36
    
    readonly property real targetW: Math.min(500, (root.overlayParent ? root.overlayParent.width - 32 : 500))
    readonly property real targetH: Math.min(root.menuMaxHeight, 380)

    readonly property real targetX: {
        const rawX = currentX + startW - targetW;
        const maxOverlayW = root.overlayParent ? root.overlayParent.width : 1920;
        return Math.max(16, Math.min(rawX, maxOverlayW - targetW - 16));
    }

    readonly property real targetY: {
        const belowY = currentY + startH + Tokens.spacing.small;
        const aboveY = currentY - targetH - Tokens.spacing.small;
        const maxOverlayH = root.overlayParent ? root.overlayParent.height : 1080;
        return root.menuOnTop 
            ? (aboveY < 16 ? belowY : aboveY)
            : ((belowY + targetH > maxOverlayH - 16) ? aboveY : belowY);
    }

    // ── Static Button (Placeholder in Layout) ──
    StyledRect {
        id: face
        anchors.fill: parent
        implicitWidth: Math.max(faceRow.implicitWidth + Tokens.padding.normal * 2 + 4, 120)
        implicitHeight: 36
        radius: height / 2
        color: Colours.palette.m3primary
        opacity: (root.expanded || closeGrace.running) ? 0 : 1
        visible: opacity > 0

        StateLayer {
            radius: parent.radius
            color: Colours.palette.m3surface
            onClicked: {
                root.searchQuery = "";
                root.activeCategory = "all";
                root.expanded = true;
                root.morphState = "open";
            }
        }

        RowLayout {
            id: faceRow
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            readonly property var currentItem: (root.model && root.currentIndex >= 0 && root.currentIndex < root.model.length) ? root.model[root.currentIndex] : null
            readonly property string currentValue: currentItem ? ((currentItem.value !== undefined) ? String(currentItem.value) : String(currentItem)) : ""

            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter

                Logo {
                    visible: faceRow.currentValue === "olvex"
                    anchors.centerIn: parent
                    implicitWidth: 18
                    implicitHeight: 15
                    topColour: Colours.palette.m3surface
                    bottomColour: Colours.palette.m3surface
                }

                Text {
                    id: faceGlyphText
                    visible: faceRow.currentValue !== "olvex"
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: (typeof CUtils !== "undefined" && typeof CUtils.glyphHOffset === "function") ? CUtils.glyphHOffset(text, font.pixelSize, font.family) : 0.0
                    anchors.verticalCenterOffset: (typeof CUtils !== "undefined" && typeof CUtils.glyphVOffset === "function") ? CUtils.glyphVOffset(text, font.pixelSize, font.family) : 0.0
                    text: {
                        const cur = (root.model && root.currentIndex >= 0 && root.currentIndex < root.model.length) ? root.model[root.currentIndex] : null;
                        const v = cur ? ((cur.value !== undefined) ? String(cur.value) : String(cur)) : "";
                        if (!v || v === "auto") return SysInfo.detectedOsGlyph || "\uf31a";
                        if (typeof CUtils !== "undefined" && typeof CUtils.distroGlyph === "function") {
                            return CUtils.distroGlyph(v, [], v);
                        }
                        return "\uf31a";
                    }
                    color: Colours.palette.m3surface
                    font.family: Tokens.font.family.mono
                    font.pixelSize: 16
                    renderType: Text.QtRendering
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            StyledText {
                Layout.preferredWidth: Math.min(implicitWidth, 150)
                Layout.alignment: Qt.AlignVCenter
                text: root.displayName(faceRow.currentItem)
                color: Colours.palette.m3surface
                textPointSize: Tokens.font.size.small
                font.weight: Font.Medium
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: "expand_more"
                color: Colours.palette.m3surface
                iconPointSize: Tokens.font.size.normal
                opacity: 0.85
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // ── Overlay Elements ──
    MouseArea {
        id: dismissArea
        parent: root.overlayParent
        anchors.fill: parent
        visible: root.expanded
        onClicked: {
            root.expanded = false;
            root.morphState = "closed";
            closeGrace.restart();
        }
        onWheel: event => event.accepted = true
    }

    // True M3 Expressive Shared Element Container Morph
    Rectangle {
        id: morphContainer
        parent: root.overlayParent
        visible: root.expanded || closeGrace.running
        z: 9999
        clip: true

        Timer {
            id: closeGrace
            interval: root.morphDuration + 60
        }

        // M3 Physics Bounds - Smooth Emphasized Deceleration Curve
        x: root.morphState === "open" ? root.targetX : root.currentX
        y: root.morphState === "open" ? root.targetY : root.currentY
        width: root.morphState === "open" ? root.targetW : root.startW
        height: root.morphState === "open" ? root.targetH : root.startH
        radius: root.morphState === "open" ? Tokens.rounding.large : (root.startH / 2)

        Behavior on x { Anim { type: Anim.DefaultSpatial } }
        Behavior on y { Anim { type: Anim.DefaultSpatial } }
        Behavior on width { Anim { type: Anim.DefaultSpatial } }
        Behavior on height { Anim { type: Anim.DefaultSpatial } }
        Behavior on radius { Anim { type: Anim.DefaultSpatial } }

        // Background Crossfade
        color: root.morphState === "open" ? Colours.palette.m3surfaceContainerLow : Colours.palette.m3primary
        Behavior on color { ColorAnimation { duration: root.morphDuration; easing: root.morphEasing } }

        // ── Outgoing Button Face (Fades out smoothly when opening) ──
        Item {
            anchors.top: parent.top
            anchors.left: parent.left
            width: root.startW
            height: root.startH
            opacity: root.morphState === "open" ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            RowLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter

                    Logo {
                        visible: faceRow.currentValue === "olvex"
                        anchors.centerIn: parent
                        implicitWidth: 18
                        implicitHeight: 15
                        topColour: Colours.palette.m3surface
                        bottomColour: Colours.palette.m3surface
                    }

                    Text {
                        id: outgoingGlyph
                        visible: faceRow.currentValue !== "olvex"
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: (typeof CUtils !== "undefined" && typeof CUtils.glyphHOffset === "function") ? CUtils.glyphHOffset(text, font.pixelSize, font.family) : 0.0
                        anchors.verticalCenterOffset: (typeof CUtils !== "undefined" && typeof CUtils.glyphVOffset === "function") ? CUtils.glyphVOffset(text, font.pixelSize, font.family) : 0.0
                        text: {
                            const cur = (root.model && root.currentIndex >= 0 && root.currentIndex < root.model.length) ? root.model[root.currentIndex] : null;
                            const v = cur ? ((cur.value !== undefined) ? String(cur.value) : String(cur)) : "";
                            if (!v || v === "auto") return SysInfo.detectedOsGlyph || "\uf31a";
                            if (typeof CUtils !== "undefined" && typeof CUtils.distroGlyph === "function") {
                                return CUtils.distroGlyph(v, [], v);
                            }
                            return "\uf31a";
                        }
                        color: Colours.palette.m3surface
                        font.family: Tokens.font.family.mono
                        font.pixelSize: 16
                        renderType: Text.QtRendering
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                StyledText {
                    Layout.preferredWidth: Math.min(implicitWidth, 150)
                    Layout.alignment: Qt.AlignVCenter
                    text: root.displayName(faceRow.currentItem)
                    color: Colours.palette.m3surface
                    textPointSize: Tokens.font.size.small
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: "expand_more"
                    color: Colours.palette.m3surface
                    iconPointSize: Tokens.font.size.normal
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // ── Incoming Landscape Grid Content (Fades in smoothly when opening) ──
        Item {
            anchors.fill: parent
            anchors.margins: Tokens.padding.normal
            opacity: root.morphState === "open" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.small

                // Search & Filter Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    // Search input
                    Rectangle {
                        Layout.preferredWidth: 180
                        Layout.preferredHeight: 32
                        radius: Tokens.rounding.normal
                        color: Colours.tPalette.m3surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 4

                            MaterialIcon {
                                text: "search"
                                iconPointSize: Tokens.font.size.small
                                color: searchInput.activeFocus ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: Tokens.font.size.small
                                font.family: Tokens.font.family.sans
                                color: Colours.palette.m3onSurface
                                clip: true
                                selectByMouse: true
                                selectionColor: Colours.palette.m3primary
                                selectedTextColor: Colours.palette.m3onPrimary

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: !searchInput.text && !searchInput.activeFocus
                                    text: qsTr("Search...")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.pixelSize: Tokens.font.size.small
                                    font.family: Tokens.font.family.sans
                                }

                                onTextChanged: root.searchQuery = text
                            }

                            MaterialIcon {
                                visible: !!searchInput.text
                                text: "close"
                                iconPointSize: Tokens.font.size.small * 0.9
                                color: Colours.palette.m3onSurfaceVariant

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: searchInput.text = ""
                                }
                            }
                        }
                    }

                    // Category Chips
                    Row {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        spacing: 4

                        Repeater {
                            model: root.categories

                            Rectangle {
                                id: chip
                                required property var modelData
                                readonly property bool isSelected: root.activeCategory === modelData.id
                                property bool hovered: chipMouse.containsMouse

                                width: chipText.implicitWidth + 14
                                height: 28
                                radius: Tokens.rounding.full
                                color: isSelected ? Colours.palette.m3primary : (hovered ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 0.9) : Colours.tPalette.m3surfaceContainer)

                                Behavior on color { ColorAnimation { duration: 150 } }

                                StyledText {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: chip.modelData.label
                                    color: chip.isSelected ? Colours.palette.m3onPrimary : (chip.hovered ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant)
                                    font.weight: chip.isSelected ? Font.DemiBold : Font.Normal
                                    textPointSize: Tokens.font.size.small * 0.9
                                }

                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeCategory = chip.modelData.id
                                }
                            }
                        }
                    }
                }

                // Grid Area
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    GridView {
                        id: grid
                        anchors.fill: parent
                        clip: true

                        readonly property int minColWidth: 110
                        readonly property int numCols: Math.max(3, Math.floor(width / minColWidth))

                        cellWidth: width / numCols
                        cellHeight: 68

                        model: root.filteredModel

                        StyledScrollBar.vertical: StyledScrollBar {
                            flickable: grid
                        }

                        // Empty State
                        Item {
                            anchors.centerIn: parent
                            visible: root.filteredModel.length === 0
                            width: 160
                            height: 80

                            Column {
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "search_off"
                                    iconPointSize: Tokens.font.size.large
                                    color: Colours.palette.m3onSurfaceVariant
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("No matching logos")
                                    color: Colours.palette.m3onSurfaceVariant
                                    textPointSize: Tokens.font.size.small
                                }
                            }
                        }

                        delegate: Item {
                            id: cell
                            required property var modelData
                            required property int index

                            width: grid.cellWidth
                            height: grid.cellHeight

                            readonly property int origIndex: (modelData && modelData.orig !== undefined) ? modelData.orig : index
                            readonly property string itemVal: (modelData && modelData.value !== undefined) ? modelData.value : ""
                            readonly property string itemLabel: (modelData && modelData.label !== undefined) ? modelData.label : ""
                            readonly property bool isSelected: origIndex === root.currentIndex
                            property bool hovered: cellMouse.containsMouse

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: Tokens.rounding.normal
                                color: cell.isSelected 
                                    ? Colours.layer(Colours.palette.m3primaryContainer, 0.8) 
                                    : (cell.hovered ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 0.95) : Colours.tPalette.m3surfaceContainer)

                                Behavior on color { ColorAnimation { duration: 150 } }

                                // Selected Checkmark Dot
                                Rectangle {
                                    visible: cell.isSelected
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 4
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: Colours.palette.m3primary

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "check"
                                        iconPointSize: 8
                                        color: Colours.palette.m3onPrimary
                                    }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    spacing: 2

                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28

                                        Logo {
                                            visible: cell.itemVal === "olvex"
                                            anchors.centerIn: parent
                                            implicitWidth: 22
                                            implicitHeight: 18
                                            topColour: cell.isSelected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3primary
                                            bottomColour: cell.isSelected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3tertiary
                                        }

                                        Text {
                                            id: cellGlyphText
                                            visible: cell.itemVal !== "olvex"
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: (typeof CUtils !== "undefined" && typeof CUtils.glyphHOffset === "function")
                                                ? CUtils.glyphHOffset(text, font.pixelSize, font.family)
                                                : 0.0
                                            anchors.verticalCenterOffset: (typeof CUtils !== "undefined" && typeof CUtils.glyphVOffset === "function")
                                                ? CUtils.glyphVOffset(text, font.pixelSize, font.family)
                                                : 0.0
                                            text: {
                                                const v = cell.itemVal;
                                                if (!v || v === "auto") {
                                                    return (typeof SysInfo !== "undefined" && SysInfo.detectedOsGlyph) 
                                                        ? SysInfo.detectedOsGlyph 
                                                        : (typeof CUtils !== "undefined" && typeof CUtils.distroGlyph === "function" 
                                                            ? CUtils.distroGlyph(SysInfo.osId, SysInfo.osIdLike, SysInfo.osName) 
                                                            : "\uf31a");
                                                }
                                                if (typeof CUtils !== "undefined" && typeof CUtils.distroGlyph === "function") {
                                                    return CUtils.distroGlyph(v, [], v);
                                                }
                                                return "\uf31a";
                                            }
                                            color: cell.isSelected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3primary
                                            font.family: Tokens.font.family.mono
                                            font.pixelSize: 18
                                            renderType: Text.QtRendering
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: cell.itemLabel
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        font.weight: cell.isSelected ? Font.DemiBold : Font.Normal
                                        color: cell.isSelected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                        textPointSize: Tokens.font.size.small * 0.88
                                    }
                                }

                                MouseArea {
                                    id: cellMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.pick(cell.origIndex)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
