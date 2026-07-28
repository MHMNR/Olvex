pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import Olvex.Config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.services

// Lightweight string dropdown — ListView menu (no Instantiator×N MenuItems).
// Popup is parented to the same Window as the control (FloatingWindow-safe).
Item {
    id: root

    property var model: []
    property int currentIndex: 0
    // Settings rows: open below by default (was true → flew to wrong place)
    property bool menuOnTop: false
    property real menuMaxHeight: 320
    property bool expanded: false
    // Hover target for sliding menu highlight (same as qs.components.controls.Menu)
    property Item hoveredItem: null

    signal selected(int index)

    readonly property int count: model ? model.length : 0
    readonly property var m3Emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]

    implicitWidth: Math.max(face.implicitWidth, 120)
    implicitHeight: face.implicitHeight

    // Pretty display for stored values (tonalspot → Tonal Spot). Raw model
    // entries stay unchanged for config / Schemes APIs.
    function displayName(v): string {
        if (v === undefined || v === null || v === "")
            return qsTr("Default");
        const s = String(v);
        const known = {
            "tonalspot": "Tonal Spot",
            "vibrant": "Vibrant",
            "expressive": "Expressive",
            "fidelity": "Fidelity",
            "content": "Content",
            "neutral": "Neutral",
            "monochrome": "Monochrome",
            "auto": "Auto",
            "amd": "AMD",
            "nvidia": "NVIDIA",
            "intel": "Intel",
            "mpv": "mpv",
            "firefox": "Firefox",
            "vlc": "VLC",
            "spotify": "Spotify",
            "fade": "Fade",
            "wipe": "Wipe",
            "disc": "Disc",
            "stripes": "Stripes",
            "iris": "Iris",
            "iris bloom": "Iris Bloom",
            "pixelate": "Pixelate",
            "portal": "Portal",
            "random": "Random",
            "none": "None",
            "card": "Card",
            "minimal": "Minimal",
            "light": "Light",
            "dark": "Dark"
        };
        const low = s.toLowerCase();
        if (known[low] !== undefined)
            return known[low];
        // Font families / mixed case — keep as-is
        if (s !== low && s !== s.toUpperCase())
            return s;
        // Single token all-lower: capitalize first letter
        if (s.indexOf(" ") < 0 && s.indexOf("-") < 0)
            return s.charAt(0).toUpperCase() + s.slice(1);
        // Words / kebab: Title Case each part
        return s.split(/[\s_-]+/).map(w => w.length ? (w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()) : w).join(" ");
    }

    function labelOf(i: int): string {
        if (!model || i < 0 || i >= model.length)
            return qsTr("Select…");
        return root.displayName(model[i]);
    }

    function closeMenu(): void {
        root.expanded = false;
    }

    function pick(i: int): void {
        if (i < 0 || i >= root.count)
            return;
        if (root.currentIndex !== i)
            root.currentIndex = i;
        root.selected(i);
        root.expanded = false;
    }

    function repositionPanel(): void {
        if (!root.expanded || !scrim.visible || !face.width)
            return;
        const host = scrim;
        // Map face corners into scrim (same window contentItem)
        const topLeft = face.mapToItem(host, 0, 0);
        const below = face.mapToItem(host, 0, face.height);
        const pw = panel.width;
        const ph = panel.height;
        // Align panel's right edge with face's right edge
        let px = topLeft.x + face.width - pw;
        let py = root.menuOnTop ? (topLeft.y - ph - Tokens.spacing.small) : (below.y + Tokens.spacing.small);
        // Keep on-screen
        const margin = 8;
        if (px < margin)
            px = margin;
        if (px + pw > host.width - margin)
            px = Math.max(margin, host.width - pw - margin);
        // Flip vertical if would overflow
        if (!root.menuOnTop && py + ph > host.height - margin)
            py = topLeft.y - ph - Tokens.spacing.small;
        if (root.menuOnTop && py < margin)
            py = below.y + Tokens.spacing.small;
        if (py < margin)
            py = margin;
        if (py + ph > host.height - margin)
            py = Math.max(margin, host.height - ph - margin);
        panel.x = px;
        panel.y = py;
    }

    onExpandedChanged: {
        if (expanded) {
            // After layout / height known
            Qt.callLater(repositionPanel);
            Qt.callLater(() => {
                if (list.count > 0 && root.currentIndex >= 0)
                    list.positionViewAtIndex(root.currentIndex, ListView.Contain);
                repositionPanel();
                // Wheel focus on menu ListView, not page Flickable
                list.forceActiveFocus();
            });
        } else {
            root.hoveredItem = null;
        }
    }

    // Scroll the menu list; never let wheel reach Settings page underneath
    function scrollMenu(pixelDeltaY: real, angleDeltaY: real): void {
        if (!list || list.contentHeight <= list.height)
            return;
        const step = pixelDeltaY !== 0 ? pixelDeltaY : (angleDeltaY / 8) * 3;
        const maxY = Math.max(0, list.contentHeight - list.height);
        list.contentY = Math.max(0, Math.min(maxY, list.contentY - step));
    }

    // ── Face: soft chromatic pill [label · expand_more] ──
    // Use primaryContainer in dark (secondaryContainer is often muddy grey on glass).
    StyledRect {
        id: face

        readonly property color colour: Colours.light
            ? Colours.palette.m3secondaryContainer
            : Colours.palette.m3primaryContainer
        readonly property color textColour: Colours.light
            ? Colours.palette.m3onSecondaryContainer
            : Colours.palette.m3onPrimaryContainer

        implicitWidth: Math.max(faceRow.implicitWidth + Tokens.padding.normal * 2 + 4, 100)
        implicitHeight: 36
        radius: height / 2
        // Opaque solid fill — no glass wash
        color: Qt.rgba(colour.r, colour.g, colour.b, 1)
        border.width: 0

        StateLayer {
            radius: parent.radius
            color: face.textColour
            onClicked: root.expanded = !root.expanded
        }

        Row {
            id: faceRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            StyledText {
                id: label

                anchors.verticalCenter: parent.verticalCenter
                text: root.labelOf(root.currentIndex)
                color: face.textColour
                textPointSize: Tokens.font.size.small
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 160)
            }

            MaterialIcon {
                id: chevron

                anchors.verticalCenter: parent.verticalCenter
                text: "expand_more"
                color: face.textColour
                rotation: root.expanded ? 180 : 0
                iconPointSize: Tokens.font.size.normal
                opacity: 0.85

                Behavior on rotation {
                    Anim {}
                }
            }
        }
    }

    // ── Scrim + panel on the SAME window as this control (FloatingWindow) ──
    MouseArea {
        id: scrim

        // Qt Window attached property — correct for FloatingWindow settings shell
        // (QsWindow.window / ContentWindow was resolving to the wrong host → top-right ghost)
        parent: {
            const w = root.Window.window;
            return w ? w.contentItem : null;
        }
        anchors.fill: parent ?? undefined
        enabled: root.expanded && parent !== null
        visible: enabled
        z: 10000
        // Capture hover so wheel targets this layer, not the page Flickable
        hoverEnabled: true
        preventStealing: true
        onClicked: root.closeMenu()

        // CRITICAL: MouseArea does not block wheel by default — events fall
        // through to SettingsPage Flickable. Accept all wheel while open;
        // when over the panel, drive the ListView ourselves.
        // Accept + consume every wheel while menu is open so Settings Flickable
        // never scrolls underneath. Always drive the menu list.
        onWheel: event => {
            event.accepted = true;
            const dy = event.pixelDelta && event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 8 * 4;
            root.scrollMenu(dy, event.angleDelta.y);
        }

        Connections {
            target: root.Window.window
            function onWidthChanged(): void {
                root.repositionPanel();
            }
            function onHeightChanged(): void {
                root.repositionPanel();
            }
        }

        TransformWatcher {
            id: watcher

            a: scrim
            b: face
        }

        readonly property var _watch: watcher.transform
        on_WatchChanged: root.repositionPanel()

        Elevation {
            id: panel

            readonly property real m: Tokens.padding.small

            width: Math.max(face.width, 220)
            height: Math.min(root.menuMaxHeight, Math.max(list.contentHeight + m * 2, 48))
            radius: Tokens.rounding.normal
            level: 2

            // Menu-style open: fade + scale from attach edge
            opacity: root.expanded ? 1 : 0
            visible: opacity > 0.01
            transformOrigin: Item.Top
            // Origin at top when opening below, bottom when opening above
            transform: Scale {
                id: panelScale
                yScale: root.expanded ? 1 : 0.12
                origin.x: panel.width / 2
                origin.y: root.menuOnTop ? panel.height : 0

                Behavior on yScale {
                    enabled: true
                    NumberAnimation {
                        duration: Tokens.anim.durations.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.m3Emphasized
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.anim.durations.expressiveFastEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.m3Emphasized
                }
            }

            StyledRect {
                id: panelSurface

                anchors.fill: parent
                radius: parent.radius
                color: Colours.palette.m3surfaceContainerLow
                clip: true

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        event.accepted = true;
                        const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 8 * 4;
                        root.scrollMenu(dy, event.angleDelta.y);
                    }
                }

                // Sliding hover marker — same as Panels.qml contextMenuHoverHighlight
                StyledRect {
                    id: hoverHighlight

                    readonly property Item target: {
                        if (!root.expanded)
                            return null;
                        if (root.hoveredItem)
                            return root.hoveredItem;
                        return list.itemAtIndex(root.currentIndex);
                    }
                    readonly property real _scroll: list.contentY

                    z: 0
                    visible: target !== null
                    opacity: visible ? 0.08 : 0
                    color: Colours.palette.m3onSurface
                    radius: Tokens.rounding.small
                    x: {
                        const _ = _scroll;
                        return target ? target.mapToItem(panelSurface, 0, 0).x : 0;
                    }
                    y: {
                        const _ = _scroll;
                        return target ? target.mapToItem(panelSurface, 0, 0).y : 0;
                    }
                    width: target ? target.width : 0
                    height: target ? target.height : 0

                    Behavior on x {
                        enabled: hoverHighlight.opacity > 0
                        SpringAnimation {
                            spring: 7.0
                            damping: 0.8
                            mass: 1.0
                            epsilon: 0.005
                        }
                    }
                    Behavior on y {
                        enabled: hoverHighlight.opacity > 0
                        SpringAnimation {
                            spring: 7.0
                            damping: 0.8
                            mass: 1.0
                            epsilon: 0.005
                        }
                    }
                    Behavior on width {
                        enabled: hoverHighlight.opacity > 0
                        SpringAnimation {
                            spring: 7.0
                            damping: 0.8
                            mass: 1.0
                            epsilon: 0.005
                        }
                    }
                    Behavior on height {
                        enabled: hoverHighlight.opacity > 0
                        SpringAnimation {
                            spring: 7.0
                            damping: 0.8
                            mass: 1.0
                            epsilon: 0.005
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }

                StyledListView {
                    id: list

                    anchors.fill: parent
                    anchors.margins: panel.m
                    z: 1
                    clip: true
                    model: root.model
                    spacing: 0
                    boundsBehavior: Flickable.StopAtBounds
                    focus: root.expanded
                    keyNavigationEnabled: true
                    highlightFollowsCurrentItem: false
                    currentIndex: root.currentIndex
                    onContentHeightChanged: root.repositionPanel()

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool active: index === root.currentIndex
                        readonly property string raw: (modelData === undefined || modelData === null) ? "" : String(modelData)
                        readonly property string label: root.displayName(modelData)
                        readonly property bool previewAsFont: row.raw.length > 0 && row.raw === row.label

                        width: list.width
                        implicitHeight: rowText.implicitHeight + Tokens.padding.normal * 2
                        height: implicitHeight

                        StyledText {
                            id: rowText

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.normal
                            anchors.rightMargin: Tokens.padding.normal
                            z: 1
                            text: row.label
                            elide: Text.ElideRight
                            color: Colours.palette.m3onSurface
                            font.family: row.previewAsFont ? row.raw : (Tokens?.font?.family?.sans ?? "sans-serif")
                            font.weight: row.active ? Font.Medium : Font.Normal
                            textPointSize: Tokens.font.size.smaller
                        }

                        StateLayer {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            color: Colours.palette.m3onSurface
                            hoverEnabled: false
                            onClicked: root.pick(row.index)
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            onEntered: {
                                if (root.expanded)
                                    root.hoveredItem = row;
                            }
                            onExited: {
                                if (root.hoveredItem === row)
                                    root.hoveredItem = null;
                            }
                        }
                    }
                }
            }
        }
    }
}
