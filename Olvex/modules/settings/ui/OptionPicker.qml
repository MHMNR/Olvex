pragma ComponentBehavior: Bound

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
import Olvex.Config
import qs.services
import qs.utils

Item {
    id: root

    property var model: []
    property int currentIndex: 0
    property bool menuOnTop: false
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

    readonly property int count: model ? model.length : 0
    readonly property real rowHeight: 36
    readonly property bool animating: morphState !== "closed" || closeGrace.running
    property string morphState: "closed" // "closed", "open"

    readonly property int morphDuration: Tokens?.anim?.durations?.expressiveDefaultSpatial ?? 450
    readonly property var morphEasing: Tokens?.anim?.expressiveDefaultSpatial

    implicitWidth: face.implicitWidth
    implicitHeight: face.implicitHeight

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

    function displayName(v): string {
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

    function previewOf(v): string {
        if (v === undefined || v === null) return "";
        if (v.preview !== undefined) return String(v.preview);
        if (v.icon !== undefined) return String(v.icon);
        return "";
    }

    function isMaterialPreview(v): bool {
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

    function isCircledText(t: string): bool {
        if (!t || t.length === 0) return false;
        const code = t.charCodeAt(0);
        return (code >= 0x2776 && code <= 0x277F)
            || (code >= 0x2460 && code <= 0x2473)
            || (code >= 0x24EB && code <= 0x24F4)
            || (code >= 0x2780 && code <= 0x2789);
    }

    function labelOf(i: int): string {
        if (!model || i < 0 || i >= model.length) return qsTr("Select\u2026");
        return root.displayName(model[i]);
    }

    function pick(i: int): void {
        if (i < 0 || i >= root.count) return;
        if (root.currentIndex !== i) root.currentIndex = i;
        root.selected(i);
        root.expanded = false;
        root.morphState = "closed";
        closeGrace.restart();
    }

    function scrollMenu(pixelDeltaY: real, angleDeltaY: real): void {
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
    
    readonly property real targetW: Math.max(startW, 220)
    readonly property real targetH: Math.min(root.menuMaxHeight, Math.max((root.count * root.rowHeight) + Tokens.padding.small * 2, 48))

    readonly property real targetX: {
        const rawX = currentX + startW - targetW;
        const maxOverlayW = root.overlayParent ? root.overlayParent.width : 1920;
        return Math.max(8, Math.min(rawX, maxOverlayW - targetW - 8));
    }

    readonly property real targetY: {
        const belowY = currentY + startH + Tokens.spacing.small;
        const aboveY = currentY - targetH - Tokens.spacing.small;
        const maxOverlayH = root.overlayParent ? root.overlayParent.height : 1080;
        return root.menuOnTop 
            ? (aboveY < 8 ? belowY : aboveY)
            : ((belowY + targetH > maxOverlayH - 8) ? aboveY : belowY);
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
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 0 } } // Instant cut, morph takes over

        StateLayer {
            radius: parent.radius
            color: Colours.palette.m3surface
            onClicked: {
                root.searchQuery = "";
                root.expanded = true;
                root.morphState = "open";
                
                if (root.searchable && typeof searchField !== "undefined") {
                    searchField.forceActiveFocus();
                }
                
                // Align scroll position
                const maxContentY = Math.max(0, (root.count * root.rowHeight) - (root.targetH - Tokens.padding.small * 2));
                const idealContentY = (root.currentIndex * root.rowHeight) - (root.targetH / 2) + (root.rowHeight / 2);
                if (list && list.count > 0) list.contentY = Math.max(0, Math.min(maxContentY, idealContentY));
            }
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
                    color: Colours.palette.m3surface
                    textPointSize: root.isCircledText(text) ? (Tokens?.font?.size?.normal ?? 13) : (Tokens?.font?.size?.small ?? 11)
                    font.weight: Font.Medium
                    font.family: Tokens?.font?.family?.sans ?? "sans-serif"
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: faceRow.isMat
                    text: faceRow.currentPrev
                    color: Colours.palette.m3surface
                    iconPointSize: Tokens.font.size.normal
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Item {
                Layout.preferredWidth: Math.min(faceText.implicitWidth, 160)
                Layout.preferredHeight: faceText.implicitHeight
                Layout.alignment: Qt.AlignVCenter
                clip: true

                StyledText {
                    id: faceText
                    anchors.centerIn: parent
                    text: root.labelOf(root.currentIndex)
                    color: Colours.palette.m3surface
                    textPointSize: Tokens.font.size.small
                    font.weight: Font.Medium
                    font.family: Tokens?.font?.family?.sans ?? "sans-serif"
                    verticalAlignment: Text.AlignVCenter
                    
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: Boolean(parent) && root.visible && faceText.implicitWidth > (parent ? parent.width : 0) && !root.expanded
                        PauseAnimation { duration: 1500 }
                        NumberAnimation {
                            from: 0
                            to: (parent ? parent.width : 0) - faceText.implicitWidth
                            duration: Math.max(0, faceText.implicitWidth - (parent ? parent.width : 0)) * 30
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
        radius: root.morphState === "open" ? Tokens.rounding.normal : (root.startH / 2)

        Behavior on x { Anim { type: Anim.DefaultSpatial } }
        Behavior on y { Anim { type: Anim.DefaultSpatial } }
        Behavior on width { Anim { type: Anim.DefaultSpatial } }
        Behavior on height { Anim { type: Anim.DefaultSpatial } }
        Behavior on radius { Anim { type: Anim.DefaultSpatial } }

        // Background Crossfade
        color: root.morphState === "open" ? Colours.palette.m3surfaceContainerLow : Colours.palette.m3primary
        Behavior on color { ColorAnimation { duration: root.morphDuration; easing: root.morphEasing } }
        
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
        border.width: root.morphState === "open" ? 1 : 0
        Behavior on border.width { NumberAnimation { duration: root.morphDuration } }

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
                        color: Colours.palette.m3surface
                        textPointSize: root.isCircledText(text) ? (Tokens?.font?.size?.normal ?? 13) : (Tokens?.font?.size?.small ?? 11)
                        font.weight: Font.Medium
                        font.family: Tokens?.font?.family?.sans ?? "sans-serif"
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: parent.isMat
                        text: parent.morphPrev
                        color: Colours.palette.m3surface
                        iconPointSize: Tokens.font.size.normal
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Item {
                    Layout.preferredWidth: Math.min(morphText.implicitWidth, 160)
                    Layout.preferredHeight: morphText.implicitHeight
                    Layout.alignment: Qt.AlignVCenter
                    clip: true

                    StyledText {
                        id: morphText
                        anchors.centerIn: parent
                        text: root.labelOf(root.currentIndex)
                        color: Colours.palette.m3surface
                        textPointSize: Tokens.font.size.small
                        font.weight: Font.Medium
                        font.family: Tokens?.font?.family?.sans ?? "sans-serif"
                        verticalAlignment: Text.AlignVCenter
                    }
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

        // ── Incoming Dropdown Content (Fades in smoothly when opening) ──
        Item {
            anchors.top: parent.top
            anchors.topMargin: Tokens.padding.small
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.small
            width: root.targetW - Tokens.padding.small * 2
            height: root.targetH - Tokens.padding.small * 2
            opacity: root.morphState === "open" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    event.accepted = true;
                    const dy = event.pixelDelta && event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 8 * 4;
                    root.scrollMenu(dy, event.angleDelta.y);
                }
            }

            StyledTextField {
                id: searchField
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: root.searchable ? Tokens.padding.small : 0
                visible: root.searchable
                height: visible ? implicitHeight : 0
                placeholderText: qsTr("Search...")
                text: root.searchQuery
                onTextChanged: {
                    if (text !== root.searchQuery) {
                        root.searchQuery = text;
                    }
                }
            }

            StyledListView {
                id: list
                anchors.top: root.searchable ? searchField.bottom : parent.top
                anchors.topMargin: root.searchable ? Tokens.spacing.small : 0
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                clip: true
                model: root.filteredModel
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                focus: root.expanded
                keyNavigationEnabled: true
                highlightFollowsCurrentItem: false
                currentIndex: -1

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: list
                }
                
                property int hoveredIndex: -1

                // Floating M3 hover highlight pill
                Rectangle {
                    parent: list.contentItem
                    z: -1
                    width: list.width
                    height: root.rowHeight
                    y: list.hoveredIndex * root.rowHeight
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

                    width: list.width
                    implicitHeight: root.rowHeight
                    height: implicitHeight

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
                                textPointSize: root.isCircledText(text) ? (Tokens?.font?.size?.normal ?? 13) : (Tokens?.font?.size?.small ?? 11)
                                font.weight: Font.Medium
                                font.family: Tokens?.font?.family?.sans ?? "sans-serif"
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
                                font.family: row.previewAsFont ? String(row.origModelData) : (Tokens?.font?.family?.sans ?? "sans-serif")
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
                    }

                    MouseArea {
                        id: itemHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onContainsMouseChanged: {
                            if (containsMouse) list.hoveredIndex = row.index;
                            else if (list.hoveredIndex === row.index) list.hoveredIndex = -1;
                        }
                        onPositionChanged: {
                            if (list.hoveredIndex !== row.index) list.hoveredIndex = row.index;
                        }
                        onClicked: root.pick(row.originalIndex)
                    }
                }
            }
        }
    }
}
