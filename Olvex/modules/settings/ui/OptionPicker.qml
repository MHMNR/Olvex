
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
    property bool alignLeft: false
    property real menuMaxHeight: 320
    property bool expanded: false
    property bool searchable: count > 10
    property string searchQuery: ""

    property var filteredModel: {
        if (!root.model) return [];
        if (!root.searchQuery) {
            let res = [];
            for (let i = 0; i < root.model.length; i++) res.push({ val: root.model[i], orig: i });
            return res;
        }
        const q = root.searchQuery.toLowerCase();
        let res = [];
        for (let i = 0; i < root.model.length; i++) {
            if (root.labelOf(i).toLowerCase().includes(q)) {
                res.push({ val: root.model[i], orig: i });
            }
        }
        return res;
    }

    signal selected(int index)
    signal notInstalledClicked(var item)

    function handleNotInstalled(itemData) {
        root.notInstalledClicked(itemData);
        const name = root.displayName(itemData);
        const pkg = (itemData && itemData.pkg) ? itemData.pkg : String(itemData.id || name).toLowerCase();
        const cmd = pkg.includes("-bin") ? `yay -S ${pkg}` : `sudo pacman -S ${pkg}`;
        if (typeof Toaster !== "undefined" && Toaster.toast) {
            Toaster.toast(qsTr("%1 is not installed").arg(name), qsTr("%1 is not installed · %2").arg(name).arg(cmd), "cloud_download", Toast.Warning);
        }
    }

    readonly property int count: model ? model.length : 0
    readonly property real rowHeight: 36
    readonly property bool animating: morphState !== "closed" || closeGrace.running
    property string morphState: "closed" // "closed", "open"

    readonly property int morphDuration: (Tokens && Tokens.anim && Tokens.anim.durations) ? Tokens.anim.durations.expressiveDefaultSpatial : 450
    readonly property var morphEasing: (Tokens && Tokens.anim) ? Tokens.anim.expressiveDefaultSpatial : Easing.OutCubic

    implicitWidth: face.implicitWidth
    implicitHeight: face.implicitHeight
    width: implicitWidth
    height: implicitHeight

    onVisibleChanged: {
        if (!visible && (root.expanded || root.animating)) {
            root.closePicker();
        }
    }

    // ── Safe overlay retrieval ──
    readonly property Item overlayParent: {
        const win = QsWindow.window;
        if (win) {
            if (win.interactionWrapper) return win.interactionWrapper;
            return win.contentItem ?? null;
        }
        // Fallback if not inside a QsWindow (e.g. standard Qt Window)
        let p = root;
        while (p && p.parent) p = p.parent;
        return p;
    }

    function displayName(v) {
        if (v === undefined || v === null || v === "") return qsTr("Default");
        if (v.label !== undefined) return v.label;
        const s = String(v);
        const known = {
            "tonalspot": "Tonal Spot", "vibrant": "Vibrant",
            "expressive": "Expressive", "fidelity": "Fidelity",
            "content": "Content", "neutral": "Neutral",
            "monochrome": "Monochrome", "auto": "Auto",
            "amd": "AMD", "nvidia": "NVIDIA", "intel": "Intel",
            "mpv": "mpv", "firefox": "Firefox", "vlc": "VLC",
            "spotify": "Spotify", "fade": "Fade", "wipe": "Wipe",
            "disc": "Disc", "stripes": "Stripes", "iris": "Iris",
            "iris bloom": "Iris Bloom", "pixelate": "Pixelate",
            "portal": "Portal", "random": "Random", "none": "None",
            "card": "Card", "minimal": "Minimal", "light": "Light", "dark": "Dark"
        };
        const low = s.toLowerCase();
        if (known[low] !== undefined) return known[low];
        if (s !== low && s !== s.toUpperCase()) return s;
        if (s.indexOf(" ") < 0 && s.indexOf("-") < 0)
            return s.charAt(0).toUpperCase() + s.slice(1);
        return s.split(/[\s_-]+/).map(w => w.length ? (w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()) : w).join(" ");
    }

    function previewOf(v) {
        if (v === undefined || v === null) return "";
        if (v.preview !== undefined) return String(v.preview);
        if (v.icon !== undefined) return String(v.icon);
        return "";
    }

    function isMaterialPreview(v) {
        if (v === undefined || v === null) return false;
        if (v.isMaterial !== undefined) return Boolean(v.isMaterial);
        const p = root.previewOf(v);
        if (!p || p.length === 0) return false;
        const knownMaterial = [
            "star", "local_fire_department", "bolt", "auto_awesome", "rocket_launch",
            "favorite", "terminal", "code", "circle", "videogame_asset", "pacman",
            "sports_esports", "diamond", "brightness_5", "bedtime", "visibility"
        ];
        return knownMaterial.includes(p) || /^[a-z][a-z0-9_]{2,}$/.test(p);
    }

    function isCircledText(t) {
        if (!t || t.length === 0) return false;
        const code = t.charCodeAt(0);
        return (code >= 0x2776 && code <= 0x277F)
            || (code >= 0x2460 && code <= 0x2473)
            || (code >= 0x24EB && code <= 0x24F4)
            || (code >= 0x2780 && code <= 0x2789);
    }

    function labelOf(i) {
        if (!model || i < 0 || i >= model.length) return qsTr("Select\u2026");
        return root.displayName(model[i]);
    }

    property real freezeX: 0
    property real freezeY: 0
    property real freezeW: 0
    property real freezeH: 0

    function closePicker() {
        if (!root.expanded && root.morphState === "closed") return;

        if (searchFieldLoader.item && searchFieldLoader.item.activeFocus) {
            searchFieldLoader.item.focus = false;
        }
        if (list && list.activeFocus) {
            list.focus = false;
        }

        root.expanded = false;
        root.morphState = "closed";
        closeGrace.restart();
    }

    function openPicker() {
        root.freezeX = root.currentX;
        root.freezeY = root.currentY;
        root.freezeW = root.startW;
        root.freezeH = root.startH;
        closeGrace.stop();
        root.searchQuery = "";
        root.expanded = true;
        root.morphState = "open";

        // Align scroll position
        const maxContentY = Math.max(0, (root.count * root.rowHeight) - (root.targetH - Tokens.padding.small * 2));
        const idealContentY = (root.currentIndex * root.rowHeight) - (root.targetH / 2) + (root.rowHeight / 2);
        if (list && list.count > 0) list.contentY = Math.max(0, Math.min(maxContentY, idealContentY));

        if (root.searchable) {
            Qt.callLater(() => {
                if (root.expanded && searchFieldLoader.item) {
                    searchFieldLoader.item.forceActiveFocus();
                }
            });
        }
    }

    function pick(i) {
        if (i < 0 || i >= root.count) return;
        const prev = root.currentIndex;
        root.selected(i);
        // Only assign manually if external property binding didn't update currentIndex
        if (root.currentIndex === prev && prev !== i) {
            root.currentIndex = i;
        }
        root.closePicker();
    }

    function scrollMenu(pixelDeltaY, angleDeltaY) {
        if (!list || list.contentHeight <= list.height) return;
        const step = pixelDeltaY !== 0 ? pixelDeltaY : (angleDeltaY / 8) * 3;
        const maxY = Math.max(0, list.contentHeight - list.height);
        list.contentY = Math.max(0, Math.min(maxY, list.contentY - step));
    }

    // Tracker to ensure we know EXACTLY where the button is in the overlay
    TransformWatcher {
        id: watcher
        a: root.overlayParent
        b: root
    }

    // Geometric calculations based on the watcher
    readonly property point mappedPos: {
        watcher.transform; // Trigger reactivity
        if (!root.overlayParent) return Qt.point(0, 0);
        return root.mapToItem(root.overlayParent, 0, 0);
    }
    readonly property real currentX: mappedPos.x
    readonly property real currentY: mappedPos.y
    readonly property real startW: root.implicitWidth
    readonly property real startH: 36
    
    readonly property real targetW: Math.max(startW, root.searchable ? 220 : 180)
    readonly property real targetH: Math.min(root.menuMaxHeight, Math.max((root.count * root.rowHeight) + Tokens.padding.small * 2, 48))

    readonly property real targetX: {
        const maxOverlayW = root.overlayParent ? root.overlayParent.width : 1920;
        const refX = (root.freezeW > 0) ? root.freezeX : currentX;
        const refW = (root.freezeW > 0) ? root.freezeW : startW;
        const rightAlignedX = refX + refW - targetW;

        if (root.alignLeft) {
            return Math.max(8, Math.min(refX, maxOverlayW - targetW - 8));
        }

        // If in right half (e.g. SettingRow), lock right edge to button right edge
        if (refX > maxOverlayW * 0.45) {
            return Math.max(8, Math.min(rightAlignedX, maxOverlayW - targetW - 8));
        }

        const idealX = Math.round(refX - Math.max(0, (targetW - refW) * 0.25));
        if (idealX + targetW <= maxOverlayW - 8) {
            return Math.max(8, idealX);
        }
        return Math.max(8, Math.min(rightAlignedX, maxOverlayW - targetW - 8));
    }

    readonly property real targetY: {
        const maxOverlayH = root.overlayParent ? root.overlayParent.height : 1080;
        const bottomLimit = maxOverlayH - 8;
        const refY = (root.freezeH > 0) ? root.freezeY : currentY;
        const refH = (root.freezeH > 0) ? root.freezeH : startH;

        if (root.menuOnTop) {
            const aboveY = refY + refH - targetH;
            if (aboveY >= 8) return aboveY;
        }

        // Natural position: align top of menu with button top
        const naturalY = refY;
        const naturalBottom = naturalY + targetH;
        const deficit = naturalBottom - bottomLimit;

        // Only move up as much as needed to make enough space below
        if (deficit > 0) {
            return Math.max(8, naturalY - deficit);
        }
        return Math.max(8, naturalY);
    }

    // ── Static Button (Placeholder in Layout) ──
    StyledRect {
        id: face
        anchors.fill: parent
        implicitWidth: Math.max(faceRow.implicitWidth + Tokens.padding.normal * 2 + 4, 100)
        implicitHeight: 36
        radius: height / 2
        color: Colours.palette.m3primary
        opacity: (root.expanded || closeGrace.running) ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 0 } } // Instant cut, morph takes over

        StateLayer {
            radius: parent.radius
            color: Colours.palette.m3onPrimary
            enabled: !root.expanded && !closeGrace.running
            onClicked: root.openPicker()
        }

        RowLayout {
            id: faceRow
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            readonly property string currentPrev: root.model && root.currentIndex >= 0 && root.currentIndex < root.model.length ? root.previewOf(root.model[root.currentIndex]) : ""
            readonly property bool isMat: root.model && root.currentIndex >= 0 && root.currentIndex < root.model.length ? root.isMaterialPreview(root.model[root.currentIndex]) : false

            Item {
                visible: faceRow.currentPrev.length > 0
                Layout.preferredWidth: visible ? 20 : 0
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    anchors.centerIn: parent
                    visible: !faceRow.isMat
                    text: faceRow.currentPrev
                    color: Colours.palette.m3onPrimary
                    textPointSize: root.isCircledText(text) ? Tokens.font.size.normal : Tokens.font.size.small
                    font.weight: Font.Medium
                    font.family: Tokens.font.family.sans
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: faceRow.isMat
                    text: faceRow.currentPrev
                    color: Colours.palette.m3onPrimary
                    iconPointSize: Tokens.font.size.normal
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Item {
                Layout.preferredWidth: Math.min(faceText.implicitWidth, 240)
                Layout.preferredHeight: faceText.implicitHeight
                Layout.alignment: Qt.AlignVCenter
                clip: true

                StyledText {
                    id: faceText
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    width: parent.width
                    text: root.labelOf(root.currentIndex)
                    color: Colours.palette.m3onPrimary
                    textPointSize: Tokens.font.size.small
                    font.weight: Font.Medium
                    font.family: Tokens.font.family.sans
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: "expand_more"
                color: Colours.palette.m3onPrimary
                iconPointSize: Tokens.font.size.normal
                opacity: 0.9
                verticalAlignment: Text.AlignVCenter
                rotation: (root.expanded || root.morphState === "open") ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }
    }

    // ── Overlay Elements ──
    MouseArea {
        id: dismissArea
        parent: root.overlayParent
        anchors.fill: parent
        z: 9997
        visible: root.expanded
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.AllButtons
        onClicked: root.closePicker()
        onWheel: event => event.accepted = true
        onPressed: event => event.accepted = true
        onReleased: event => event.accepted = true
        onDoubleClicked: event => event.accepted = true
    }

    // M3 Ambient Elevation Shadow
    Elevation {
        parent: root.overlayParent
        z: 9998
        visible: morphContainer.visible
        x: morphContainer.x
        y: morphContainer.y
        width: morphContainer.width
        height: morphContainer.height
        radius: morphContainer.radius
        level: root.morphState === "open" ? 2 : 0
        color: Qt.alpha(Colours.palette.m3shadow, Colours.light ? 0.22 : 0.45)
        blur: 18
        offset.y: 4
        spread: 0
        opacity: root.morphState === "open" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    // True M3 Expressive Shared Element Container Morph (StyledClippingRect clips children to rounded corners)
    StyledClippingRect {
        id: morphContainer
        parent: root.overlayParent
        visible: root.expanded || closeGrace.running
        z: 9999

        Timer {
            id: closeGrace
            interval: root.morphDuration + 60
            onTriggered: {
                if (searchFieldLoader.item) {
                    searchFieldLoader.item.focus = false;
                }
                if (list) {
                    list.focus = false;
                }
            }
        }

        // M3 Physics Bounds - Smooth Emphasized Deceleration Curve
        x: root.morphState === "open" ? root.targetX : root.currentX
        y: root.morphState === "open" ? root.targetY : root.currentY
        width: root.morphState === "open" ? root.targetW : root.startW
        height: root.morphState === "open" ? root.targetH : root.startH
        radius: root.morphState === "open" ? Tokens.rounding.normal : (root.startH / 2)

        Behavior on x { Anim { type: Anim.DefaultSpatial } }
        Behavior on y { Anim { type: Anim.DefaultSpatial } }
        Behavior on width { Anim { type: Anim.DefaultSpatial } }
        Behavior on height { Anim { type: Anim.DefaultSpatial } }
        Behavior on radius { Anim { type: Anim.DefaultSpatial } }

        // Background Crossfade (StyledClippingRect has built-in Behavior on color with CAnim)
        color: root.morphState === "open" ? Colours.palette.m3surfaceContainer : Colours.palette.m3primary
        border.width: 0

        // ── Shared Element Morphing Button Face ──
        Item {
            id: morphBtnFace
            anchors.fill: parent
            opacity: root.morphState === "open" ? 0.0 : 1.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: root.morphState === "open" ? 110 : 180
                    easing.type: root.morphState === "open" ? Easing.OutQuad : Easing.OutCubic
                }
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                Item {
                    visible: morphPrev.length > 0
                    Layout.preferredWidth: visible ? 20 : 0
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter

                    readonly property string morphPrev: root.model && root.currentIndex >= 0 && root.currentIndex < root.model.length ? root.previewOf(root.model[root.currentIndex]) : ""
                    readonly property bool isMat: root.model && root.currentIndex >= 0 && root.currentIndex < root.model.length ? root.isMaterialPreview(root.model[root.currentIndex]) : false

                    StyledText {
                        anchors.centerIn: parent
                        visible: !parent.isMat
                        text: parent.morphPrev
                        color: Colours.palette.m3onPrimary
                        textPointSize: root.isCircledText(text) ? Tokens.font.size.normal : Tokens.font.size.small
                        font.weight: Font.Medium
                        font.family: Tokens.font.family.sans
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: parent.isMat
                        text: parent.morphPrev
                        color: Colours.palette.m3onPrimary
                        iconPointSize: Tokens.font.size.normal
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Item {
                    Layout.preferredWidth: Math.min(morphText.implicitWidth, 240)
                    Layout.preferredHeight: morphText.implicitHeight
                    Layout.alignment: Qt.AlignVCenter
                    clip: true

                    StyledText {
                        id: morphText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        width: parent.width
                        text: root.labelOf(root.currentIndex)
                        color: Colours.palette.m3onPrimary
                        textPointSize: Tokens.font.size.small
                        font.weight: Font.Medium
                        font.family: Tokens.font.family.sans
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }

                MaterialIcon {
                    id: morphChevron
                    Layout.alignment: Qt.AlignVCenter
                    text: "expand_more"
                    color: Colours.palette.m3onPrimary
                    iconPointSize: Tokens.font.size.normal
                    opacity: root.morphState === "open" ? 0.0 : 0.9
                    verticalAlignment: Text.AlignVCenter
                    rotation: root.morphState === "open" ? 180 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }
        }

        // ── Incoming Dropdown Content (Fades in smoothly when opening) ──
        Item {
            anchors.top: parent.top
            anchors.topMargin: Tokens.padding.small
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.small
            width: root.targetW - Tokens.padding.small * 2
            height: root.targetH - Tokens.padding.small * 2
            opacity: root.morphState === "open" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity {
                NumberAnimation {
                    duration: root.morphState === "open" ? 220 : 110
                    easing.type: root.morphState === "open" ? Easing.OutCubic : Easing.OutQuad
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    event.accepted = true;
                    const dy = event.pixelDelta && event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 8 * 4;
                    root.scrollMenu(dy, event.angleDelta.y);
                }
            }

            Loader {
                id: searchFieldLoader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: root.searchable ? Tokens.padding.small : 0
                active: root.searchable && (root.expanded || closeGrace.running)
                visible: root.searchable
                height: (visible && active && item) ? item.implicitHeight : 0

                sourceComponent: StyledTextField {
                    id: innerSearchField
                    anchors.fill: parent
                    placeholderText: qsTr("Search...")
                    text: root.searchQuery
                    onTextChanged: {
                        if (text !== root.searchQuery) {
                            root.searchQuery = text;
                        }
                    }
                    Keys.onEscapePressed: event => {
                        event.accepted = true;
                        root.closePicker();
                    }
                }
            }

            StyledListView {
                id: list
                anchors.top: (root.searchable && searchFieldLoader.item) ? searchFieldLoader.bottom : parent.top
                anchors.topMargin: (root.searchable && searchFieldLoader.item) ? Tokens.spacing.small : 0
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                clip: true
                model: root.filteredModel
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                focus: false
                keyNavigationEnabled: true
                highlightFollowsCurrentItem: false
                currentIndex: -1
                Keys.onEscapePressed: event => {
                    event.accepted = true;
                    root.closePicker();
                }

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: list
                }
                
                property int hoveredIndex: -1
                Timer {
                    id: clearHoverTimer
                    interval: 75
                    onTriggered: list.hoveredIndex = -1
                }

                // Floating M3 hover highlight pill
                Rectangle {
                    parent: list.contentItem
                    z: -1
                    width: list.width
                    height: root.rowHeight
                    y: list.hoveredIndex >= 0 ? list.hoveredIndex * root.rowHeight : y
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
                    radius: Tokens.rounding.small
                    opacity: {
                        if (list.hoveredIndex < 0 || !root.filteredModel || list.hoveredIndex >= root.filteredModel.length) return 0;
                        const item = root.filteredModel[list.hoveredIndex];
                        const orig = (typeof item === "object" && item !== null && "orig" in item) ? item.orig : list.hoveredIndex;
                        return orig !== root.currentIndex ? 1 : 0;
                    }
                    visible: opacity > 0
                    
                    Behavior on y { Anim { type: Anim.DefaultSpatial } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property int originalIndex: (typeof modelData === "object" && modelData !== null && "orig" in modelData) ? modelData.orig : index
                    readonly property var origModelData: (typeof modelData === "object" && modelData !== null && "val" in modelData) ? modelData.val : modelData
                    readonly property bool active: originalIndex === root.currentIndex
                    readonly property string label: root.displayName(origModelData)
                    readonly property bool previewAsFont: {
                        const s = (origModelData === undefined || origModelData === null) ? "" : String(origModelData);
                        return s.length > 0 && s === row.label;
                    }
                    readonly property bool isInstalled: (origModelData && typeof origModelData === "object" && ("installed" in origModelData)) ? Boolean(origModelData.installed) : true

                    width: list.width
                    implicitHeight: root.rowHeight
                    height: implicitHeight
                    opacity: row.isInstalled ? 1.0 : 0.45
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    // Applied indicator marker - EXACTLY list.width, NEVER resizes
                    Rectangle {
                        anchors.fill: parent
                        color: Colours.palette.m3primary
                        radius: Tokens.rounding.small
                        visible: row.active
                    }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        spacing: Tokens.spacing.small

                        Item {
                            visible: rowPrev.length > 0
                            Layout.preferredWidth: visible ? 20 : 0
                            Layout.preferredHeight: 20
                            Layout.alignment: Qt.AlignVCenter

                            readonly property string rowPrev: root.previewOf(row.origModelData)
                            readonly property bool isMat: root.isMaterialPreview(row.origModelData)

                            StyledText {
                                anchors.centerIn: parent
                                visible: !parent.isMat
                                text: parent.rowPrev
                                color: row.active ? Colours.palette.m3surface : Colours.palette.m3onSurface
                                textPointSize: root.isCircledText(text) ? Tokens.font.size.normal : Tokens.font.size.small
                                font.weight: Font.Medium
                                font.family: Tokens.font.family.sans
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: parent.isMat
                                text: parent.rowPrev
                                color: row.active ? Colours.palette.m3surface : Colours.palette.m3onSurface
                                iconPointSize: Tokens.font.size.normal
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: rowText.implicitHeight
                            Layout.alignment: Qt.AlignVCenter
                            clip: true

                            StyledText {
                                id: rowText
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.label
                                color: row.active ? Colours.palette.m3surface : Colours.palette.m3onSurface
                                font.weight: Font.Medium
                                font.family: row.previewAsFont ? String(row.origModelData) : Tokens.font.family.sans
                                textPointSize: Tokens.font.size.small
                                
                                SequentialAnimation on x {
                                    loops: Animation.Infinite
                                    running: Boolean(parent) && rowText.implicitWidth > (parent ? parent.width : 0) && root.expanded && root.morphState === "open" && !closeGrace.running
                                    PauseAnimation { duration: 1500 }
                                    NumberAnimation {
                                        from: 0
                                        to: (parent ? parent.width : 0) - rowText.implicitWidth
                                        duration: Math.max(0, rowText.implicitWidth - (parent ? parent.width : 0)) * 30
                                    }
                                    PauseAnimation { duration: 1500 }
                                    NumberAnimation {
                                        to: 0
                                        duration: 400
                                        easing.type: Easing.InOutQuad
                                    }
                                }
                            }
                        }

                        MaterialIcon {
                            visible: !row.isInstalled
                            Layout.alignment: Qt.AlignVCenter
                            text: "cloud_download"
                            iconPointSize: 14
                            color: row.active ? Colours.palette.m3surface : Colours.palette.m3onSurfaceVariant
                            opacity: 0.75
                        }
                    }

                    MouseArea {
                        id: itemHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: row.isInstalled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onContainsMouseChanged: {
                            if (containsMouse) {
                                clearHoverTimer.stop();
                                list.hoveredIndex = row.index;
                            } else if (list.hoveredIndex === row.index) {
                                clearHoverTimer.restart();
                            }
                        }
                        onPositionChanged: {
                            if (list.hoveredIndex !== row.index) {
                                clearHoverTimer.stop();
                                list.hoveredIndex = row.index;
                            }
                        }
                        onClicked: {
                            if (!row.isInstalled) {
                                root.handleNotInstalled(row.origModelData);
                                return;
                            }
                            root.pick(row.originalIndex);
                        }
                    }
                }
            }
        }
    }
}
