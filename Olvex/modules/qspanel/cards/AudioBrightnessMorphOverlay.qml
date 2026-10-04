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
    readonly property real contentInnerW: endW - 36
    readonly property real targetEndH: Math.max(260, Math.min(root.height - 32, cardLayout.implicitHeight + 36))

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
            contentWidth: root.contentInnerW
            contentHeight: cardLayout.implicitHeight
            clip: true

            property real slideY: morphCard.state === "docked" ? 12 : 0
            transform: Translate {
                y: cardContent.slideY
            }

            ColumnLayout {
                id: cardLayout
                width: root.contentInnerW
                spacing: 14

                // ── 1. Header Bar ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
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

                // ── 2. UNIFIED AUDIO HUB CONTAINER ──
                Rectangle {
                    id: audioHubCard
                    Layout.fillWidth: true
                    radius: Tokens.rounding.normal
                    color: Colours.tileFill
                    implicitHeight: audioHubCol.implicitHeight + 24
                    visible: Config.bar.quickOrb.showMediaVolume || Config.bar.quickOrb.showUiSounds || Config.bar.quickOrb.showMicrophone

                    Behavior on color {
                        CAnim { duration: Tokens.anim.durations.normal }
                    }

                    ColumnLayout {
                        id: audioHubCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // A. Master Media Volume
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: Config.bar.quickOrb.showMediaVolume

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

                                // M3 Morphing Square/Circle Button (GPU-rendered crisp HD)
                                Rectangle {
                                    id: volBtn
                                    width: 34
                                    height: 34
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34

                                    readonly property bool isVolActive: !Audio.muted && Audio.volume > 0.001

                                    radius: isVolActive ? Tokens.rounding.small : height / 2
                                    color: isVolActive ? Colours.palette.m3primary : (Audio.muted ? Qt.alpha(Colours.palette.m3error, 0.22) : Qt.alpha(Colours.palette.m3onSurface, 0.12))

                                    Behavior on radius {
                                        Anim { type: Anim.FastSpatial }
                                    }

                                    Behavior on color {
                                        CAnim { duration: Tokens.anim.durations.normal }
                                    }

                                    HoverHandler {
                                        id: volBtnHover
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    StateLayer {
                                        color: volBtn.isVolActive ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                                        iconPointSize: Tokens.font.size.large
                                        color: volBtn.isVolActive ? Colours.palette.m3onPrimary : (Audio.muted ? Colours.palette.m3error : Qt.alpha(Colours.palette.m3onSurface, 0.70))
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (Audio.sink && Audio.sink.audio)
                                                Audio.sink.audio.muted = !Audio.sink.audio.muted;
                                        }
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

                        // Hairline Divider 1
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.18)
                            visible: Config.bar.quickOrb.showMediaVolume && (Config.bar.quickOrb.showUiSounds || Config.bar.quickOrb.showMicrophone)
                        }

                        // B. Notification & Alerts Sound Volume
                        ColumnLayout {
                            id: notifSoundSection
                            Layout.fillWidth: true
                            spacing: 8
                            visible: Config.bar.quickOrb.showUiSounds

                            readonly property bool isNotifSoundEnabled: (GlobalConfig.services.uiSounds && GlobalConfig.services.uiSounds.enabled !== undefined) ? GlobalConfig.services.uiSounds.enabled : true
                            readonly property real notifVol: (GlobalConfig.services.uiSounds && typeof GlobalConfig.services.uiSounds.volume === "number") ? GlobalConfig.services.uiSounds.volume : 0.8
                            readonly property bool isEffectivelyMuted: !notifSoundSection.isNotifSoundEnabled || notifSoundSection.notifVol <= 0.001

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
                                    text: notifSoundSection.isEffectivelyMuted ? qsTr("Muted") : `${Math.round(notifSoundSection.notifVol * 100)}%`
                                    font.weight: 600
                                    textPointSize: Tokens.font.size.smaller
                                    color: notifSoundSection.isEffectivelyMuted ? Colours.palette.m3error : Colours.palette.m3secondary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                // M3 Morphing Square/Circle Button (GPU-rendered crisp HD)
                                Rectangle {
                                    id: notifSoundBtn
                                    width: 34
                                    height: 34
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34

                                    readonly property bool isNotifActive: !notifSoundSection.isEffectivelyMuted

                                    radius: isNotifActive ? Tokens.rounding.small : height / 2
                                    color: isNotifActive ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3error, 0.22)

                                    Behavior on radius {
                                        Anim { type: Anim.FastSpatial }
                                    }

                                    Behavior on color {
                                        CAnim { duration: Tokens.anim.durations.normal }
                                    }

                                    HoverHandler {
                                        id: notifSoundBtnHover
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    StateLayer {
                                        color: notifSoundBtn.isNotifActive ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: notifSoundBtn.isNotifActive ? "notifications" : "notifications_off"
                                        iconPointSize: Tokens.font.size.large
                                        color: notifSoundBtn.isNotifActive ? Colours.palette.m3onPrimary : Colours.palette.m3error
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (GlobalConfig.services.uiSounds) {
                                                if (notifSoundSection.isEffectivelyMuted) {
                                                    GlobalConfig.services.uiSounds.enabled = true;
                                                    if (notifSoundSection.notifVol <= 0.001)
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
                                }

                                StyledSlider {
                                    Layout.fillWidth: true
                                    showValue: false
                                    from: 0
                                    to: 1.0
                                    value: notifSoundSection.isNotifSoundEnabled ? notifSoundSection.notifVol : 0
                                    activeTrackColor: notifSoundSection.isEffectivelyMuted ? Colours.palette.m3error : Colours.palette.m3secondary
                                    thumbColor: notifSoundSection.isEffectivelyMuted ? Colours.palette.m3error : Colours.palette.m3secondary
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

                        // Hairline Divider 2
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.18)
                            visible: (Config.bar.quickOrb.showMediaVolume || Config.bar.quickOrb.showUiSounds) && Config.bar.quickOrb.showMicrophone
                        }

                        // C. Microphone Input Volume
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: Config.bar.quickOrb.showMicrophone

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

                                // M3 Morphing Square/Circle Button (GPU-rendered crisp HD)
                                Rectangle {
                                    id: micBtn
                                    width: 34
                                    height: 34
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34

                                    readonly property bool isMicActive: !Audio.sourceMuted && Audio.sourceVolume > 0.001

                                    radius: isMicActive ? Tokens.rounding.small : height / 2
                                    color: isMicActive ? Colours.palette.m3primary : (Audio.sourceMuted ? Qt.alpha(Colours.palette.m3error, 0.22) : Qt.alpha(Colours.palette.m3onSurface, 0.12))

                                    Behavior on radius {
                                        Anim { type: Anim.FastSpatial }
                                    }

                                    Behavior on color {
                                        CAnim { duration: Tokens.anim.durations.normal }
                                    }

                                    HoverHandler {
                                        id: micBtnHover
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    StateLayer {
                                        color: micBtn.isMicActive ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
                                        iconPointSize: Tokens.font.size.large
                                        color: micBtn.isMicActive ? Colours.palette.m3onPrimary : (Audio.sourceMuted ? Colours.palette.m3error : Qt.alpha(Colours.palette.m3onSurface, 0.70))
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (Audio.source && Audio.source.audio)
                                                Audio.source.audio.muted = !Audio.source.audio.muted;
                                        }
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
                }

                // ── 3. COMPACT DEVICE SWITCHERS ──
                Rectangle {
                    id: devicesCard
                    Layout.fillWidth: true
                    radius: Tokens.rounding.normal
                    color: Colours.tileFill
                    implicitHeight: devicesCol.implicitHeight + 24
                    visible: Config.bar.quickOrb.showDeviceSwitchers && ((Audio.sinks && Audio.sinks.length > 1) || (Audio.sources && Audio.sources.length > 1))

                    Behavior on color {
                        CAnim { duration: Tokens.anim.durations.normal }
                    }

                    ColumnLayout {
                        id: devicesCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        // Output Devices section
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: Audio.sinks && Audio.sinks.length > 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                StyledText {
                                    text: qsTr("Playback Output")
                                    font.weight: 600
                                    textPointSize: Tokens.font.size.smaller - 1
                                    color: Qt.alpha(Colours.palette.m3onSurface, 0.70)
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: Audio.sinks

                                    Rectangle {
                                        id: sinkChip
                                        required property PwNode modelData
                                        readonly property bool isSelected: Boolean(Audio.sink && Audio.sink.id === modelData.id)
                                        readonly property string dName: modelData.description || modelData.name || qsTr("Device")
                                        readonly property string lowerName: dName.toLowerCase()

                                        height: 28
                                        width: Math.min(devicesCard.width - 20, sinkChipRow.implicitWidth + 18)
                                        radius: isSelected ? Tokens.rounding.small : height / 2
                                        color: isSelected
                                            ? Colours.palette.m3primary
                                            : (sinkChipHover.hovered ? Colours.tileFillHover : Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.75))

                                        Behavior on radius {
                                            Anim { type: Anim.FastSpatial }
                                        }

                                        Behavior on color {
                                            CAnim { duration: Tokens.anim.durations.normal }
                                        }

                                        HoverHandler {
                                            id: sinkChipHover
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        RowLayout {
                                            id: sinkChipRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            MaterialIcon {
                                                text: {
                                                    if (sinkChip.lowerName.includes("headphone") || sinkChip.lowerName.includes("headset") || sinkChip.lowerName.includes("earphone") || sinkChip.lowerName.includes("buds") || sinkChip.lowerName.includes("airpod"))
                                                        return "headphones";
                                                    if (sinkChip.lowerName.includes("hdmi") || sinkChip.lowerName.includes("tv"))
                                                        return "tv";
                                                    return "speaker";
                                                }
                                                color: sinkChip.isSelected ? Colours.palette.m3onPrimary : Qt.alpha(Colours.palette.m3onSurface, 0.75)
                                                iconPointSize: Tokens.font.size.smaller
                                            }

                                            StyledText {
                                                text: sinkChip.dName
                                                textPointSize: Tokens.font.size.smaller - 1
                                                font.weight: sinkChip.isSelected ? 600 : 400
                                                color: sinkChip.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 150
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: Audio.setAudioSink(sinkChip.modelData)
                                        }
                                    }
                                }
                            }
                        }

                        // Subtle divider between sink & source if both exist
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.15)
                            visible: (Audio.sinks && Audio.sinks.length > 1) && (Audio.sources && Audio.sources.length > 1)
                        }

                        // Input Devices section
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: Audio.sources && Audio.sources.length > 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                StyledText {
                                    text: qsTr("Recording Input")
                                    font.weight: 600
                                    textPointSize: Tokens.font.size.smaller - 1
                                    color: Qt.alpha(Colours.palette.m3onSurface, 0.70)
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: Audio.sources

                                    Rectangle {
                                        id: sourceChip
                                        required property PwNode modelData
                                        readonly property bool isSelected: Boolean(Audio.source && Audio.source.id === modelData.id)
                                        readonly property string dName: modelData.description || modelData.name || qsTr("Mic Device")

                                        height: 28
                                        width: Math.min(devicesCard.width - 20, sourceChipRow.implicitWidth + 18)
                                        radius: isSelected ? Tokens.rounding.small : height / 2
                                        color: isSelected
                                            ? Colours.palette.m3primary
                                            : (sourceChipHover.hovered ? Colours.tileFillHover : Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.75))

                                        Behavior on radius {
                                            Anim { type: Anim.FastSpatial }
                                        }

                                        Behavior on color {
                                            CAnim { duration: Tokens.anim.durations.normal }
                                        }

                                        HoverHandler {
                                            id: sourceChipHover
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        RowLayout {
                                            id: sourceChipRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            MaterialIcon {
                                                text: "mic"
                                                color: sourceChip.isSelected ? Colours.palette.m3onPrimary : Qt.alpha(Colours.palette.m3onSurface, 0.75)
                                                iconPointSize: Tokens.font.size.smaller
                                            }

                                            StyledText {
                                                text: sourceChip.dName
                                                font.weight: sourceChip.isSelected ? 600 : 400
                                                textPointSize: Tokens.font.size.smaller - 1
                                                color: sourceChip.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 150
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
                    }
                }

                // ── 4. COLLAPSIBLE APP VOLUMES ACCORDION ──
                Rectangle {
                    id: appVolumesAccordion
                    Layout.fillWidth: true
                    radius: Tokens.rounding.normal
                    color: Colours.tileFill
                    visible: Audio.streams && Audio.streams.length > 0
                    implicitHeight: accordionCol.implicitHeight + 24

                    property bool expanded: false

                    Behavior on color {
                        CAnim { duration: Tokens.anim.durations.normal }
                    }

                    ColumnLayout {
                        id: accordionCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        // Accordion Header Row (Clickable)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: Tokens.rounding.small
                            color: headerHover.hovered ? Colours.tileFillHover : "transparent"

                            Behavior on color {
                                CAnim { duration: Tokens.anim.durations.normal }
                            }

                            HoverHandler {
                                id: headerHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            StateLayer {
                                color: Colours.palette.m3primary
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                StyledText {
                                    text: qsTr("App Volumes")
                                    font.weight: 600
                                    textPointSize: Tokens.font.size.smaller
                                    color: Colours.palette.m3onSurface
                                }

                                Rectangle {
                                    width: streamCountLabel.implicitWidth + 12
                                    height: 18
                                    radius: Tokens.rounding.full
                                    color: Qt.alpha(Colours.palette.m3primary, 0.18)

                                    StyledText {
                                        id: streamCountLabel
                                        anchors.centerIn: parent
                                        text: String(Audio.streams ? Audio.streams.length : 0)
                                        textPointSize: Tokens.font.size.smaller - 2
                                        font.weight: 600
                                        color: Colours.palette.m3primary
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                MaterialIcon {
                                    text: appVolumesAccordion.expanded ? "expand_less" : "expand_more"
                                    iconPointSize: Tokens.font.size.normal
                                    color: Qt.alpha(Colours.palette.m3onSurface, 0.65)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: appVolumesAccordion.expanded = !appVolumesAccordion.expanded
                            }
                        }

                        // Expandable stream items list container
                        Item {
                            id: expandableStreamsContainer
                            Layout.fillWidth: true
                            clip: true
                            implicitHeight: appVolumesAccordion.expanded ? streamsInnerCol.implicitHeight : 0
                            visible: implicitHeight > 0

                            Behavior on implicitHeight {
                                NumberAnimation {
                                    duration: Tokens.anim.durations.normal
                                    easing.type: Easing.OutCubic
                                }
                            }

                            ColumnLayout {
                                id: streamsInnerCol
                                width: parent.width
                                spacing: 10

                                Repeater {
                                    model: Audio.streams

                                    ColumnLayout {
                                        id: streamItem
                                        required property PwNode modelData
                                        Layout.fillWidth: true
                                        spacing: 6

                                        readonly property string streamName: Audio.getStreamName(modelData)
                                        readonly property bool isStreamMuted: Audio.getStreamMuted(modelData)
                                        readonly property real streamVol: Audio.getStreamVolume(modelData)

                                        // Subtle separator before stream item
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 1
                                            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.15)
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true

                                            StyledText {
                                                text: streamItem.streamName
                                                font.weight: 500
                                                textPointSize: Tokens.font.size.smaller
                                                color: Colours.palette.m3onSurface
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            StyledText {
                                                text: streamItem.isStreamMuted ? qsTr("Muted") : `${Math.round(streamItem.streamVol * 100)}%`
                                                font.weight: 600
                                                textPointSize: Tokens.font.size.smaller
                                                color: streamItem.isStreamMuted ? Colours.palette.m3error : Qt.alpha(Colours.palette.m3onSurface, 0.75)
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            // M3 Morphing App Stream Mute Button (34x34 matching all other buttons)
                                            Rectangle {
                                                id: streamBtn
                                                width: 34
                                                height: 34
                                                Layout.preferredWidth: 34
                                                Layout.preferredHeight: 34

                                                readonly property bool isStreamActive: !streamItem.isStreamMuted && streamItem.streamVol > 0.001

                                                radius: isStreamActive ? Tokens.rounding.small : height / 2
                                                color: isStreamActive ? Colours.palette.m3primary : (streamItem.isStreamMuted ? Qt.alpha(Colours.palette.m3error, 0.22) : Qt.alpha(Colours.palette.m3onSurface, 0.12))

                                                Behavior on radius {
                                                    Anim { type: Anim.FastSpatial }
                                                }

                                                Behavior on color {
                                                    CAnim { duration: Tokens.anim.durations.normal }
                                                }

                                                HoverHandler {
                                                    id: streamBtnHover
                                                    cursorShape: Qt.PointingHandCursor
                                                }

                                                StateLayer {
                                                    color: streamBtn.isStreamActive ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                                }

                                                MaterialIcon {
                                                    anchors.centerIn: parent
                                                    text: Icons.getVolumeIcon(streamItem.streamVol, streamItem.isStreamMuted)
                                                    iconPointSize: Tokens.font.size.large
                                                    color: streamBtn.isStreamActive ? Colours.palette.m3onPrimary : (streamItem.isStreamMuted ? Colours.palette.m3error : Qt.alpha(Colours.palette.m3onSurface, 0.70))
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Audio.setStreamMuted(streamItem.modelData, !streamItem.isStreamMuted)
                                                }
                                            }

                                            StyledSlider {
                                                Layout.fillWidth: true
                                                showValue: false
                                                from: 0
                                                to: GlobalConfig.services.maxVolume || 1.0
                                                value: streamItem.streamVol
                                                activeTrackColor: streamItem.isStreamMuted ? Colours.palette.m3error : Colours.palette.m3primary
                                                thumbColor: streamItem.isStreamMuted ? Colours.palette.m3error : Colours.palette.m3primary
                                                inactiveTrackColor: Colours.light ? Qt.alpha(Colours.palette.m3onSurface, 0.12) : Qt.alpha(Colours.palette.m3onSurface, 0.16)
                                                onMoved: Audio.setStreamVolume(streamItem.modelData, value)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 5. UNIFIED DISPLAY HUB CONTAINER ──
                Rectangle {
                    id: displayHubCard
                    Layout.fillWidth: true
                    radius: Tokens.rounding.normal
                    color: Colours.tileFill
                    implicitHeight: displayHubCol.implicitHeight + 24
                    visible: (root.hasBrightnessSupport && Config.bar.quickOrb.showBrightness) || ((typeof NightLight !== "undefined" && NightLight) && Config.bar.quickOrb.showNightLight)

                    Behavior on color {
                        CAnim { duration: Tokens.anim.durations.normal }
                    }

                    ColumnLayout {
                        id: displayHubCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        // A. Display Brightness Section
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: root.hasBrightnessSupport && Config.bar.quickOrb.showBrightness

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

                                // M3 Morphing Square/Circle Brightness Button (GPU-rendered crisp HD)
                                Rectangle {
                                    id: brightBtn
                                    width: 34
                                    height: 34
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34

                                    readonly property real curB: (root.activeMonitor && typeof root.activeMonitor.brightness === "number") ? root.activeMonitor.brightness : 0
                                    readonly property bool isBrightActive: brightBtn.curB > 0.02

                                    radius: isBrightActive ? Tokens.rounding.small : height / 2
                                    color: isBrightActive ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.12)

                                    Behavior on radius {
                                        Anim { type: Anim.FastSpatial }
                                    }

                                    Behavior on color {
                                        CAnim { duration: Tokens.anim.durations.normal }
                                    }

                                    HoverHandler {
                                        id: brightBtnHover
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    StateLayer {
                                        color: brightBtn.isBrightActive ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: `brightness_${Math.max(1, Math.min(7, Math.round(brightBtn.curB * 6) + 1))}`
                                        iconPointSize: Tokens.font.size.large
                                        color: brightBtn.isBrightActive ? Colours.palette.m3onPrimary : Qt.alpha(Colours.palette.m3onSurface, 0.70)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.activeMonitor) {
                                                const next = root.activeMonitor.brightness < 0.5 ? 1.0 : 0.2;
                                                root.activeMonitor.setBrightness(next);
                                            }
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

                        // Hairline Divider between Brightness and Night Light
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.18)
                            visible: (root.hasBrightnessSupport && Config.bar.quickOrb.showBrightness) && ((typeof NightLight !== "undefined" && NightLight) && Config.bar.quickOrb.showNightLight)
                        }

                        // B. Night Light Section (Warmth / Temperature Slider)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: (typeof NightLight !== "undefined" && NightLight) && Config.bar.quickOrb.showNightLight

                            RowLayout {
                                Layout.fillWidth: true

                                StyledText {
                                    text: qsTr("Night Light")
                                    font.weight: 500
                                    textPointSize: Tokens.font.size.smaller
                                    color: Colours.palette.m3onSurface
                                }

                                Item { Layout.fillWidth: true }

                                StyledText {
                                    text: NightLight.enabled ? `${NightLight.temperature}K` : qsTr("Off")
                                    font.weight: 600
                                    textPointSize: Tokens.font.size.smaller
                                    color: NightLight.enabled ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.50)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                // M3 Morphing Square/Circle Night Light Toggle Button
                                Rectangle {
                                    id: nlBtn
                                    width: 34
                                    height: 34
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34

                                    radius: NightLight.enabled ? Tokens.rounding.small : height / 2
                                    color: NightLight.enabled ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.12)

                                    Behavior on radius {
                                        Anim { type: Anim.FastSpatial }
                                    }

                                    Behavior on color {
                                        CAnim { duration: Tokens.anim.durations.normal }
                                    }

                                    HoverHandler {
                                        id: nlBtnHover
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    StateLayer {
                                        color: NightLight.enabled ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: NightLight.enabled ? "nightlight" : "bedtime"
                                        iconPointSize: Tokens.font.size.large
                                        color: NightLight.enabled ? Colours.palette.m3onPrimary : Qt.alpha(Colours.palette.m3onSurface, 0.70)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NightLight.toggle()
                                    }
                                }

                                StyledSlider {
                                    id: nlSlider
                                    Layout.fillWidth: true
                                    showValue: false
                                    enabled: NightLight.enabled
                                    from: 2500
                                    to: 6500
                                    stepSize: 50
                                    value: (typeof NightLight !== "undefined" && NightLight) ? NightLight.temperature : 4500
                                    activeTrackColor: NightLight.enabled ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.38)
                                    thumbColor: NightLight.enabled ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.38)
                                    inactiveTrackColor: Colours.light ? Qt.alpha(Colours.palette.m3onSurface, 0.12) : Qt.alpha(Colours.palette.m3onSurface, 0.16)
                                    opacity: NightLight.enabled ? 1.0 : 0.45

                                    Behavior on opacity {
                                        Anim { type: Anim.DefaultSpatial }
                                    }

                                    onMoved: {
                                        if (typeof NightLight !== "undefined" && NightLight)
                                            NightLight.setTemperature(Math.round(value));
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
