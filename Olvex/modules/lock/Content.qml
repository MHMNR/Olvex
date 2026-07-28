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

        radius: Tokens.rounding.large

        color: bgColor

        scale: cardHover.hovered ? 1.02 : 1
        Behavior on scale { Anim { type: Anim.FastSpatial } }

        antialiasing: true

        Elevation {
            anchors.fill: parent
            radius: parent.radius
            opacity: parent.opacity
            z: -1
            level: card.elevationLevel
            visible: card.elevationLevel > 0
        }

        HoverHandler { id: cardHover }

        Item {
            id: container
            anchors.fill: parent
        }
    }

    // ── Chain-reaction stagger controller ────────────────────────────────────
    // Left cards: L1 → L2 → L3 → L4, each 70ms apart from left
    // Right cards: R1 → R2, starting 40ms after L1, 70ms apart from right
    // Exit is reverse: R2 → R1 → L4 → L3 → L2 → L1

    readonly property int stagger: 70    // ms between each card
    readonly property int dur: 850        // slide duration per card
    readonly property int exitDur: 650   // exit duration per card
    readonly property int offset: 500    // px off-screen start

    Connections {
        target: root.lock
        function onContentReadyChanged(): void {
            if (root.lock.contentReady) entranceAnim.start()
        }
        function onUnlockingChanged(): void {
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
            // Grown to absorb the height the music card gave up when its
            // internal spacing was tightened (was 160-ish, now hugs its
            // content closer to the visualizer) — keeps the column's total
            // height the same instead of leaving a gap.
            Layout.preferredHeight: 145
            transform: Translate { id: l1Trans; x: -500 }
            WeatherInfo { id: weather; rootHeight: root.height }
        }

        LockCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 140
            transform: Translate { id: l2Trans; x: -500 }
            Fetch { id: fetchId }
        }

        LockCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Direct px, same as the other cards — edit this number directly
            // to change the music card's height.
            Layout.preferredHeight: 123
            bgColor: Players.musicSurfaceColor
            elevationLevel: 3
            border.width: 1
            border.color: Qt.alpha(Players.musicOnSurfaceColor, 0.14)
            transform: Translate { id: l3Trans; x: -500 }
            Media { id: media; lock: root.lock }
        }

        LockCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 130
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
            transform: Translate { id: r1Trans; x: 500 }
            Resources { id: resources }
        }

        LockCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 230
            transform: Translate { id: r2Trans; x: 500 }
            NotifDock { id: notifDock; lock: root.lock }
        }
    }
}
