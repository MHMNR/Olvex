import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services

RowLayout {
    id: root

    required property var lock

    anchors.fill: parent
    anchors.leftMargin: 120
    anchors.rightMargin: 120
    anchors.topMargin: 150
    anchors.bottomMargin: 150
    spacing: 100

    focus: true
    Component.onCompleted: forceActiveFocus()
    onActiveFocusChanged: {
        if (!activeFocus && !root.lock.unlocking)
            forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (root.lock.unlocking) return;
        root.lock.pam.handleKey(event);
    }

    // ── Reusable Glass Card Component ────────────────────────────────────────
    component LockCard : Rectangle {
        id: card
        default property alias content: container.data

        // Global color-picker token by default; the music card overrides this
        // to Players.musicSurfaceColor (the music/album-art color picker),
        // matching the bar and minimal-lock-screen music pills.
        property color bgColor: Colours.palette.m3surfaceContainerHigh

        // Opt-in drop shadow (0 = none, matches every other card's current
        // flat look by default). Only the music card raises this — see the
        // Elevation child below, gated off entirely when level is 0 so the
        // other 5 cards pay zero cost for it.
        property int elevationLevel: 0
        property real slideOffset: 0

        radius: Tokens.rounding.large

        // Base rectangle is transparent so the blurred backdrop plate shows through
        color: "transparent"

        readonly property bool blurEnabled: (GlobalConfig.appearance.transparency.blur !== false) && (GlobalConfig.lock.cardBlur !== false) && !!(root.lock && root.lock.blurredWallpaper)

        scale: 1.0

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.anim.durations.normal
                easing: Tokens.anim.emphasizedDecel
            }
        }

        antialiasing: true
        layer.enabled: root.isTransitioning
        layer.smooth: true

        Elevation {
            anchors.fill: parent
            radius: card.radius
            opacity: root.elementOpacity
            z: -1
            level: card.elevationLevel
            visible: card.elevationLevel > 0
        }

        // ── Backdrop blur plate ──────────────────────────────────────────────
        StyledClippingRect {
            id: blurPlate
            anchors.fill: parent
            radius: card.radius
            visible: card.blurEnabled

            ShaderEffectSource {
                id: backdropSample
                anchors.fill: parent
                sourceItem: card.blurEnabled ? root.lock.blurredWallpaper : null
                sourceRect: {
                    if (!card.blurEnabled || !root.lock || !root.lock.rootItem)
                        return Qt.rect(0, 0, 0, 0);
                    // Dynamically bind to slideOffset + card x/y for frame-by-frame realtime UV tracking
                    const _track = card.slideOffset + card.x + card.y;
                    const pt = card.mapToItem(root.lock.rootItem, 0, 0);
                    if (!pt || pt.x === undefined || pt.y === undefined || Number.isNaN(pt.x) || Number.isNaN(pt.y))
                        return Qt.rect(0, 0, 0, 0);
                    return Qt.rect(Math.max(0, pt.x), Math.max(0, pt.y), card.width, card.height);
                }
                live: true
                smooth: true
            }
        }

        // ── M3 Tint & Surface Overlay ────────────────────────────────────────
        Rectangle {
            id: tintPlate
            anchors.fill: parent
            radius: card.radius
            color: Qt.alpha(card.bgColor, card.blurEnabled ? Math.min(1.0, root.elementOpacity * 0.62) : root.elementOpacity)
            border.color: card.blurEnabled ? Qt.alpha(Colours.palette.m3outlineVariant, 0.28) : "transparent"
            border.width: card.blurEnabled ? 1 : 0
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.anim.durations.normal
                    easing: Tokens.anim.emphasizedDecel
                }
            }
        }

        HoverHandler { id: cardHover }

        Item {
            id: container
            anchors.fill: parent
        }
    }

    // ── Chain-reaction stagger controller ────────────────────────────────────
    // Left cards: L1 → L2 → L3 → L4, each 45ms apart from left
    // Right cards: R1 → R2, starting 30ms after L1, 45ms apart from right
    // Exit is reverse: R2 → R1 → L4 → L3 → L2 → L1

    readonly property bool isTransitioning: entranceAnim.running || exitAnim.running
    readonly property int stagger: 70    // ms between each card
    readonly property int dur: 850        // slide duration per card
    readonly property int exitDur: 650   // exit duration per card
    readonly property int offset: 500    // px off-screen start

    Connections {
        target: root.lock
        function onContentReadyChanged() {
            if (root.lock.contentReady) entranceAnim.start()
        }
        function onUnlockingChanged() {
            if (root.lock.unlocking) {
                entranceAnim.stop()
                exitAnim.start()
            } else {
                exitAnim.stop()
                // reset for next cycle
                l1Trans.x = -root.offset; l2Trans.x = -root.offset
                l3Trans.x = -root.offset; l4Trans.x = -root.offset
                r1Trans.x =  root.offset; r2Trans.x =  root.offset
            }
        }
    }

    // ── ENTER: chain reaction, left-to-right stagger ─────────────────────────
    ParallelAnimation {
        id: entranceAnim

        // Left column — cards cascade top to bottom
        SequentialAnimation {
            NumberAnimation { target: l1Trans; property: "x"; from: -root.offset; to: 0; duration: root.dur; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }
        SequentialAnimation {
            PauseAnimation { duration: root.stagger }
            NumberAnimation { target: l2Trans; property: "x"; from: -root.offset; to: 0; duration: root.dur; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }
        SequentialAnimation {
            PauseAnimation { duration: root.stagger * 2 }
            NumberAnimation { target: l3Trans; property: "x"; from: -root.offset; to: 0; duration: root.dur; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }
        SequentialAnimation {
            PauseAnimation { duration: root.stagger * 3 }
            NumberAnimation { target: l4Trans; property: "x"; from: -root.offset; to: 0; duration: root.dur; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }

        // Right column — cascade top to bottom, offset 40ms from left start
        SequentialAnimation {
            PauseAnimation { duration: 40 }
            NumberAnimation { target: r1Trans; property: "x"; from: root.offset; to: 0; duration: root.dur; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 40 + root.stagger }
            NumberAnimation { target: r2Trans; property: "x"; from: root.offset; to: 0; duration: root.dur; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }
    }

    // ── EXIT: reverse chain reaction, bottom-to-top ───────────────────────────
    ParallelAnimation {
        id: exitAnim

        // Right column — exits first (bottom then top)
        SequentialAnimation {
            PauseAnimation { duration: root.stagger }
            NumberAnimation { target: r2Trans; property: "x"; to: root.offset; duration: root.exitDur; easing.type: Easing.InExpo }
        }
        SequentialAnimation {
            NumberAnimation { target: r1Trans; property: "x"; to: root.offset; duration: root.exitDur; easing.type: Easing.InExpo }
        }

        // Left column — exits after right (bottom then top)
        SequentialAnimation {
            PauseAnimation { duration: root.stagger * 2 }
            NumberAnimation { target: l4Trans; property: "x"; to: -root.offset; duration: root.exitDur; easing.type: Easing.InExpo }
        }
        SequentialAnimation {
            PauseAnimation { duration: root.stagger * 3 }
            NumberAnimation { target: l3Trans; property: "x"; to: -root.offset; duration: root.exitDur; easing.type: Easing.InExpo }
        }
        SequentialAnimation {
            PauseAnimation { duration: root.stagger * 4 }
            NumberAnimation { target: l2Trans; property: "x"; to: -root.offset; duration: root.exitDur; easing.type: Easing.InExpo }
        }
        SequentialAnimation {
            PauseAnimation { duration: root.stagger * 5 }
            NumberAnimation { target: l1Trans; property: "x"; to: -root.offset; duration: root.exitDur; easing.type: Easing.InExpo }
        }
    }

    // ── Settings → Lock → Element opacity ────────────────────────────────────
    readonly property real elementOpacity: {
        const v = GlobalConfig.lock.minimalOpacity;
        if (v === undefined || v === null || Number.isNaN(v))
            return 1;
        return Math.max(0.05, Math.min(1, v));
    }

    // ── Left column ──────────────────────────────────────────────────────────
    ColumnLayout {
        id: leftColumn
        Layout.alignment: Qt.AlignVCenter
        Layout.fillHeight: true
        Layout.preferredWidth: 320
        Layout.maximumWidth: 320
        spacing: 20

        LockCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 145
            slideOffset: l1Trans.x
            transform: Translate { id: l1Trans; x: -500 }
            WeatherInfo { id: weather; rootHeight: root.height }
        }

        LockCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 140
            slideOffset: l2Trans.x
            transform: Translate { id: l2Trans; x: -500 }
            Fetch { id: fetchId }
        }

        LockCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 138
            bgColor: Players.musicSurfaceColor
            elevationLevel: 3
            slideOffset: l3Trans.x
            transform: Translate { id: l3Trans; x: -500 }
            Media { id: media; lock: root.lock }
        }

        LockCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 130
            slideOffset: l4Trans.x
            transform: Translate { id: l4Trans; x: -500 }
            PowerSession { id: powerSession }
        }
    }

    // ── Center ───────────────────────────────────────────────────────────────
    Item {
        id: centerItem
        Layout.fillWidth: true
        Layout.preferredHeight: leftColumn.height
        Layout.alignment: Qt.AlignVCenter

        Center {
            anchors.fill: parent
            lock: root.lock
        }
    }

    // ── Right column ─────────────────────────────────────────────────────────
    ColumnLayout {
        id: rightColumn
        Layout.alignment: Qt.AlignVCenter
        Layout.fillHeight: true
        Layout.preferredWidth: 320
        Layout.maximumWidth: 320
        spacing: 20

        LockCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 300
            slideOffset: r1Trans.x
            transform: Translate { id: r1Trans; x: 500 }
            Resources { id: resources }
        }

        LockCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 230
            slideOffset: r2Trans.x
            transform: Translate { id: r2Trans; x: 500 }
            NotifDock { id: notifDock; lock: root.lock }
        }
    }
}
