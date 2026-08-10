pragma ComponentBehavior: Bound

import ".."
import "."
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import "../../../components/effects"
import QtQuick
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

    signal selected(int index)

    readonly property int count: model ? model.length : 0
    readonly property real rowHeight: 36
    readonly property bool animating: morphState !== "closed"
    property string morphState: "closed" // "closed", "open"

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
        if (!root.overlayParent || !face) return Qt.point(0, 0);
        return face.mapToItem(root.overlayParent, 0, 0);
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

    // ── Static Button (Placeholder) ──
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
            color: Colours.palette.m3onPrimary
            onClicked: {
                root.expanded = true;
                root.morphState = "open";
                
                // Align scroll position
                const maxContentY = Math.max(0, (root.count * root.rowHeight) - (root.targetH - Tokens.padding.small * 2));
                const idealContentY = (root.currentIndex * root.rowHeight) - (root.targetH / 2) + (root.rowHeight / 2);
                if (list && list.count > 0) list.contentY = Math.max(0, Math.min(maxContentY, idealContentY));
            }
        }

        Row {
            id: faceRow
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            Item {
                width: Math.min(faceText.implicitWidth, 160)
                height: faceText.implicitHeight
                clip: true

                StyledText {
                    id: faceText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.labelOf(root.currentIndex)
                    color: Colours.palette.m3onPrimary
                    textPointSize: Tokens.font.size.small
                    font.weight: Font.Medium
                    
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: faceText.implicitWidth > parent.width && !root.expanded
                        PauseAnimation { duration: 1500 }
                        NumberAnimation {
                            from: 0
                            to: parent.width - faceText.implicitWidth
                            duration: Math.max(0, faceText.implicitWidth - parent.width) * 30
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
                anchors.verticalCenter: parent.verticalCenter
                text: "expand_more"
                color: Colours.palette.m3onPrimary
                iconPointSize: Tokens.font.size.normal
                opacity: 0.85
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

    // True M3 Expressive Shared Element Morph
    Rectangle {
        id: morphContainer
        parent: root.overlayParent
        visible: root.expanded || closeGrace.running
        z: 9999
        clip: true

        Timer {
            id: closeGrace
            interval: 500 // Keeps container alive while physics settle
        }

        // M3 Physics Bounds
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
        Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
        
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
        border.width: root.morphState === "open" ? 1 : 0
        Behavior on border.width { NumberAnimation { duration: 250 } }

        // ── Traveling Active Item ──
        Rectangle {
            id: travelingPill
            
            // In closed state, fills the button. In open state, positions at the active row.
            x: root.morphState === "open" ? Tokens.padding.small : 0
            y: root.morphState === "open" ? (Tokens.padding.small + root.currentIndex * root.rowHeight - list.contentY) : 0
            width: root.morphState === "open" ? (root.targetW - Tokens.padding.small * 2) : root.startW
            height: root.startH
            radius: root.morphState === "open" ? Tokens.rounding.small : (root.startH / 2)
            
            color: root.morphState === "open" ? Colours.palette.m3primary : "transparent"
            Behavior on color { ColorAnimation { duration: 250 } }

            Behavior on x { Anim { type: Anim.DefaultSpatial } }
            Behavior on y { Anim { type: Anim.DefaultSpatial } }
            Behavior on width { Anim { type: Anim.DefaultSpatial } }
            // Height is constant, no behavior needed
            Behavior on radius { Anim { type: Anim.DefaultSpatial } }

            // Absolute positioning for flawless M3 Shared Element text glide
            readonly property real textStartW: travelingText.width
            readonly property real iconStartW: travelingIcon.width
            readonly property real totalStartW: textStartW + Tokens.spacing.small + iconStartW
            readonly property real contentStartX: (root.startW - totalStartW) / 2

            StyledText {
                id: travelingText
                x: root.morphState === "open" ? Tokens.padding.normal : parent.contentStartX
                y: (parent.height - implicitHeight) / 2
                text: root.labelOf(root.currentIndex)
                color: Colours.palette.m3onPrimary
                textPointSize: Tokens.font.size.small
                font.weight: root.morphState === "open" ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 160)
                
                Behavior on x { Anim { type: Anim.DefaultSpatial } }
            }

            MaterialIcon {
                id: travelingIcon
                x: root.morphState === "open" ? root.targetW : (parent.contentStartX + travelingText.width + Tokens.spacing.small)
                y: (parent.height - implicitHeight) / 2
                text: "expand_more"
                color: Colours.palette.m3onPrimary
                iconPointSize: Tokens.font.size.normal
                opacity: root.morphState === "open" ? 0 : 0.85
                
                Behavior on x { Anim { type: Anim.DefaultSpatial } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }

        // ── List Items (Fade in/out) ──
        Item {
            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            z: 3
            opacity: root.morphState === "open" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    event.accepted = true;
                    const dy = event.pixelDelta && event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 8 * 4;
                    root.scrollMenu(dy, event.angleDelta.y);
                }
            }

            StyledListView {
                id: list
                anchors.fill: parent
                clip: true
                model: root.model
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                focus: root.expanded
                keyNavigationEnabled: true
                highlightFollowsCurrentItem: false
                currentIndex: root.currentIndex
                
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
                    opacity: list.hoveredIndex >= 0 && list.hoveredIndex !== root.currentIndex ? 1 : 0
                    visible: opacity > 0
                    
                    Behavior on y { Anim { type: Anim.DefaultSpatial } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool active: index === root.currentIndex
                    readonly property string label: root.displayName(modelData)
                    readonly property bool previewAsFont: {
                        const s = (modelData === undefined || modelData === null) ? "" : String(modelData);
                        return s.length > 0 && s === row.label;
                    }

                    width: list.width
                    implicitHeight: root.rowHeight
                    height: implicitHeight

                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        height: rowText.implicitHeight
                        clip: true

                        StyledText {
                            id: rowText
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.label
                            opacity: row.active ? 0 : 1 // Active label is drawn by travelingPill
                            color: Colours.palette.m3onSurface
                            font.family: row.previewAsFont ? String(row.modelData) : (Tokens?.font?.family?.sans ?? "sans-serif")
                            textPointSize: Tokens.font.size.smaller
                            
                            SequentialAnimation on x {
                                loops: Animation.Infinite
                                running: rowText.implicitWidth > parent.width && root.expanded && opacity > 0
                                PauseAnimation { duration: 1500 }
                                NumberAnimation {
                                    from: 0
                                    to: parent.width - rowText.implicitWidth
                                    duration: Math.max(0, rowText.implicitWidth - parent.width) * 30
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
                        onClicked: root.pick(row.index)
                    }
                }
            }
        }
    }
}
