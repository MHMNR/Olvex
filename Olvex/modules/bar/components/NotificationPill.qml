import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import M3Shapes
import Olvex
import Olvex.Config
import qs.components
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property var bar

    readonly property bool hasNotif: Notifs.hasBarNotif
    readonly property var currentNotif: Notifs.currentBarNotif
    readonly property var olderNotifs: {
        if (!root.hasNotif || !Notifs.barQueue)
            return [];
        return Notifs.barQueue.filter(n => n && !n.closed && n !== root.currentNotif);
    }
    readonly property int notifCount: (root.hasNotif ? 1 : 0) + olderNotifs.length

    readonly property int pillWidth: 48
    readonly property real pillRadius: pillWidth / 2

    readonly property real olderCirclesHeight: {
        const len = root.olderNotifs.length;
        if (len === 0) return 0;
        return len * root.pillWidth + (len - 1) * Tokens.spacing.small;
    }
    readonly property real targetTopHeight: {
        if (root.olderNotifs.length === 0)
            return root.height;
        return Math.max(root.pillWidth, root.height - root.olderCirclesHeight - Tokens.spacing.small);
    }

    opacity: root.hasNotif ? 1 : 0
    visible: root.hasNotif && opacity > 0.01

    implicitWidth: pillWidth
    implicitHeight: root.hasNotif ? (160 + olderNotifs.length * (pillWidth + Tokens.spacing.small)) : 0

    Behavior on implicitHeight {
        Anim { type: Anim.DefaultSpatial }
    }

    Layout.preferredWidth: pillWidth
    Layout.alignment: Qt.AlignHCenter

    function triggerExpand(sourceItem: Item, iconItem: Item, notifData: var): void {
        if (!notifData)
            return;
        if (root.bar && typeof root.bar.expandNotificationMorphFromPill === "function") {
            root.bar.expandNotificationMorphFromPill(sourceItem, iconItem, null, notifData);
        }
    }

    // ── 100% Synchronized Single-Driver Push-Down Shrink Pipeline ──
    property real pushProgress: 0.0
    property real startShrinkH: 160
    property real targetCircY: 0
    property real targetTopH: 160
    property var animatingOldNotif: null
    property real lastPillHeight: 160

    Connections {
        target: Notifs

        function onNotificationPushed(newNotif: var, oldNotif: var): void {
            if (oldNotif !== null && oldNotif !== undefined) {
                root.animatingOldNotif = oldNotif;

                const prevH = Math.max(root.pillWidth, topPill.height > 0 ? topPill.height : root.lastPillHeight);
                const olderCountAfter = root.olderNotifs.length;
                const olderHeightAfter = olderCountAfter * root.pillWidth + Math.max(0, olderCountAfter - 1) * Tokens.spacing.small;

                root.startShrinkH = prevH;
                root.targetTopH = Math.max(root.pillWidth, root.height - (olderHeightAfter + Tokens.spacing.small));
                root.targetCircY = Math.max(0, root.height - olderHeightAfter);

                shrinkingPill.visible = true;
                pushDownAnim.restart();
            }
        }
    }

    NumberAnimation {
        id: pushDownAnim
        target: root
        property: "pushProgress"
        from: 0.0
        to: 1.0
        duration: Tokens.anim.durations.expressiveDefaultSpatial
        easing: Tokens.anim.expressiveDefaultSpatial

        onFinished: {
            shrinkingPill.visible = false;
            root.animatingOldNotif = null;
            root.pushProgress = 0.0;
            topPill.opacity = Qt.binding(() => (Notifs.notifMorphRendering && Notifs.activeMorphNotif === root.currentNotif) ? 0 : 1);
            root.lastPillHeight = topPill.height;
        }
    }

    // ── Transient Shrinking Pill (Physical Push-Down & Shrink) ──
    StyledRect {
        id: shrinkingPill
        x: 0
        y: (1.0 - root.pushProgress) * 0 + root.pushProgress * root.targetCircY
        width: root.pillWidth
        height: (1.0 - root.pushProgress) * root.startShrinkH + root.pushProgress * root.pillWidth
        radius: root.pillRadius
        color: Colours.palette.m3secondaryContainer
        visible: false
        z: 10

        property real textAlpha: Math.max(0.0, 1.0 - root.pushProgress * 2.5)

        Item {
            anchors.fill: parent
            anchors.margins: 4
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 6

                Item {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignHCenter

                    StyledRect {
                        anchors.fill: parent
                        radius: width / 2
                        color: Colours.palette.m3surfaceContainerHighest

                        CachingIconImage {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            source: Icons.resolveIcon(root.animatingOldNotif?.appIcon || root.animatingOldNotif?.appName || root.animatingOldNotif?.image || "", "")
                            visible: source !== ""
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "notifications"
                            color: Colours.palette.m3onSecondaryContainer
                            iconPointSize: Tokens.font.size.normal
                            fill: 1
                            visible: !root.animatingOldNotif?.appIcon
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    opacity: shrinkingPill.textAlpha

                    Item {
                        anchors.centerIn: parent
                        width: Math.max(1, parent.height)
                        height: 24
                        transform: [ Rotation { angle: 90; origin.x: width / 2; origin.y: height / 2 } ]

                        MarqueeText {
                            anchors.fill: parent
                            text: root.animatingOldNotif?.summary || root.animatingOldNotif?.appName || ""
                            color: Colours.palette.m3onSecondaryContainer
                            textPointSize: Tokens.font.size.smaller
                        }
                    }
                }
            }
        }
    }

    // ── Settled Top / Newest Notification: PILL (Synchronously locked to pushing pill) ──
    StyledRect {
        id: topPill
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.pillWidth
        height: pushDownAnim.running
            ? Math.max(root.pillWidth, shrinkingPill.y > 0 ? (shrinkingPill.y - Tokens.spacing.small) : ((1.0 - root.pushProgress) * root.pillWidth + root.pushProgress * root.targetTopH))
            : root.targetTopHeight
        radius: root.pillRadius
        color: Colours.palette.m3secondaryContainer
        opacity: pushDownAnim.running
            ? Math.min(1.0, root.pushProgress * 2.0)
            : ((Notifs.notifMorphRendering && Notifs.activeMorphNotif === root.currentNotif) ? 0 : 1)
        z: 2

        Behavior on height {
            enabled: !pushDownAnim.running
            Anim { type: Anim.DefaultSpatial }
        }

        Behavior on color {
            CAnim {
                duration: Tokens.anim.durations.expressiveDefaultSpatial
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }

        property real pillScale: 1.0
        scale: pillScale

        SequentialAnimation {
            id: topPressSpring
            NumberAnimation { target: topPill; property: "pillScale"; to: 0.94; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: topPill; property: "pillScale"; to: 1.0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }

        Item {
            id: innerClipContainer
            anchors.fill: parent
            anchors.margins: 4
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 6

                Item {
                    id: topAppIconFrame
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignHCenter

                    StyledRect {
                        anchors.fill: parent
                        radius: width / 2
                        color: Colours.palette.m3surfaceContainerHighest

                        CachingIconImage {
                            id: topAppIconImg
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            source: Icons.resolveIcon(root.currentNotif?.appIcon || root.currentNotif?.appName || root.currentNotif?.image || "", "")
                            visible: source !== ""
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "notifications"
                            color: Colours.palette.m3onSecondaryContainer
                            iconPointSize: Tokens.font.size.normal
                            fill: 1
                            visible: !topAppIconImg.visible
                        }
                    }
                }

                Item {
                    id: topTextFrame
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    visible: topPill.height > root.pillWidth + 24
                    opacity: topPill.height > root.pillWidth + 24 ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation { duration: Tokens.anim.durations.small; easing: Tokens.anim.expressiveFastSpatial }
                    }

                    Item {
                        id: rotatedMarqueeWrapper
                        anchors.centerIn: parent
                        width: Math.max(1, topTextFrame.height)
                        height: 24

                        transform: [
                            Rotation {
                                angle: 90
                                origin.x: rotatedMarqueeWrapper.width / 2
                                origin.y: rotatedMarqueeWrapper.height / 2
                            }
                        ]

                        MarqueeText {
                            anchors.fill: parent
                            text: root.currentNotif?.summary || root.currentNotif?.appName || qsTr("Notification")
                            color: Colours.palette.m3onSecondaryContainer
                            textPointSize: Tokens.font.size.smaller
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                topPressSpring.start();
                root.triggerExpand(topPill, topAppIconFrame, root.currentNotif);
            }
        }
    }

    // ── Older Notification Circles: Persistent slots with fluid Y-glide physics ──
    Repeater {
        model: 4

        delegate: StyledRect {
            id: circleSlot
            required property int index

            readonly property var notifData: index < root.olderNotifs.length ? root.olderNotifs[index] : null
            readonly property bool slotActive: notifData !== null
            readonly property real targetY: Math.max(0, root.height - (root.olderNotifs.length - index) * root.pillWidth - (root.olderNotifs.length - 1 - index) * Tokens.spacing.small)

            x: (root.width - width) / 2
            y: targetY
            width: root.pillWidth
            height: root.pillWidth
            radius: root.pillRadius
            color: Colours.palette.m3secondaryContainer
            z: 1

            visible: opacity > 0.01
            opacity: slotActive ? ((Notifs.notifMorphRendering && Notifs.activeMorphNotif === notifData) ? 0 : 1) : 0

            Behavior on y {
                Anim { type: Anim.DefaultSpatial }
            }

            Behavior on color {
                CAnim {
                    duration: Tokens.anim.durations.expressiveDefaultSpatial
                    easing: Tokens.anim.expressiveDefaultSpatial
                }
            }

            property real circleScale: 1.0
            scale: circleScale

            SequentialAnimation {
                id: circlePressSpring
                NumberAnimation { target: circleSlot; property: "circleScale"; to: 0.92; duration: 90; easing.type: Easing.OutQuad }
                NumberAnimation { target: circleSlot; property: "circleScale"; to: 1.0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            }

            StyledRect {
                id: circleIconFrame
                anchors.centerIn: parent
                width: 36
                height: 36
                radius: width / 2
                color: Colours.palette.m3surfaceContainerHighest

                CachingIconImage {
                    id: circleIconImg
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: Icons.resolveIcon(circleSlot.notifData?.appIcon || circleSlot.notifData?.appName || circleSlot.notifData?.image || "", "")
                    visible: source !== ""
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "notifications"
                    color: Colours.palette.m3onSecondaryContainer
                    iconPointSize: Tokens.font.size.small
                    fill: 1
                    visible: !circleIconImg.visible
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: circleSlot.slotActive
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    circlePressSpring.start();
                    root.triggerExpand(circleSlot, circleIconFrame, circleSlot.notifData);
                }
            }
        }
    }

    // ── MarqueeText Component ──
    component MarqueeText: Item {
        id: marqueeRoot

        required property string text
        property color color: Colours.palette.m3onSecondaryContainer
        property real textPointSize: Tokens.font.size.smaller
        property bool running: true

        height: primaryLabel.implicitHeight
        clip: true

        readonly property real speed: 26
        readonly property bool needsMarquee: width > 0 && primaryLabel.implicitWidth > width + 2

        layer.enabled: needsMarquee
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: ShaderEffectSource {
                sourceItem: Rectangle {
                    width: marqueeRoot.width
                    height: marqueeRoot.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.08; color: "black" }
                        GradientStop { position: 0.92; color: "black" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }
        }

        Row {
            id: marqueeRow
            spacing: 24
            property real scrollX: 0

            x: marqueeRoot.needsMarquee ? scrollX : 0
            height: parent.height

            StyledText {
                id: primaryLabel
                text: marqueeRoot.text
                color: marqueeRoot.color
                textPointSize: marqueeRoot.textPointSize
                font.family: Tokens.font.family.mono
                font.weight: Font.Medium
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideNone
            }

            StyledText {
                text: marqueeRoot.text
                color: marqueeRoot.color
                textPointSize: marqueeRoot.textPointSize
                font.family: Tokens.font.family.mono
                font.weight: Font.Medium
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                visible: marqueeRoot.needsMarquee
                elide: Text.ElideNone
            }
        }

        SequentialAnimation {
            id: marqueeAnim
            running: marqueeRoot.running && marqueeRoot.needsMarquee && marqueeRoot.visible && marqueeRoot.width > 0
            loops: Animation.Infinite

            PauseAnimation { duration: 1500 }
            NumberAnimation {
                target: marqueeRow
                property: "scrollX"
                to: -(primaryLabel.implicitWidth + marqueeRow.spacing)
                duration: Math.max(2500, primaryLabel.implicitWidth * 1000 / marqueeRoot.speed)
                easing.type: Easing.Linear
            }
            PauseAnimation { duration: 800 }
            PropertyAction {
                target: marqueeRow
                property: "scrollX"
                value: 0
            }
        }
    }
}
