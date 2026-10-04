import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Pipewire
import Olvex.Config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.images
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    anchors.fill: parent

    required property ShellScreen screen

    readonly property Brightness.Monitor activeMonitor: {
        const mon = Brightness.getMonitorForScreen(root.screen);
        return mon ? mon : Brightness.getMonitor("active");
    }

    readonly property bool hasBrightnessSupport: {
        if (!activeMonitor)
            return false;
        const b = activeMonitor.brightness;
        return typeof b === "number" && !isNaN(b) && isFinite(b) && b >= 0;
    }

    readonly property alias morphCard: morphCard

    property bool active: false
    property bool morphAnimating: expandTransition.running || collapseTransition.running
    property bool closingDown: false
    property string activeMetric: "volume" // "volume" | "brightness" | "mic"

    property real startX: 0
    property real startY: 0
    property real startW: 48
    property real startH: 48
    property real realIconX: 0
    property real realIconY: 0
    property real realIconW: 48
    property real realIconH: 48

    readonly property real endRadius: 24
    readonly property real startRadius: startW / 2

    // ── M3 Expressive Tokens (Gentle Spring Bounce ~7%, tuned slightly softer than MediaMorph) ──
    readonly property int expandDur: 420
    readonly property int collapseDur: 280
    readonly property var gentleSpringCurve: [0.32, 1.07, 0.36, 1.015, 1.0, 1.0]
    readonly property var spatialEasing: gentleSpringCurve
    readonly property var spatialEasingDecel: Tokens.anim.emphasizedDecel
    readonly property int contentRevealDelay: 130

    readonly property real endW: 380
    readonly property real targetEndH: Math.max(260, Math.min(root.height - 32, cardLayout.implicitHeight + 40))

    property real endH: targetEndH
    Behavior on endH {
        enabled: morphCard.state === "expanded" && !root.morphAnimating
        NumberAnimation {
            duration: 280
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.gentleSpringCurve
        }
    }

    readonly property bool opensRight: startX < root.width / 2
    readonly property real targetEndX: opensRight ? startX + startW + 20 : startX - endW - 20
    readonly property real endX: Math.max(16, Math.min(root.width - root.endW - 16, targetEndX))

    readonly property real targetEndY: Math.max(16, Math.min(root.height - targetEndH - 32, startY + (startH - targetEndH) / 2))
    property real endY: targetEndY
    Behavior on endY {
        enabled: morphCard.state === "expanded" && !root.morphAnimating
        NumberAnimation {
            duration: 280
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.gentleSpringCurve
        }
    }

    visible: active || morphAnimating
    z: 2000

    function start(x, y, w, h, iconX, iconY, iconW, iconH, metric) {
        startX = x;
        startY = y;
        startW = w;
        startH = h;
        realIconX = iconX;
        realIconY = iconY;
        realIconW = iconW;
        realIconH = iconH;
        if (metric)
            activeMetric = metric;

        // HyperOS/M3 Interrupt Reversal: if closing down, reverse immediately
        if (root.active && root.closingDown) {
            hideTimer.stop();
            root.closingDown = false;
            morphCard.state = "expanded";
            return;
        }

        // If already expanded, toggle collapse
        if (root.active && !root.closingDown && morphCard.state === "expanded") {
            root.collapse();
            return;
        }

        hideTimer.stop();
        expandDeferred.stop();
        closingDown = false;

        morphCard.opacity = 1.0;
        morphCard.scale = 1.0;
        morphCard.x = startX;
        morphCard.y = startY;
        morphCard.width = startW;
        morphCard.height = startH;
        morphCard.radius = startRadius;

        active = true;
        morphCard.state = "docked";
        expandDeferred.start();
    }

    function collapse() {
        if (hideTimer.running)
            return;
        closingDown = true;
        morphCard.state = "docked";
        hideTimer.start();
    }

    function close() {
        collapse();
    }

    Timer {
        id: expandDeferred
        interval: 16
        repeat: false
        onTriggered: {
            if (root.active && !root.closingDown)
                morphCard.state = "expanded";
        }
    }

    Timer {
        id: hideTimer
        interval: root.collapseDur
        repeat: false
        onTriggered: {
            root.active = false;
            root.closingDown = false;
        }
    }

    Keys.onEscapePressed: collapse()

    // Backdrop Tap-outside to collapse
    MouseArea {
        anchors.fill: parent
        z: 0
        enabled: root.active && !root.closingDown
        onClicked: root.collapse()
    }

    // Material 3 Morphing Card Container
    Rectangle {
        id: morphCard

        x: root.startX
        y: root.startY
        width: root.startW
        height: root.startH
        radius: root.startRadius
        color: "transparent"
        clip: false
        z: 1

        state: "docked"

        // Clean Tonal M3 Surface Background (Zero Borders, Zero Shadows)
        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: morphCard.radius
            color: Colours.tileSurface
            antialiasing: true
            smooth: true

            Behavior on color {
                CAnim {
                    duration: Tokens.anim.durations.expressiveDefaultSpatial
                }
            }
        }

        // In-flight click absorber: allows clicking card during collapse to interrupt and re-expand
        MouseArea {
            z: 99
            anchors.fill: parent
            enabled: morphCard.state === "docked" || root.closingDown
            onClicked: mouse => {
                mouse.accepted = true;
                root.start(root.startX, root.startY, root.startW, root.startH, root.realIconX, root.realIconY, root.realIconW, root.realIconH, root.activeMetric);
            }
        }

        states: [
            State {
                name: "docked"
                PropertyChanges {
                    target: morphCard
                    x: root.startX
                    y: root.startY
                    width: root.startW
                    height: root.startH
                    radius: root.startRadius
                }
                PropertyChanges {
                    target: cardBg
                    color: Colours.tileSurface
                }
                PropertyChanges {
                    target: cardContent
                    opacity: 0
                    slideY: 12
                }
                PropertyChanges {
                    target: collapsedPillContent
                    opacity: 1
                    scale: 1.0
                }
            },
            State {
                name: "expanded"
                PropertyChanges {
                    target: morphCard
                    x: root.endX
                    y: root.endY
                    width: root.endW
                    height: root.endH
                    radius: root.endRadius
                }
                PropertyChanges {
                    target: cardBg
                    color: Colours.tileSurface
                }
                PropertyChanges {
                    target: cardContent
                    opacity: 1
                    slideY: 0
                }
                PropertyChanges {
                    target: collapsedPillContent
                    opacity: 0
                    scale: 0.92
                }
            }
        ]

        transitions: [
            Transition {
                id: expandTransition
                from: "docked"
                to: "expanded"
                ParallelAnimation {
                    // Container bounds travel (Calibrated gentle spring ~7%)
                    NumberAnimation {
                        target: morphCard
                        properties: "x,y,width,height"
                        duration: root.expandDur
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.spatialEasing
                    }
                    // Color transition
                    ColorAnimation {
                        target: cardBg
                        property: "color"
                        duration: root.expandDur
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.spatialEasing
                    }
                    // Shape mask morph
                    NumberAnimation {
                        target: morphCard
                        property: "radius"
                        duration: Math.round(root.expandDur * 0.75)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.spatialEasing
                    }
                    // Pill content fades out cleanly & quickly (exact 90ms matching notif pill)
                    ParallelAnimation {
                        NumberAnimation {
                            target: collapsedPillContent
                            property: "opacity"
                            duration: 90
                            easing: Tokens.anim.expressiveFastSpatial
                        }
                        NumberAnimation {
                            target: collapsedPillContent
                            property: "scale"
                            duration: 90
                            easing: Tokens.anim.expressiveFastSpatial
                        }
                    }
                    // Expanded content reveals smoothly once container is wide enough (exact 130ms delay + spatialEasingDecel)
                    SequentialAnimation {
                        PauseAnimation { duration: root.contentRevealDelay }
                        ParallelAnimation {
                            NumberAnimation {
                                target: cardContent
                                property: "opacity"
                                duration: root.expandDur - root.contentRevealDelay
                                easing: root.spatialEasingDecel
                            }
                            NumberAnimation {
                                target: cardContent
                                property: "slideY"
                                duration: root.expandDur - root.contentRevealDelay
                                easing: root.spatialEasingDecel
                            }
                        }
                    }
                }
            },
            Transition {
                id: collapseTransition
                from: "expanded"
                to: "docked"
                onRunningChanged: {
                    if (!running && root.closingDown) {
                        hideTimer.stop();
                        root.active = false;
                        root.closingDown = false;
                    }
                }
                ParallelAnimation {
                    // Container bounds travel back with gentle spring bounce (~7%)
                    NumberAnimation {
                        target: morphCard
                        properties: "x,y,width,height,radius"
                        duration: root.collapseDur
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.gentleSpringCurve
                    }
                    ColorAnimation {
                        target: cardBg
                        property: "color"
                        duration: root.collapseDur
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.gentleSpringCurve
                    }
                    // Card content glides down and fades out smoothly as container begins to collapse
                    ParallelAnimation {
                        NumberAnimation {
                            target: cardContent
                            property: "opacity"
                            duration: Math.round(root.collapseDur * 0.4)
                            easing: Tokens.anim.expressiveFastSpatial
                        }
                        NumberAnimation {
                            target: cardContent
                            property: "slideY"
                            duration: Math.round(root.collapseDur * 0.4)
                            easing: Tokens.anim.expressiveFastSpatial
                        }
                    }
                    // Pill content fades in smoothly as card approaches pill bounds
                    SequentialAnimation {
                        PauseAnimation { duration: Math.round(root.collapseDur * 0.3) }
                        ParallelAnimation {
                            NumberAnimation {
                                target: collapsedPillContent
                                property: "opacity"
                                duration: Math.round(root.collapseDur * 0.7)
                                easing: Tokens.anim.expressiveDefaultSpatial
                            }
                            NumberAnimation {
                                target: collapsedPillContent
                                property: "scale"
                                duration: Math.round(root.collapseDur * 0.7)
                                easing: root.spatialEasingDecel
                            }
                        }
                    }
                }
            }
        ]

        // Collapsed Shared-Hero Content (Identical to resting taskbar circle)
        Item {
            id: collapsedPillContent
            width: root.startW
            height: root.startH
            anchors.centerIn: parent
            transformOrigin: Item.Center
            opacity: morphCard.state === "docked" ? 1 : 0
            scale: morphCard.state === "docked" ? 1.0 : 0.90

            // Circular Gauge Progress Ring
            Shape {
                id: morphProgressShape
                anchors.fill: parent
                anchors.margins: 3
                preferredRendererType: Shape.CurveRenderer
                asynchronous: true

                readonly property real currentVal: {
                    if (root.activeMetric === "brightness") {
                        const b = (root.activeMonitor && typeof root.activeMonitor.brightness === "number") ? root.activeMonitor.brightness : 0;
                        return Math.max(0, Math.min(1.0, b));
                    } else if (root.activeMetric === "mic") {
                        return Audio.sourceMuted ? 0 : Math.max(0, Math.min(1.0, Audio.sourceVolume / (GlobalConfig.services.maxVolume || 1.0)));
                    } else {
                        return Audio.muted ? 0 : Math.max(0, Math.min(1.0, Audio.volume / (GlobalConfig.services.maxVolume || 1.0)));
                    }
                }

                readonly property color ringAccent: {
                    if (root.activeMetric === "brightness") {
                        return Colours.palette.m3tertiary;
                    } else if (root.activeMetric === "mic") {
                        return Audio.sourceMuted ? Colours.palette.m3error : Colours.palette.m3secondary;
                    } else {
                        return Audio.muted ? Colours.palette.m3error : Colours.palette.m3primary;
                    }
                }

                readonly property real strokeW: 3
                readonly property real arcR: (width - strokeW) / 2
                readonly property real cX: width / 2
                readonly property real cY: height / 2

                // Inactive Track
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.alpha(Colours.palette.m3onSurface, 0.14)
                    strokeWidth: morphProgressShape.strokeW
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        startAngle: -90
                        sweepAngle: 360
                        radiusX: morphProgressShape.arcR
                        radiusY: morphProgressShape.arcR
                        centerX: morphProgressShape.cX
                        centerY: morphProgressShape.cY
                    }
                }

                // Active Track
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: morphProgressShape.ringAccent
                    strokeWidth: morphProgressShape.strokeW
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        startAngle: -90
                        sweepAngle: Math.max(0.1, 360 * morphProgressShape.currentVal)
                        radiusX: morphProgressShape.arcR
                        radiusY: morphProgressShape.arcR
                        centerX: morphProgressShape.cX
                        centerY: morphProgressShape.cY
                    }
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                iconPointSize: Tokens.font.size.large
                fill: 1

                text: {
                    if (root.activeMetric === "brightness") {
                        const b = (root.activeMonitor && typeof root.activeMonitor.brightness === "number") ? root.activeMonitor.brightness : 0;
                        return `brightness_${Math.max(1, Math.min(7, Math.round(b * 6) + 1))}`;
                    } else if (root.activeMetric === "mic") {
                        return Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted);
                    } else {
                        return Icons.getVolumeIcon(Audio.volume, Audio.muted);
                    }
                }

                color: {
                    if (root.activeMetric === "brightness") {
                        return Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3tertiary;
                    } else if (root.activeMetric === "mic") {
                        return Audio.sourceMuted ? Colours.palette.m3error : (Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3secondary);
                    } else {
                        return Audio.muted ? Colours.palette.m3error : (Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3primary);
                    }
                }
            }
        }

        // Expanded Rich Content (Olvex Clean Element Design)
        StyledFlickable {
            id: cardContent
            anchors.fill: parent
            anchors.margins: 18
            contentWidth: width
            contentHeight: cardLayout.implicitHeight
            clip: true

            property real slideY: morphCard.state === "docked" ? 12 : 0
            transform: Translate {
                y: cardContent.slideY
            }

            ColumnLayout {
                id: cardLayout
                width: parent.width
                spacing: 14

                // ── 1. Header Bar ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: Qt.alpha(Colours.palette.m3primary, 0.16)

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "tune"
                            color: Colours.palette.m3primary
                            iconPointSize: Tokens.font.size.normal
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: root.hasBrightnessSupport ? qsTr("Sound & Display") : qsTr("Sound & Audio")
                            font.weight: 600
                            textPointSize: Tokens.font.size.normal
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            text: {
                                const sinkName = (Audio.sink && Audio.sink.description) ? Audio.sink.description : ((Audio.sink && Audio.sink.name) ? Audio.sink.name : qsTr("Default Output"));
                                return sinkName;
                            }
                            textPointSize: Tokens.font.size.smaller
                            font.weight: 400
                            color: Qt.alpha(Colours.palette.m3onSurface, 0.60)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Close Button
                    IconButton {
                        icon: "close"
                        type: IconButton.Text
                        inactiveOnColour: Qt.alpha(Colours.palette.m3onSurface, 0.70)
                        onClicked: root.collapse()
                    }
                }

                // Subtle Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.alpha(Colours.palette.m3outlineVariant, 0.25)
                }

                // ── 2. SECTION: SOUND & AUDIO ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialIcon {
                        text: "volume_up"
                        iconPointSize: Tokens.font.size.smaller - 2
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.55)
                    }

                    StyledText {
                        text: qsTr("SOUND & AUDIO")
                        font.weight: 700
                        font.letterSpacing: 0.8
                        textPointSize: Tokens.font.size.smaller - 2
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.55)
                    }
                }

                // Master Media Volume Tile
                Rectangle {
                    Layout.fillWidth: true
                    radius: Tokens.rounding.normal ?? 16
                    color: volHover.hovered ? Colours.tileFillHover : Colours.tileFill
                    implicitHeight: volumeCol.implicitHeight + 24

                    Behavior on color {
                        CAnim {
                            duration: Tokens.anim.durations.normal
                        }
                    }

                    HoverHandler {
                        id: volHover
                    }

                    ColumnLayout {
                        id: volumeCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                text: qsTr("Media Volume")
                                font.weight: 500
                                textPointSize: Tokens.font.size.smaller
                                color: Colours.palette.m3onSurface
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: Audio.muted ? qsTr("Muted") : `${Math.round(Audio.volume * 100)}%`
                                font.weight: 600
                                textPointSize: Tokens.font.size.smaller
                                color: Audio.muted ? Colours.palette.m3error : Colours.palette.m3primary
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            IconButton {
                                icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                                type: IconButton.Tonal
                                inactiveColour: Audio.muted ? Qt.alpha(Colours.palette.m3error, 0.22) : Qt.alpha(Colours.palette.m3primary, 0.18)
                                inactiveOnColour: Audio.muted ? Colours.palette.m3error : Colours.palette.m3primary
                                onClicked: {
                                    if (Audio.sink && Audio.sink.audio)
                                        Audio.sink.audio.muted = !Audio.sink.audio.muted;
                                }
                            }

                            StyledSlider {
                                Layout.fillWidth: true
                                showValue: false
                                from: 0
                                to: GlobalConfig.services.maxVolume || 1.0
                                value: Audio.volume
                                activeTrackColor: Audio.muted ? Colours.palette.m3error : Colours.palette.m3primary
                                thumbColor: Audio.muted ? Colours.palette.m3error : Colours.palette.m3primary
                                inactiveTrackColor: Colours.light ? Qt.alpha(Colours.palette.m3onSurface, 0.12) : Qt.alpha(Colours.palette.m3onSurface, 0.16)
                                onMoved: Audio.setVolume(value)
                            }
                        }
                    }
                }

                // Notification & Alert Sound Volume Tile
                Rectangle {
                    id: notifSoundTile
                    Layout.fillWidth: true
                    radius: Tokens.rounding.normal ?? 16
                    color: notifSoundHover.hovered ? Colours.tileFillHover : Colours.tileFill
                    implicitHeight: notifSoundCol.implicitHeight + 24

                    Behavior on color {
                        CAnim {
                            duration: Tokens.anim.durations.normal
                        }
                    }

                    HoverHandler {
                        id: notifSoundHover
                    }

                    readonly property bool isNotifSoundEnabled: (GlobalConfig.services.uiSounds && GlobalConfig.services.uiSounds.enabled !== undefined) ? GlobalConfig.services.uiSounds.enabled : true
                    readonly property real notifVol: (GlobalConfig.services.uiSounds && typeof GlobalConfig.services.uiSounds.volume === "number") ? GlobalConfig.services.uiSounds.volume : 0.8
                    readonly property bool isEffectivelyMuted: !notifSoundTile.isNotifSoundEnabled || notifSoundTile.notifVol <= 0.001

                    Timer {
                        id: notifPreviewDebounce
                        interval: 250
                        repeat: false
                        onTriggered: {
                            GlobalConfig.save();
                            if (UiSounds && typeof UiSounds.preview === "function") {
                                const soundFile = (GlobalConfig.services.uiSounds && GlobalConfig.services.uiSounds.notificationsSound) ? GlobalConfig.services.uiSounds.notificationsSound : "notif.mp3";
                                UiSounds.preview(soundFile);
                            }
                        }
                    }

                    ColumnLayout {
                        id: notifSoundCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                text: qsTr("Notification & Alerts")
                                font.weight: 500
                                textPointSize: Tokens.font.size.smaller
                                color: Colours.palette.m3onSurface
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: notifSoundTile.isEffectivelyMuted ? qsTr("Muted") : `${Math.round(notifSoundTile.notifVol * 100)}%`
                                font.weight: 600
                                textPointSize: Tokens.font.size.smaller
                                color: notifSoundTile.isEffectivelyMuted ? Colours.palette.m3error : Colours.palette.m3secondary
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            IconButton {
                                icon: notifSoundTile.isEffectivelyMuted ? "notifications_off" : "notifications"
                                type: IconButton.Tonal
                                inactiveColour: notifSoundTile.isEffectivelyMuted ? Qt.alpha(Colours.palette.m3error, 0.22) : Qt.alpha(Colours.palette.m3secondary, 0.18)
                                inactiveOnColour: notifSoundTile.isEffectivelyMuted ? Colours.palette.m3error : Colours.palette.m3secondary
                                onClicked: {
                                    if (GlobalConfig.services.uiSounds) {
                                        if (notifSoundTile.isEffectivelyMuted) {
                                            GlobalConfig.services.uiSounds.enabled = true;
                                            if (notifSoundTile.notifVol <= 0.001)
                                                GlobalConfig.services.uiSounds.volume = 0.8;
                                            GlobalConfig.save();
                                            notifPreviewDebounce.restart();
                                        } else {
                                            GlobalConfig.services.uiSounds.enabled = false;
                                            GlobalConfig.save();
                                        }
                                    }
                                }
                            }

                            StyledSlider {
                                Layout.fillWidth: true
                                showValue: false
                                from: 0
                                to: 1.0
                                value: notifSoundTile.isNotifSoundEnabled ? notifSoundTile.notifVol : 0
                                activeTrackColor: notifSoundTile.isEffectivelyMuted ? Colours.palette.m3error : Colours.palette.m3secondary
                                thumbColor: notifSoundTile.isEffectivelyMuted ? Colours.palette.m3error : Colours.palette.m3secondary
                                inactiveTrackColor: Colours.light ? Qt.alpha(Colours.palette.m3onSurface, 0.12) : Qt.alpha(Colours.palette.m3onSurface, 0.16)
                                onMoved: {
                                    if (GlobalConfig.services.uiSounds) {
                                        if (!GlobalConfig.services.uiSounds.enabled)
                                            GlobalConfig.services.uiSounds.enabled = true;
                                        GlobalConfig.services.uiSounds.volume = value;
                                        notifPreviewDebounce.restart();
                                    }
                                }
                            }
                        }
                    }
                }

                // Microphone Input Volume Tile
                Rectangle {
                    id: micTile
                    Layout.fillWidth: true
                    radius: Tokens.rounding.normal ?? 16
                    color: micHover.hovered ? Colours.tileFillHover : Colours.tileFill
                    implicitHeight: micCol.implicitHeight + 24

                    Behavior on color {
                        CAnim {
                            duration: Tokens.anim.durations.normal
                        }
                    }

                    HoverHandler {
                        id: micHover
                    }

                    ColumnLayout {
                        id: micCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                text: qsTr("Microphone Input")
                                font.weight: 500
                                textPointSize: Tokens.font.size.smaller
                                color: Colours.palette.m3onSurface
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: Audio.sourceMuted ? qsTr("Muted") : `${Math.round(Audio.sourceVolume * 100)}%`
                                font.weight: 600
                                textPointSize: Tokens.font.size.smaller
                                color: Audio.sourceMuted ? Colours.palette.m3error : Colours.palette.m3secondary
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            IconButton {
                                icon: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
                                type: IconButton.Tonal
                                inactiveColour: Audio.sourceMuted ? Qt.alpha(Colours.palette.m3error, 0.22) : Qt.alpha(Colours.palette.m3secondary, 0.18)
                                inactiveOnColour: Audio.sourceMuted ? Colours.palette.m3error : Colours.palette.m3secondary
                                onClicked: {
                                    if (Audio.source && Audio.source.audio)
                                        Audio.source.audio.muted = !Audio.source.audio.muted;
                                }
                            }

                            StyledSlider {
                                Layout.fillWidth: true
                                showValue: false
                                from: 0
                                to: GlobalConfig.services.maxVolume || 1.0
                                value: Audio.sourceVolume
                                activeTrackColor: Audio.sourceMuted ? Colours.palette.m3error : Colours.palette.m3secondary
                                thumbColor: Audio.sourceMuted ? Colours.palette.m3error : Colours.palette.m3secondary
                                inactiveTrackColor: Colours.light ? Qt.alpha(Colours.palette.m3onSurface, 0.12) : Qt.alpha(Colours.palette.m3onSurface, 0.16)
                                onMoved: Audio.setSourceVolume(value)
                            }
                        }
                    }
                }

                // Input Device Switcher (when multiple sources exist)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: Audio.sources && Audio.sources.length > 1

                    StyledText {
                        text: qsTr("Input Devices")
                        font.weight: 600
                        textPointSize: Tokens.font.size.smaller
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.85)
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: Audio.sources

                            Rectangle {
                                id: sourceChip
                                required property PwNode modelData
                                readonly property bool isSelected: Boolean(Audio.source && Audio.source.id === modelData.id)
                                readonly property string dName: modelData.description || modelData.name || qsTr("Mic Device")

                                height: 32
                                width: sourceChipRow.implicitWidth + 20
                                radius: Tokens.rounding.full
                                color: isSelected ? Qt.alpha(Colours.palette.m3secondary, 0.24) : (sourceChipHover.hovered ? Colours.tileFillHover : Colours.tileFill)

                                Behavior on color {
                                    CAnim { duration: Tokens.anim.durations.normal }
                                }

                                HoverHandler { id: sourceChipHover; cursorShape: Qt.PointingHandCursor }

                                RowLayout {
                                    id: sourceChipRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    MaterialIcon {
                                        text: "mic"
                                        color: sourceChip.isSelected ? Colours.palette.m3secondary : Qt.alpha(Colours.palette.m3onSurface, 0.70)
                                        iconPointSize: Tokens.font.size.smaller - 2
                                    }

                                    StyledText {
                                        text: sourceChip.dName
                                        font.weight: sourceChip.isSelected ? 600 : 400
                                        textPointSize: Tokens.font.size.smaller - 1
                                        color: sourceChip.isSelected ? Colours.palette.m3secondary : Colours.palette.m3onSurface
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Audio.setAudioSource(sourceChip.modelData)
                                }
                            }
                        }
                    }
                }

                // Output Device Switcher (when multiple sinks exist)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: Audio.sinks && Audio.sinks.length > 1

                    StyledText {
                        text: qsTr("Output Devices")
                        font.weight: 600
                        textPointSize: Tokens.font.size.smaller
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.85)
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: Audio.sinks

                            Rectangle {
                                id: devChip
                                required property PwNode modelData
                                readonly property bool isSelected: Boolean(Audio.sink && Audio.sink.id === modelData.id)
                                readonly property string dName: modelData.description || modelData.name || qsTr("Device")
                                readonly property string lowerName: dName.toLowerCase()

                                width: Math.min(cardContent.width, deviceRow.implicitWidth + 24)
                                height: 34
                                radius: Tokens.rounding.full
                                color: isSelected
                                    ? Qt.alpha(Colours.palette.m3primary, 0.28)
                                    : (devHover.hovered ? Colours.tileFillHover : Colours.tileFill)

                                Behavior on color {
                                    CAnim {
                                        duration: Tokens.anim.durations.normal
                                    }
                                }

                                HoverHandler {
                                    id: devHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                RowLayout {
                                    id: deviceRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    MaterialIcon {
                                        text: {
                                            if (lowerName.includes("headphone") || lowerName.includes("headset") || lowerName.includes("earphone") || lowerName.includes("buds") || lowerName.includes("airpod"))
                                                return "headphones";
                                            if (lowerName.includes("hdmi") || lowerName.includes("tv"))
                                                return "tv";
                                            return "speaker";
                                        }
                                        color: isSelected ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.85)
                                        iconPointSize: Tokens.font.size.smaller
                                    }

                                    StyledText {
                                        text: dName
                                        textPointSize: Tokens.font.size.smaller
                                        font.weight: isSelected ? 600 : 400
                                        color: isSelected ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 180
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Audio.setAudioSink(modelData)
                                }
                            }
                        }
                    }
                }

                // Per-App Volume Streams (in serial with Sound!)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: Audio.streams && Audio.streams.length > 0

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: qsTr("App Volumes")
                            font.weight: 600
                            textPointSize: Tokens.font.size.smaller
                            color: Qt.alpha(Colours.palette.m3onSurface, 0.85)
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: streamCountText.implicitWidth + 12
                            height: 20
                            radius: Tokens.rounding.full
                            color: Qt.alpha(Colours.palette.m3primary, 0.18)

                            StyledText {
                                id: streamCountText
                                anchors.centerIn: parent
                                text: String(Audio.streams ? Audio.streams.length : 0)
                                textPointSize: Tokens.font.size.smaller
                                font.weight: 600
                                color: Colours.palette.m3primary
                            }
                        }
                    }

                    // Streams list
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: Audio.streams

                            Rectangle {
                                id: streamItem
                                required property PwNode modelData
                                Layout.fillWidth: true
                                radius: Tokens.rounding.normal ?? 16
                                color: streamHover.hovered ? Colours.tileFillHover : Colours.tileFill
                                implicitHeight: streamCol.implicitHeight + 24

                                Behavior on color {
                                    CAnim {
                                        duration: Tokens.anim.durations.normal
                                    }
                                }

                                HoverHandler {
                                    id: streamHover
                                }

                                readonly property string streamName: Audio.getStreamName(modelData)
                                readonly property bool isStreamMuted: Audio.getStreamMuted(modelData)
                                readonly property real streamVol: Audio.getStreamVolume(modelData)

                                ColumnLayout {
                                    id: streamCol
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        // App Category / Icon badge
                                        Rectangle {
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: Qt.alpha(Colours.palette.m3primary, 0.16)

                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                text: Icons.getAppCategoryIcon(streamName, "audiotrack")
                                                color: Colours.palette.m3primary
                                                iconPointSize: Tokens.font.size.smaller - 2
                                            }
                                        }

                                        StyledText {
                                            text: streamName
                                            font.weight: 500
                                            textPointSize: Tokens.font.size.smaller
                                            color: Colours.palette.m3onSurface
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        StyledText {
                                            text: isStreamMuted ? qsTr("Muted") : `${Math.round(streamVol * 100)}%`
                                            font.weight: 600
                                            textPointSize: Tokens.font.size.smaller
                                            color: isStreamMuted ? Colours.palette.m3error : Qt.alpha(Colours.palette.m3onSurface, 0.75)
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        IconButton {
                                            icon: Icons.getVolumeIcon(streamVol, isStreamMuted)
                                            type: IconButton.Tonal
                                            inactiveColour: isStreamMuted ? Qt.alpha(Colours.palette.m3error, 0.22) : Qt.alpha(Colours.palette.m3primary, 0.18)
                                            inactiveOnColour: isStreamMuted ? Colours.palette.m3error : Colours.palette.m3primary
                                            onClicked: Audio.setStreamMuted(modelData, !isStreamMuted)
                                        }

                                        StyledSlider {
                                            Layout.fillWidth: true
                                            showValue: false
                                            from: 0
                                            to: GlobalConfig.services.maxVolume || 1.0
                                            value: streamVol
                                            activeTrackColor: isStreamMuted ? Colours.palette.m3error : Colours.palette.m3primary
                                            thumbColor: isStreamMuted ? Colours.palette.m3error : Colours.palette.m3primary
                                            inactiveTrackColor: Colours.light ? Qt.alpha(Colours.palette.m3onSurface, 0.12) : Qt.alpha(Colours.palette.m3onSurface, 0.16)
                                            onMoved: Audio.setStreamVolume(modelData, value)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 3. SECTION: DISPLAY & SCREEN ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: root.hasBrightnessSupport || (typeof NightLight !== "undefined" && NightLight)

                    // Subtle Section Divider
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.20)
                    }

                    // Mini-heading
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialIcon {
                            text: "brightness_medium"
                            iconPointSize: Tokens.font.size.smaller - 2
                            color: Qt.alpha(Colours.palette.m3onSurface, 0.55)
                        }

                        StyledText {
                            text: qsTr("DISPLAY & SCREEN")
                            font.weight: 700
                            font.letterSpacing: 0.8
                            textPointSize: Tokens.font.size.smaller - 2
                            color: Qt.alpha(Colours.palette.m3onSurface, 0.55)
                        }
                    }

                    // Display Brightness Tile (only shown if brightness is supported)
                    Rectangle {
                        Layout.fillWidth: true
                        radius: Tokens.rounding.normal ?? 16
                        color: brightHover.hovered ? Colours.tileFillHover : Colours.tileFill
                        implicitHeight: brightnessCol.implicitHeight + 24
                        visible: root.hasBrightnessSupport

                        Behavior on color {
                            CAnim {
                                duration: Tokens.anim.durations.normal
                            }
                        }

                        HoverHandler {
                            id: brightHover
                        }

                        ColumnLayout {
                            id: brightnessCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                StyledText {
                                    text: qsTr("Display Brightness")
                                    font.weight: 500
                                    textPointSize: Tokens.font.size.smaller
                                    color: Colours.palette.m3onSurface
                                }

                                Item { Layout.fillWidth: true }

                                StyledText {
                                    text: `${Math.round(((root.activeMonitor && typeof root.activeMonitor.brightness === "number") ? root.activeMonitor.brightness : 0) * 100)}%`
                                    font.weight: 600
                                    textPointSize: Tokens.font.size.smaller
                                    color: Colours.palette.m3tertiary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                IconButton {
                                    icon: {
                                        const b = (root.activeMonitor && typeof root.activeMonitor.brightness === "number") ? root.activeMonitor.brightness : 0;
                                        return `brightness_${Math.max(1, Math.min(7, Math.round(b * 6) + 1))}`;
                                    }
                                    type: IconButton.Tonal
                                    inactiveColour: Qt.alpha(Colours.palette.m3tertiary, 0.18)
                                    inactiveOnColour: Colours.palette.m3tertiary
                                    onClicked: {
                                        if (root.activeMonitor) {
                                            const next = root.activeMonitor.brightness < 0.5 ? 1.0 : 0.2;
                                            root.activeMonitor.setBrightness(next);
                                        }
                                    }
                                }

                                StyledSlider {
                                    Layout.fillWidth: true
                                    showValue: false
                                    from: 0
                                    to: 1.0
                                    value: (root.activeMonitor && typeof root.activeMonitor.brightness === "number") ? root.activeMonitor.brightness : 0
                                    thumbColor: Colours.palette.m3tertiary
                                    activeTrackColor: Colours.palette.m3tertiary
                                    inactiveTrackColor: Colours.light ? Qt.alpha(Colours.palette.m3onSurface, 0.12) : Qt.alpha(Colours.palette.m3onSurface, 0.16)
                                    onMoved: {
                                        if (root.activeMonitor)
                                            root.activeMonitor.setBrightness(value);
                                    }
                                }
                            }
                        }
                    }

                    // Night Light Chip
                    Rectangle {
                        id: nlChip
                        Layout.fillWidth: true
                        height: 40
                        radius: Tokens.rounding.full
                        color: NightLight.enabled
                            ? Qt.alpha(Colours.palette.m3tertiary, 0.28)
                            : (nlHover.hovered ? Colours.tileFillHover : Colours.tileFill)

                        Behavior on color {
                            CAnim {
                                duration: Tokens.anim.durations.normal
                            }
                        }

                        HoverHandler {
                            id: nlHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            MaterialIcon {
                                text: NightLight.enabled ? "nightlight" : "bedtime"
                                color: NightLight.enabled ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
                                iconPointSize: Tokens.font.size.smaller
                            }

                            StyledText {
                                text: qsTr("Night Light")
                                textPointSize: Tokens.font.size.smaller
                                font.weight: 500
                                color: NightLight.enabled ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: NightLight.toggle()
                        }
                    }
                }
            }
        }
    }
}
