import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Olvex.Config
import qs.components
import qs.components.controls
import qs.components.images
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    anchors.fill: parent

    required property ShellScreen screen

    property bool active: false
    property bool isDismissing: false
    property bool morphAnimating: expandTransition.running || collapseTransition.running || dismissAnimation.running
    property bool closingDown: false
    property var notifData: null

    property real startX: 0
    property real startY: 0
    property real startW: 48
    property real startH: 160
    property real realIconX: 4
    property real realIconY: 4
    property real realIconW: 40
    property real realIconH: 40

    readonly property real endRadius: 28
    readonly property real startRadius: startW / 2

    readonly property int expandDur: 420
    readonly property int collapseDur: 260
    readonly property var spatialEasing: Tokens.anim.expressiveDefaultSpatial
    readonly property var spatialEasingDecel: Tokens.anim.emphasizedDecel
    readonly property int contentRevealDelay: 130

    readonly property string notifRawImage: String(root.notifData?.image ?? "")
    readonly property bool hasRealImage: {
        if (!notifRawImage || notifRawImage.length === 0)
            return false;
        if (notifRawImage.startsWith("image://icon/"))
            return false;
        if (Icons.iconNameFromUrl(notifRawImage).length > 0)
            return false;
        return notifRawImage.startsWith("/") || notifRawImage.startsWith("file://") || notifRawImage.startsWith("http://") || notifRawImage.startsWith("https://");
    }

    readonly property real targetEndH: Math.max(100, cardCol.implicitHeight + 36)
    property real endH: targetEndH
    Behavior on endH {
        enabled: notifCard.state === "expanded" && !root.morphAnimating
        NumberAnimation {
            duration: 300
            easing: Tokens.anim.expressiveDefaultSpatial
        }
    }

    readonly property real endW: 360
    
    readonly property bool opensRight: startX < root.width / 2
    readonly property real targetEndX: opensRight ? startX + startW + 20 : startX - endW - 20
    readonly property real endX: Math.max(16, Math.min(root.width - root.endW - 16, targetEndX))
    
    readonly property real targetEndY: Math.max(16, Math.min(root.height - targetEndH - 16, startY + (startH - targetEndH) / 2))
    property real endY: targetEndY
    Behavior on endY {
        enabled: notifCard.state === "expanded" && !root.morphAnimating
        NumberAnimation {
            duration: 300
            easing: Tokens.anim.expressiveDefaultSpatial
        }
    }

    visible: active || morphAnimating
    z: 2000

    Component.onCompleted: {
        Notifs.registerNotifMorph(root.screen.name, root);
    }

    Component.onDestruction: {
        Notifs.unregisterNotifMorph(root.screen.name, root);
    }

    function start(x: real, y: real, w: real, h: real,
                   iconX: real, iconY: real, iconW: real, iconH: real,
                   data: var): void {
        startX = x;
        startY = y;
        startW = w;
        startH = h;
        realIconX = iconX;
        realIconY = iconY;
        realIconW = iconW;
        realIconH = iconH;
        notifData = data;

        dismissAnimation.stop();
        hideTimer.stop();
        expandDeferred.stop();
        isDismissing = false;
        closingDown = false;

        notifCard.opacity = 1.0;
        notifCard.scale = 1.0;
        notifCard.x = startX;
        notifCard.y = startY;
        notifCard.width = startW;
        notifCard.height = startH;
        notifCard.radius = startRadius;

        active = true;
        Notifs.activeMorphNotif = data;
        Notifs.notifMorphActive = true;
        Notifs.notifMorphAnimating = true;
        notifCard.state = "docked";
        expandDeferred.start();
    }

    function collapse(): void {
        if (dismissAnimation.running || hideTimer.running || root.isDismissing)
            return;
        closingDown = true;
        Notifs.notifMorphAnimating = true;
        notifCard.state = "docked";
        hideTimer.start();
    }

    function close(): void {
        collapse();
    }

    function dismiss(): void {
        if (dismissAnimation.running || hideTimer.running)
            return;
        isDismissing = true;
        closingDown = true;
        Notifs.notifMorphAnimating = true;
        dismissAnimation.start();
    }

    Timer {
        id: expandDeferred
        interval: 16
        repeat: false
        onTriggered: {
            if (root.active && !root.closingDown && !root.isDismissing)
                notifCard.state = "expanded";
        }
    }

    Timer {
        id: hideTimer
        interval: root.collapseDur
        repeat: false
        onTriggered: {
            root.active = false;
            root.closingDown = false;
            Notifs.activeMorphNotif = null;
            Notifs.notifMorphActive = false;
            Notifs.notifMorphAnimating = false;
        }
    }

    // ── Direct Dismiss Animation (exits smoothly directly from expanded card on dismiss button) ──
    ParallelAnimation {
        id: dismissAnimation

        NumberAnimation {
            target: notifCard
            property: "opacity"
            to: 0.0
            duration: 220
            easing: Tokens.anim.expressiveFastSpatial
        }
        NumberAnimation {
            target: notifCard
            property: "scale"
            to: 0.92
            duration: 220
            easing: Tokens.anim.emphasizedAccel
        }
        NumberAnimation {
            target: notifCard
            property: "x"
            to: notifCard.x - 16
            duration: 220
            easing: Tokens.anim.emphasizedAccel
        }
        onFinished: {
            const closingNotif = root.notifData;
            root.isDismissing = false;
            root.active = false;
            root.closingDown = false;
            if (closingNotif && typeof closingNotif.close === "function")
                closingNotif.close();
            Notifs.dismissNotif(closingNotif);
            Notifs.activeMorphNotif = null;
            Notifs.notifMorphActive = false;
            Notifs.notifMorphAnimating = false;
        }
    }

    Keys.onEscapePressed: collapse()

    // ── Tap outside: collapse / morph back into bar pill (notification stays alive in bar) ──
    MouseArea {
        anchors.fill: parent
        z: 0
        enabled: root.active && !root.closingDown && !root.isDismissing
        onClicked: root.collapse()
    }

    // ── Morphing Card Container (Material 3 Container Transform) ──
    Rectangle {
        id: notifCard

        x: root.startX
        y: root.startY
        width: root.startW
        height: root.startH
        radius: root.startRadius
        color: "transparent"
        clip: true
        z: 1

        // Material 3 Expressive Container Transform uses spring-based bounding box morphing
        // We do not need artificial scale squashing or lifting if the spring physics are correct.


        state: "docked"

        // Card background: M3 container color interpolation
        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: notifCard.radius
            color: notifCard.state === "expanded" ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3secondaryContainer

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.alpha(Colours.palette.m3surfaceTint, notifCard.state === "expanded" ? 0.08 : 0.0)
            }
        }

        states: [
            State {
                name: "docked"
                PropertyChanges {
                    target: notifCard
                    x: root.startX
                    y: root.startY
                    width: root.startW
                    height: root.startH
                    radius: root.startRadius
                }
                PropertyChanges {
                    target: cardContent
                    opacity: 0
                    y: 28
                }
                PropertyChanges {
                    target: collapsedPillContent
                    opacity: 1
                }
                PropertyChanges {
                    target: heroIcon
                    x: root.realIconX
                    y: root.realIconY
                    width: root.realIconW
                    height: root.realIconH
                    radius: root.realIconW / 2
                }
            },
            State {
                name: "expanded"
                PropertyChanges {
                    target: notifCard
                    x: root.endX
                    y: root.endY
                    width: root.endW
                    height: root.endH
                    radius: root.endRadius
                }
                PropertyChanges {
                    target: cardContent
                    opacity: 1
                    y: 18
                }
                PropertyChanges {
                    target: collapsedPillContent
                    opacity: 0
                }
                PropertyChanges {
                    target: heroIcon
                    x: 18
                    y: 18
                    width: 32
                    height: 32
                    radius: 16
                }
            }
        ]

        transitions: [
            Transition {
                id: expandTransition
                from: "docked"
                to: "expanded"
                ParallelAnimation {
                    // Container bounds travel (M3 Expressive token-based easing)
                    NumberAnimation {
                        target: notifCard
                        properties: "x,y,width,height"
                        duration: root.expandDur
                        easing: root.spatialEasing
                    }
                    // Color transition
                    ColorAnimation {
                        target: cardBg
                        property: "color"
                        duration: root.expandDur
                        easing.type: Easing.OutCubic
                    }
                    // Shape mask morph
                    NumberAnimation {
                        target: notifCard
                        property: "radius"
                        duration: Math.round(root.expandDur * 0.75)
                        easing: root.spatialEasing
                    }
                    // Shared hero icon travel
                    NumberAnimation {
                        target: heroIcon
                        properties: "x,y,width,height"
                        duration: root.expandDur
                        easing: root.spatialEasing
                    }
                    NumberAnimation {
                        target: heroIcon
                        property: "radius"
                        duration: Math.round(root.expandDur * 0.75)
                        easing: root.spatialEasing
                    }
                    // Pill content fades out
                    NumberAnimation {
                        target: collapsedPillContent
                        property: "opacity"
                        duration: 110
                        easing: Tokens.anim.expressiveFastSpatial
                    }
                    // Expanded content reveals and slides up
                    ParallelAnimation {
                        NumberAnimation { target: cardContent; property: "opacity"; duration: root.expandDur - root.contentRevealDelay; easing: root.spatialEasingDecel }
                        NumberAnimation { target: cardContent; property: "y"; duration: root.expandDur - root.contentRevealDelay; easing: root.spatialEasingDecel }
                    }
                }
            },
            Transition {
                id: collapseTransition
                from: "expanded"
                to: "docked"
                enabled: !root.isDismissing
                ParallelAnimation {
                    // Container bounds travel back
                    NumberAnimation {
                        target: notifCard
                        properties: "x,y,width,height,radius"
                        duration: root.collapseDur
                        easing: root.spatialEasing
                    }
                    ColorAnimation {
                        target: cardBg
                        property: "color"
                        duration: root.collapseDur
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: heroIcon
                        properties: "x,y,width,height,radius"
                        duration: root.collapseDur
                        easing: root.spatialEasing
                    }
                    NumberAnimation {
                        target: cardContent
                        properties: "opacity,y"
                        duration: Math.round(root.collapseDur * 0.4)
                        easing: root.spatialEasing
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: Math.round(root.collapseDur * 0.3) }
                        NumberAnimation {
                            target: collapsedPillContent
                            property: "opacity"
                            duration: Math.round(root.collapseDur * 0.7)
                            easing: Tokens.anim.expressiveDefaultSpatial
                        }
                    }
                }
            }
        ]

        // ── Start (Collapsed Pill) Content Layer — Fades out on expand ──
        Item {
            id: collapsedPillContent
            width: root.startW
            height: root.startH
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            opacity: notifCard.state === "docked" ? 1 : 0

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 6

                Item {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                }

                Item {
                    id: overlayTextFrame
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Item {
                        id: rotatedOverlayWrapper
                        anchors.centerIn: parent
                        width: Math.max(1, overlayTextFrame.height)
                        height: 24

                        transform: [
                            Rotation {
                                angle: 90
                                origin.x: rotatedOverlayWrapper.width / 2
                                origin.y: rotatedOverlayWrapper.height / 2
                            }
                        ]

                        StyledText {
                            anchors.fill: parent
                            text: root.notifData?.summary || root.notifData?.appName || qsTr("Notification")
                            color: Colours.palette.m3onSecondaryContainer
                            textPointSize: Tokens.font.size.smaller
                            font.family: Tokens.font.family.mono
                            font.weight: Font.Medium
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ── Shared Hero App Icon ──
        StyledClippingRect {
            id: heroIcon
            x: notifCard.state === "expanded" ? 18 : root.realIconX
            y: notifCard.state === "expanded" ? 18 : root.realIconY
            width: notifCard.state === "expanded" ? 32 : root.realIconW
            height: notifCard.state === "expanded" ? 32 : root.realIconH
            radius: width / 2
            color: Colours.palette.m3surfaceContainerHighest
            z: 5

            CachingIconImage {
                id: heroIconImg
                anchors.fill: parent
                source: root.notifData ? Icons.getNotificationIcon(root.notifData) : ""
            }
        }

        // ── End (Expanded Card) Content Layer — Fades in on expand ──
        Item {
            id: cardContent
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.endW - 36
            anchors.top: parent.top
            anchors.margins: 18
            opacity: 0

            ColumnLayout {
                id: cardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 10

                // Header Row: App Name + Timestamp + Close button (Icon is rendered by shared heroIcon)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                    }

                    StyledText {
                        text: root.notifData?.appName || qsTr("Notification")
                        textPointSize: Tokens.font.size.small
                        font.weight: Font.DemiBold
                        color: Colours.palette.m3onSurfaceVariant
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: root.notifData?.timeStr || ""
                        textPointSize: Tokens.font.size.smaller
                        color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.7)
                    }

                    IconButton {
                        icon: "close"
                        type: IconButton.Text
                        iconPointSize: Tokens.font.size.small
                        onClicked: {
                            root.dismiss();
                        }
                    }
                }

                // Summary / Title
                StyledText {
                    text: root.notifData?.summary || ""
                    textPointSize: Tokens.font.size.normal
                    font.weight: Font.Bold
                    color: Colours.palette.m3onSurface
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    visible: text.length > 0
                }

                // Body text
                StyledText {
                    text: root.notifData?.body || ""
                    textPointSize: Tokens.font.size.small
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.85)
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                    visible: text.length > 0
                }

                // Attached Image preview — only displayed when actual media bitmap exists and is ready
                StyledClippingRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.hasRealImage && attachedImg.status === Image.Ready ? Math.min(180, Math.round(width * 0.52)) : 0
                    visible: Layout.preferredHeight > 0
                    radius: 12
                    color: "transparent"

                    Image {
                        id: attachedImg
                        anchors.fill: parent
                        source: root.hasRealImage ? Qt.resolvedUrl(root.notifRawImage) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mipmap: true
                    }
                }

                // Action Buttons Row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8

                    Repeater {
                        model: root.notifData?.actions ?? []

                        delegate: TextButton {
                            required property var modelData
                            text: modelData.text || modelData.id || qsTr("Action")
                            type: TextButton.Tonal
                            onClicked: {
                                if (root.notifData?.notification?.invokeAction) {
                                    root.notifData.notification.invokeAction(modelData.id);
                                }
                                root.dismiss();
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    TextButton {
                        text: qsTr("Dismiss")
                        type: TextButton.Text
                        onClicked: {
                            root.dismiss();
                        }
                    }
                }
            }
        }
    }
}
