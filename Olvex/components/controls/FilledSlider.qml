import QtQuick
import QtQuick.Templates
import Olvex.Config
import qs.components
import qs.services

// iOS-26-style fluid capsule — slim translucent stadium track at rest, springs
// wider on hover/press. The track and the liquid fill are both plain native
// Rectangles (GPU-antialiased, DPR-correct): the fill is bottom-anchored, the
// same width as the track, with radius width/2, so its rounded bottom coincides
// exactly with the track's own rounded bottom and its top is the rounded
// meniscus — no clip needed, and none used (a clip's hard mask edge chopped the
// rounded bottom). The base shows the icon on hover and the % while
// dragging/scrolling; a hardware/media-key change (not hovered) stays slim.
Slider {
    id: root

    required property string icon
    property real oldValue
    property bool initialized
    property Item screenCapture: null

    orientation: Qt.Vertical
    hoverEnabled: true

    // Anything that actively changes the value while the cursor is on the
    // slider (drag OR scroll) reveals the base readout as a percentage;
    // hovering alone only reveals the icon. A hardware/media-key change
    // won't be hovered, so it stays slim with nothing shown at the base —
    // exactly like the iOS Control Center panel.
    readonly property bool showValue: pressed || wheeling
    readonly property bool swollen: hovered || pressed

    readonly property real wRest: Math.round(width * 0.5)
    readonly property real wActive: width
    property real capW: wRest
    Behavior on capW {
        SpringAnimation {
            spring: 3.6
            damping: 0.62
            mass: 1.0
            epsilon: 0.001
        }
    }
    onSwollenChanged: capW = swollen ? wActive : wRest

    readonly property real baseH: capW

    // Drive the fill from `position` (0..1, from→to), NOT from `value`. During
    // a drag the Slider updates `position` instantly from the cursor, whereas
    // `value` is run through the `Behavior on value` animation below — so a
    // value-based fill lags behind the finger and feels janky/broken. `position`
    // still follows `value` for key/scroll changes (so those stay smoothly
    // animated), but tracks the drag with zero lag. Not `visualPosition`, which
    // is the vertical-inverted (1 - position) variant meant for a top-anchored
    // handle; the fill grows upward with the raw position.
    readonly property real liquidH: position * height
    readonly property color accentColor: Colours.palette.m3primary

    // Invisible handle — the fill is drawn independently (via liquidH), but
    // QtQuick.Templates.Slider still needs a handle item for its drag/press
    // geometry. Omitting it left the slider with no grab region, so dragging
    // didn't track properly (the "buggy" drag). Same geometry as the original
    // (a root.width square riding the waterline), just with no visuals.
    handle: Item {
        implicitWidth: root.width
        implicitHeight: root.width
        y: root.visualPosition * (root.availableHeight - height)
    }

    // Scroll doesn't set `pressed` (wheel is handled by an outer
    // CustomMouseArea sibling in modules/osd/Content.qml, shared across the
    // volume/mic/brightness sliders) — so a wheel-driven change shows up
    // here simply as "value changed while hovered and not pressed". A
    // hardware volume-key change looks the same to this component EXCEPT
    // the mouse won't be hovering when it happens, so it's naturally
    // excluded without needing to plumb wheel events through separately.
    property bool wheeling: false
    Timer {
        id: wheelSettle
        interval: 700
        onTriggered: root.wheeling = false
    }
    onValueChanged: {
        if (!initialized) {
            initialized = true;
            return;
        }
        if (Math.abs(value - oldValue) < 0.0005)
            return;
        oldValue = value;
        if (root.hovered && !root.pressed) {
            wheeling = true;
            wheelSettle.restart();
        }
    }

    background: Item {
        anchors.fill: parent

        // The iOS-style slider track itself — a translucent rounded rail. No
        // clipping is needed: the fill is always bottom-anchored, the same
        // width as the track, with radius width/2 — so its bottom semicircle
        // coincides exactly with the track's own rounded bottom, and its top
        // is the rounded meniscus. A clip here (StyledClippingRect) instead
        // cut a hard 1-bit mask edge that didn't line up with the fill's
        // antialiased corner, chopping the rounded bottom — that was the bug.
        // This IS the visible slider; the drawer's backing pill (osdBg/osdGroup
        // in ContentWindow.qml) is blanked so only this shows.
        Rectangle {
            id: railClip
            width: root.capW
            height: parent.height
            x: (parent.width - width) / 2
            radius: width / 2
            antialiasing: true
            color: Qt.alpha(Colours.palette.m3onSurface, 0.20)

            // Liquid — bottom-anchored, grows with value. radius width/2 gives
            // a full stadium cap while tall; below its own width Qt tapers the
            // cap. Native Rectangle → GPU antialiased + DPR-correct.
            Rectangle {
                width: parent.width
                anchors.bottom: parent.bottom
                height: Math.min(parent.height, root.liquidH)
                radius: width / 2
                antialiasing: true
                visible: height > 0.5
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(root.accentColor, 1.10) }
                    GradientStop { position: 1.0; color: root.accentColor }
                }
            }
        }

        // ── base readout: empty at rest, icon on hover, % while dragging/
        // scrolling. Reuses the same icon⇄number pop-morph as before (one
        // MaterialIcon swapping between the glyph and the numeric value),
        // just gated by an outer opacity so it's hidden entirely at rest.
        Item {
            id: base
            width: root.capW
            height: root.baseH
            x: (parent.width - width) / 2
            y: parent.height - height
            opacity: root.swollen ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                }
            }

            readonly property bool covered: root.liquidH >= root.baseH * 0.5

            MaterialIcon {
                id: icon

                anchors.centerIn: parent
                text: root.icon
                color: base.covered ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

                function update(): void {
                    animate = !root.showValue;
                    binding.when = root.showValue;
                    iconPointSize = root.showValue ? Tokens.font.size.small : Tokens.font.size.larger;
                    font.family = root.showValue ? Tokens.font.family.sans : Tokens.font.family.material;
                }

                Binding {
                    id: binding
                    target: icon
                    property: "text"
                    value: Math.round(root.value * 100)
                    when: false
                }
            }

            Connections {
                target: root
                function onShowValueChanged() { morphAnim.restart(); }
            }

            SequentialAnimation {
                id: morphAnim

                Anim {
                    target: icon
                    property: "scale"
                    to: 0
                    duration: Tokens.anim.durations.normal / 2
                    easing: Tokens.anim.standardAccel
                }
                ScriptAction {
                    script: icon.update()
                }
                Anim {
                    target: icon
                    property: "scale"
                    to: 1
                    duration: Tokens.anim.durations.normal / 2
                    easing: Tokens.anim.standardDecel
                }
            }
        }
    }

    // Disabled while actively dragging so the value (and the backend it drives
    // via onMoved) tracks the finger instantly; enabled otherwise so key/scroll
    // changes animate smoothly.
    Behavior on value {
        enabled: !root.pressed
        Anim {
            type: Anim.StandardLarge
        }
    }
}
