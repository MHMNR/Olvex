import QtQuick
import QtQuick.Layouts
import Quickshell
import M3Shapes
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    required property Pam pam
    readonly property alias placeholder: placeholder
    property string buffer

    Layout.fillWidth: true
    Layout.fillHeight: true

    clip: true

    Connections {
        function onBufferChanged() {
            if ((root.pam?.buffer?.length ?? 0) === 0) {
                placeholder.animate = true;
            }
            root.buffer = root.pam?.buffer ?? "";
            cursor.resetBlink();
        }
        target: root.pam
    }

    StyledText {
        id: placeholder

        anchors.centerIn: parent

        text: {
            if (root.pam?.isVerifying)
                return qsTr("Verifying...");
            if (root.pam?.state === "max")
                return qsTr("You have reached the maximum number of tries");
            return qsTr("Enter password");
        }

        animate: true
        color: root.pam?.isVerifying ? Colours.palette.m3secondary : Colours.palette.m3onSurfaceVariant
        textPointSize: Tokens.font.size.normal

        opacity: (root.buffer && root.buffer.length > 0) ? 0 : 0.75

        Behavior on opacity {
            Anim {}
        }
    }

    // ── Centred content block (dots + caret) ────────────────────────────────
    Item {
        id: contentContainer

        // ── Dynamic sizing ───────────────────────────────────────────────────
        // dotCount drives adaptive compression so all dots always fit in root.width.
        readonly property int dotCount: charList.count

        // Design limits
        readonly property real maxDotDiameter: 22
        readonly property real minDotDiameter: 8
        readonly property real maxDotSpacing: 11
        readonly property real minDotSpacing: 2

        // How much horizontal space the dots can actually use.
        // Reserve 16 px of side breathing-room + caret+gap on the right.
        readonly property real caretReserve: dotCount > 0 ? (caretGap + cursor.width) : 0
        readonly property int caretGap: 8
        readonly property real availableForDots: Math.max(0, root.width - 16 - caretReserve)

        // Step 1 – can we fit at maxDotDiameter just by squeezing spacing?
        // spacing_needed = (availableForDots - n*D) / (n-1)
        // Step 2 – if spacing_needed < minSpacing, shrink D to fit at minSpacing.
        readonly property real _idealDiam: {
            if (dotCount <= 1) return maxDotDiameter;
            const spacingAtMax = (availableForDots - dotCount * maxDotDiameter) / (dotCount - 1);
            if (spacingAtMax >= minDotSpacing) return maxDotDiameter;              // fits OK
            // Compute D so that spacing = minDotSpacing
            return Math.max(minDotDiameter,
                (availableForDots - minDotSpacing * (dotCount - 1)) / dotCount);
        }

        readonly property real _idealSpacing: {
            if (dotCount <= 1) return maxDotSpacing;
            const gap = (availableForDots - dotCount * _idealDiam) / (dotCount - 1);
            return Math.max(minDotSpacing, Math.min(maxDotSpacing, gap));
        }

        // Animated – smoothly compress/expand as characters are added/removed.
        property real effectiveDotDiameter: maxDotDiameter
        property real effectiveDotSpacing: maxDotSpacing

        on_IdealDiamChanged: effectiveDotDiameter = _idealDiam
        on_IdealSpacingChanged: effectiveDotSpacing = _idealSpacing

        Behavior on effectiveDotDiameter {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on effectiveDotSpacing {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // ── Derived layout ───────────────────────────────────────────────────
        readonly property real dotsWidth: dotCount > 0
            ? dotCount * effectiveDotDiameter + (dotCount - 1) * effectiveDotSpacing
            : 0
        readonly property real totalActiveWidth: dotsWidth + (dotCount > 0 ? caretGap + cursor.width : 0)

        readonly property real targetX: root.buffer.length > 0
            ? Math.max(8, Math.round((root.width - totalActiveWidth) / 2))
            : Math.max(8, Math.round(placeholder.x - cursor.width - caretGap))

        x: targetX
        anchors.verticalCenter: parent.verticalCenter
        width: root.buffer.length > 0 ? totalActiveWidth : 0
        height: maxDotDiameter + 14   // extra room for initial-shape pop

        Behavior on x {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastSpatial || 200
                easing: Tokens.anim.expressiveFastSpatial
            }
        }

        // ── Dots ─────────────────────────────────────────────────────────────
        ListView {
            id: charList

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: contentContainer.dotsWidth
            height: contentContainer.effectiveDotDiameter
            implicitWidth: contentContainer.dotsWidth
            implicitHeight: contentContainer.effectiveDotDiameter

            orientation: Qt.Horizontal
            spacing: contentContainer.effectiveDotSpacing
            interactive: false

            model: ScriptModel {
                values: root.buffer.split("")
            }

            delegate: Item {
                id: ch

                // Track the effective diameter AT THE TIME THIS DELEGATE WAS CREATED,
                // but keep it bound so it updates when compression kicks in.
                width: contentContainer.effectiveDotDiameter
                height: contentContainer.effectiveDotDiameter
                implicitWidth: width
                implicitHeight: height

                opacity: 0
                scale: 0.3
                Component.onCompleted: {
                    opacity = 1;
                    scale = 1;
                }
                ListView.onRemove: removeAnim.start()

                property bool isMorphed: false

                // Curated Material 3 Expressive shapes
                readonly property var expressiveShapes: [
                    MaterialShape.Cookie4Sided,
                    MaterialShape.Sunny,
                    MaterialShape.Clover4Leaf,
                    MaterialShape.Diamond,
                    MaterialShape.Heart,
                    MaterialShape.Pentagon,
                    MaterialShape.Gem,
                    MaterialShape.Boom,
                    MaterialShape.SoftBurst,
                    MaterialShape.Flower,
                    MaterialShape.Puffy,
                    MaterialShape.Bun
                ]
                readonly property int initialShape: expressiveShapes[Math.floor(Math.random() * expressiveShapes.length)]

                // ── Phase 1: M3 Expressive shape ─────────────────────────────
                MaterialShape {
                    id: dotShape
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    color: Colours.palette.m3onSurface
                    shape: ch.initialShape
                    animationDuration: Tokens.anim.durations.expressiveFastSpatial || 350
                    animationEasing: Tokens.anim.expressiveFastSpatial

                    // 6x super-sampled texture — crisp bezier curves during morph
                    textureSize: Qt.size(Math.max(128, Math.round(width * 6)), Math.max(128, Math.round(height * 6)))
                    antialiasing: true
                    smooth: true

                    // Large pop-in (1.15×), then shrinks & fades as GPU circle takes over
                    scale: ch.isMorphed ? 0.3 : 1.15
                    opacity: ch.isMorphed ? 0.0 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: Tokens.anim.durations.expressiveFastSpatial || 350
                            easing: Tokens.anim.expressiveFastSpatial
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 210; easing.type: Easing.OutCubic }
                    }

                    Timer {
                        interval: 350
                        running: true
                        repeat: false
                        onTriggered: ch.isMorphed = true
                    }
                }

                // ── Phase 2: GPU-native perfect circle ────────────────────────
                // Rectangle with radius=w/2 → Qt scene graph renders true anti-aliased
                // arc — zero bezier-polygon jaggies that MaterialShape.Circle has.
                // dotPx tracks effectiveDotDiameter (already animated) — no separate Behavior needed.
                Rectangle {
                    id: dotCircle
                    anchors.centerIn: parent

                    // Settled dot size tracks effectiveDotDiameter (which is already animated)
                    width:  Math.max(6, contentContainer.effectiveDotDiameter * 0.64)
                    height: Math.max(6, contentContainer.effectiveDotDiameter * 0.64)
                    radius: width / 2

                    color: Colours.palette.m3onSurface
                    antialiasing: true

                    opacity: ch.isMorphed ? 1.0 : 0.0
                    scale: ch.isMorphed ? 1.0 : 0.3

                    Behavior on opacity {
                        NumberAnimation { duration: 210; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Tokens.anim.durations.expressiveFastSpatial || 350
                            easing: Tokens.anim.expressiveFastSpatial
                        }
                    }
                }

                // ── Remove animation ──────────────────────────────────────────
                SequentialAnimation {
                    id: removeAnim

                    PropertyAction { target: ch; property: "ListView.delayRemove"; value: true }
                    ParallelAnimation {
                        NumberAnimation { target: ch; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InQuad }
                        NumberAnimation { target: ch; property: "scale";   to: 0.3; duration: 120; easing.type: Easing.InQuad }
                    }
                    PropertyAction { target: ch; property: "ListView.delayRemove"; value: false }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 180; easing: Tokens.anim.expressiveFastSpatial }
                }
                Behavior on scale {
                    NumberAnimation { duration: 220; easing: Tokens.anim.expressiveFastSpatial }
                }
            }
        }

        // ── Blinking caret ───────────────────────────────────────────────────
        Rectangle {
            id: cursor

            anchors.left: root.buffer.length > 0 ? charList.right : undefined
            anchors.leftMargin: root.buffer.length > 0 ? contentContainer.caretGap : 0
            x: root.buffer.length > 0 ? undefined : 0
            anchors.verticalCenter: parent.verticalCenter
            width: 2.5
            height: 22
            radius: 1.25
            color: Colours.palette.m3primary
            visible: root.visible && !root.pam.isVerifying

            Timer {
                id: blinkTimer
                interval: 530
                repeat: true
                running: cursor.visible
                onTriggered: cursor.opacity = (cursor.opacity > 0.5 ? 0.0 : 1.0)
            }

            function resetBlink() {
                cursor.opacity = 1.0;
                blinkTimer.restart();
            }
        }
    }
}
