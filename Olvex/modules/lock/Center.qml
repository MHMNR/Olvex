
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import M3Shapes
import Olvex.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.components.widgets
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property var lock
    readonly property real centerScale: Math.min(1, ((lock && lock.rootItem && lock.rootItem.height > 0) ? lock.rootItem.height : 1080) / 1440)
    readonly property int centerWidth: Tokens.sizes.lock.centerWidth * centerScale

    Layout.preferredWidth: centerWidth
    Layout.fillWidth: false
    Layout.fillHeight: true

    spacing: 0

    property bool morphReady: false
    property bool entranceStarted: false
    property real morphDx: 0
    property real morphDy: -400
    property real morphScale: 1.0

    function prepareClockMorph() {
        const scr = root.lock && root.lock.screen ? root.lock.screen.name : "";
        const src = LockState.getDesktopClockRect(scr);
        if (src && src.visible && src.width > 0 && clockSlot.width > 0 && root.lock && root.lock.rootItem) {
            const dst = clockSlot.mapToItem(root.lock.rootItem, 0, 0);
            if (dst && Number.isFinite(dst.x) && Number.isFinite(dst.y)) {
                const s = (root.lock && root.lock.uiScale > 0) ? root.lock.uiScale : 1.0;
                const srcX = src.x / s;
                const srcY = src.y / s;
                const srcW = src.width / s;
                const srcH = src.height / s;
                const srcScale = src.scale / s;
                root.morphDx = (srcX + srcW / 2) - (dst.x + clockSlot.width / 2);
                root.morphDy = (srcY + srcH / 2) - (dst.y + clockSlot.height / 2);
                root.morphScale = (srcScale > 0 && clockCol.clockScale > 0)
                    ? Math.max(0.4, Math.min(2.2, srcScale / clockCol.clockScale))
                    : Math.max(0.4, Math.min(2.2, srcH / Math.max(1, clockSlot.height)));
                return true;
            }
        }
        root.morphDx = 0;
        root.morphDy = -400;
        root.morphScale = 1.0;
        return false;
    }

    function syncClockToDesktop() {
        if (root.entranceStarted || (root.lock && root.lock.unlocking))
            return;
        if (root.prepareClockMorph()) {
            clockCol.x = root.morphDx;
            clockCol.y = root.morphDy;
            clockCol.scale = root.morphScale;
            root.morphReady = true;
            LockState.lockClockVisible = true;
        }
    }

    function startLockEntrance() {
        if (!root.lock || !root.lock.contentReady || root.entranceStarted)
            return;
        root.prepareClockMorph();
        clockCol.x = root.morphDx;
        clockCol.y = root.morphDy;
        clockCol.scale = root.morphScale;
        root.morphReady = true;
        root.entranceStarted = true;
        LockState.lockClockVisible = true;
        entranceAnim.start();
    }

    Component.onCompleted: {
        root.syncClockToDesktop();
        if (root.lock && root.lock.contentReady)
            Qt.callLater(root.startLockEntrance);
    }

    Connections {
        target: root.parent
        ignoreUnknownSignals: true
        function onXChanged() { root.syncClockToDesktop(); }
        function onYChanged() { root.syncClockToDesktop(); }
        function onWidthChanged() { root.syncClockToDesktop(); }
        function onHeightChanged() { root.syncClockToDesktop(); }
    }

    // ── Entrance/Exit Animations ─────────────────────────────────────────────
    Connections {
        target: root.lock
        function onContentReadyChanged() {
            if (root.lock.contentReady)
                Qt.callLater(root.startLockEntrance);
        }
        function onUnlockingChanged() {
            if (root.lock.unlocking) {
                entranceAnim.stop();
                root.prepareClockMorph();
                exitAnim.restart();
            } else if (root.lock && root.lock.locked) {
                exitAnim.stop();
                // reset positions only if still locked
                root.morphReady = false;
                root.entranceStarted = false;
                LockState.lockClockVisible = false;
                clockCol.x = 0;
                clockCol.y = 0;
                clockCol.scale = 1.0;
                authTrans.y = 800;
            }
        }
    }

    ParallelAnimation {
        id: entranceAnim

        // 40ms warmup lets LockSurface finish initial FBO/blur upload before clock lifts off at 144fps
        SequentialAnimation {
            PauseAnimation { duration: 40 }
            NumberAnimation {
                property: "x"
                target: clockCol
                to: 0
                duration: 680
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]
            }
        }

        SequentialAnimation {
            PauseAnimation { duration: 40 }
            NumberAnimation {
                property: "y"
                target: clockCol
                to: 0
                duration: 680
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]
            }
        }

        SequentialAnimation {
            PauseAnimation { duration: 40 }
            NumberAnimation {
                property: "scale"
                target: clockCol
                to: 1.0
                duration: 680
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]
            }
        }

        SequentialAnimation {
            PauseAnimation { duration: 100 }
            NumberAnimation {
                target: authTrans
                property: "y"
                from: 800
                to: 0
                duration: 900
                easing.type: Easing.OutBack
                easing.overshoot: 0.7
            }
        }
    }

    ParallelAnimation {
        id: exitAnim

        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation {
                property: "x"
                target: clockCol
                to: root.morphDx
                duration: 780
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation {
                property: "y"
                target: clockCol
                to: root.morphDy
                duration: 780
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation {
                property: "scale"
                target: clockCol
                to: root.morphScale
                duration: 780
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: authTrans; property: "y"; to: 800; duration: 700; easing.type: Easing.InExpo }
        }
    }

    // ── Clock & Date (Untransformed slot for exact Desktop -> Lock Hero Morph) ─
    Item {
        id: clockSlot
        Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
        Layout.topMargin: 24
        implicitWidth: clockCol.implicitWidth
        implicitHeight: clockCol.implicitHeight
        onXChanged: root.syncClockToDesktop()
        onYChanged: root.syncClockToDesktop()
        onWidthChanged: root.syncClockToDesktop()

        SharedClock {
            id: clockCol
            x: 0
            y: 0
            transformOrigin: Item.Center
            opacity: root.morphReady ? 1 : 0
            syncFromLockState: true
            lockScreenName: root.lock && root.lock.screen ? root.lock.screen.name : ""
            wallpaper: (root.lock && root.lock.wallpaperItem) ? root.lock.wallpaperItem : null
            parentUiScale: (root.lock && root.lock.uiScale !== undefined) ? root.lock.uiScale : 1.0
            readonly property point _wpPos: {
                const _dep = x + y + width + height + scale + clockSlot.x + clockSlot.y + root.x + root.y;
                return (wallpaper && width > 0 && height > 0)
                    ? mapToItem(wallpaper, width * (1 - scale) / 2, height * (1 - scale) / 2)
                    : Qt.point(0, 0);
            }
            absX: _wpPos.x
            absY: _wpPos.y
            blurEnabled: Boolean(Config.background && Config.background.desktopClock && Config.background.desktopClock.background && Config.background.desktopClock.background.blur) && !GameMode.enabled
            clockScale: (Config.background && Config.background.desktopClock && Config.background.desktopClock.scale !== undefined)
                ? Config.background.desktopClock.scale
                : 1.0
            dateDetailFormat: "d MMMM yyyy"
            shadowEnabled: true
            shadowOpacity: 0.35
            shadowBlur: 0.6
        }
    }

    // ── Spacer to push auth card to bottom ──────────────────────────────────
    Item {
        Layout.fillHeight: true
    }

    // ── Messages Area ────────────────────────────────────────────────────────
    Item {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.large
        implicitHeight: Math.max(message.implicitHeight, stateMessage.implicitHeight)

        StyledText {
            id: stateMessage
            anchors.centerIn: parent
            width: parent.width
            readonly property string msg: {
                if (Hypr.kbLayout !== Hypr.defaultKbLayout) return qsTr("Kb layout: %1").arg(Hypr.kbLayoutFull);
                if (Hypr.capsLock) return qsTr("Caps lock is ON.");
                return "";
            }
            text: msg
            opacity: msg ? 1 : 0
            color: Colours.current.m3onSurfaceVariant
            font.family: Tokens.font.family.mono
            horizontalAlignment: Qt.AlignHCenter
            Behavior on opacity { Anim {} }
        }

        StyledText {
            id: message
            anchors.centerIn: parent
            width: parent.width
            readonly property Pam pam: root.lock.pam
            text: pam.passwd.message || pam.fprint.message || ""
            opacity: text ? 1 : 0
            color: Colours.current.m3error
            textPointSize: Tokens.font.size.small
            font.family: Tokens.font.family.mono
            horizontalAlignment: Qt.AlignHCenter
            Behavior on opacity { Anim {} }
        }
    }

    readonly property real elementOpacity: {
        const v = GlobalConfig.lock.minimalOpacity;
        if (v === undefined || v === null || Number.isNaN(v))
            return 1;
        return Math.max(0.05, Math.min(1, v));
    }

    readonly property bool blurActive: (GlobalConfig.appearance.transparency.blur !== false) && (GlobalConfig.lock.cardBlur !== false) && !!(root.lock && root.lock.blurredWallpaper)

    // ── Center Card ───────────────────────────────────────────────────────────
    Rectangle {
        id: authCard
        Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
        Layout.bottomMargin: 0
        
        transform: Translate { id: authTrans; y: 800 }
        
        implicitWidth: 340
        implicitHeight: authContent.implicitHeight + 32

        radius: Tokens.rounding.large
        color: "transparent"
        
        // ── Backdrop blur plate ──────────────────────────────────────────────
        StyledClippingRect {
            id: blurPlate
            anchors.fill: parent
            radius: authCard.radius
            visible: root.blurActive

            ShaderEffectSource {
                id: backdropSample
                anchors.fill: parent
                sourceItem: root.blurActive ? root.lock.blurredWallpaper : null
                sourceRect: {
                    if (!root.blurActive || !root.lock || !root.lock.rootItem)
                        return Qt.rect(0, 0, 0, 0);
                    // Dynamically bind to authTrans.y + authCard x/y for frame-by-frame realtime UV tracking
                    const _track = authTrans.y + authCard.x + authCard.y;
                    const pt = authCard.mapToItem(root.lock.rootItem, 0, 0);
                    if (!pt || pt.x === undefined || pt.y === undefined || Number.isNaN(pt.x) || Number.isNaN(pt.y))
                        return Qt.rect(0, 0, 0, 0);
                    const s = (root.lock && root.lock.uiScale !== undefined) ? root.lock.uiScale : 1.0;
                    return Qt.rect(Math.max(0, pt.x * s), Math.max(0, pt.y * s), authCard.width * s, authCard.height * s);
                }
                live: true
                smooth: true
            }
        }

        // ── M3 Tint & Surface Overlay ────────────────────────────────────────
        Rectangle {
            id: tintPlate
            anchors.fill: parent
            radius: authCard.radius
            color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, root.blurActive ? Math.min(1.0, root.elementOpacity * 0.62) : root.elementOpacity)
            border.color: "transparent"
            border.width: 0
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.anim.durations.normal
                    easing: Tokens.anim.emphasizedDecel
                }
            }
        }

        ColumnLayout {
            id: authContent
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── User Row: Left Spinning Avatar + Right Name & Info ───────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // ── Left Spinning Cookie Avatar ──────────────────────────────
                Item {
                    id: avatarHost
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    implicitWidth: 64
                    implicitHeight: 64

                    property real spin: 0

                    Timer {
                        id: spinTimer
                        interval: 33
                        repeat: true
                        running: root.visible && (!root.lock || (root.lock.contentReady && !root.lock.unlocking)) && !entranceAnim.running && !exitAnim.running
                        onTriggered: {
                            avatarHost.spin = (avatarHost.spin <= 0.6) ? 360 : (avatarHost.spin - 0.6);
                        }
                    }

                    // Outer spinning ring
                    MaterialShape {
                        id: avatarRing
                        anchors.fill: parent
                        z: 0
                        implicitSize: 64
                        shape: MaterialShape.Cookie12Sided
                        color: Colours.layer(Colours.current.m3primaryContainer, 1)
                        rotation: avatarHost.spin
                    }

                    // Invisible spinning mask (clips pfp + fallback icon)
                    Item {
                        id: avatarMaskWrap
                        anchors.fill: parent
                        visible: false
                        z: 0
                        layer.enabled: true

                        MaterialShape {
                            anchors.fill: parent
                            implicitSize: 64
                            shape: MaterialShape.Cookie12Sided
                            color: "white"
                            rotation: avatarHost.spin
                        }
                    }

                    // Fallback — shown when no .face image
                    Item {
                        id: avatarFallback
                        anchors.fill: parent
                        visible: pfp.status !== Image.Ready
                        z: 1
                        layer.enabled: true
                        layer.effect: Mask {
                            maskSource: avatarMaskWrap
                        }

                        MaterialShape {
                            anchors.centerIn: parent
                            implicitSize: 48
                            shape: MaterialShape.Circle
                            color: Qt.alpha(Colours.current.m3surface, 0.2)
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "person"
                            color: Colours.current.m3onSurfaceVariant
                            iconPointSize: 26
                        }
                    }

                    // Profile picture clipped to spinning Cookie mask
                    CachingImage {
                        id: pfp
                        anchors.fill: parent
                        z: 1
                        path: `${Paths.home}/.face`
                        layer.enabled: true
                        layer.effect: Mask {
                            maskSource: avatarMaskWrap
                        }
                    }
                }

                // ── Right User Name & Session Info ───────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const u = SysInfo.user || "user";
                            return u.charAt(0).toUpperCase() + u.slice(1);
                        }
                        color: Colours.palette.m3onSurface
                        textPointSize: Tokens.font.size.large
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: `${SysInfo.user}@${SysInfo.hostName} · ${SysInfo.wm}`
                        color: Colours.palette.m3onSurfaceVariant
                        font.family: Tokens.font.family.mono
                        textPointSize: Tokens.font.size.smaller - 2
                        opacity: 0.78
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }

            // ── Password Input Pill ──────────────────────────────────────────
            StyledRect {
                id: passInputContainer
                Layout.fillWidth: true
                implicitHeight: input.implicitHeight + Tokens.padding.small * 2
                color: {
                    if (root.lock.pam.passwd.message || root.lock.pam.fprint.message)
                        return Qt.alpha(Colours.palette.m3error, 0.16);
                    return passInputHover.hovered ? Colours.tileFillElevated : Colours.tileFill;
                }
                radius: Tokens.rounding.full

                Behavior on color {
                    CAnim {}
                }

                HoverHandler {
                    id: passInputHover
                    cursorShape: Qt.IBeamCursor
                }

                TapHandler {
                    onTapped: parent.forceActiveFocus()
                    cursorShape: Qt.IBeamCursor
                }

                RowLayout {
                    id: input
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    spacing: Tokens.spacing.normal

                    Item {
                        implicitWidth: implicitHeight
                        implicitHeight: fprintIcon.implicitHeight + Tokens.padding.small * 2

                        MaterialIcon {
                            id: fprintIcon
                            anchors.centerIn: parent
                            animate: true
                            text: {
                                if (root.lock.pam.fprint.tries >= GlobalConfig.lock.maxFprintTries)
                                    return "fingerprint_off";
                                if (root.lock.pam.fprint.active)
                                    return "fingerprint";
                                return "lock";
                            }
                            color: root.lock.pam.fprint.tries >= GlobalConfig.lock.maxFprintTries ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                            opacity: root.lock.pam.isVerifying ? 0 : 1
                            Behavior on opacity { Anim {} }
                        }

                        LoadingIndicator {
                            anchors.centerIn: parent
                            implicitSize: fprintIcon.implicitHeight
                            color: Colours.palette.m3primary
                            animated: root.lock.pam.isVerifying
                            opacity: root.lock.pam.isVerifying ? 1 : 0
                            Behavior on opacity { Anim {} }
                        }
                    }

                    InputField {
                        id: inputField
                        pam: root.lock.pam
                    }

                    StyledRect {
                        implicitWidth: implicitHeight
                        implicitHeight: enterIcon.implicitHeight + Tokens.padding.small * 2
                        color: root.lock.pam.buffer ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.08)
                        radius: Tokens.rounding.full

                        StateLayer {
                            color: root.lock.pam.buffer ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            onClicked: root.lock.pam.submit()
                        }

                        MaterialIcon {
                            id: enterIcon
                            anchors.centerIn: parent
                            text: "arrow_forward"
                            color: root.lock.pam.buffer ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                            font.weight: 500
                        }
                    }
                }
            }
        }
    }
}
