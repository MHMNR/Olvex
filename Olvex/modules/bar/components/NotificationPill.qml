import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import M3Shapes
import Olvex
import Olvex.Config
import qs.components
import qs.components.images
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property var bar
    clip: false

    readonly property bool hasNotif: Notifs.hasBarNotif
    readonly property var currentNotif: Notifs.currentBarNotif
    readonly property var olderNotifs: {
        if (!Notifs.barQueue)
            return [];
        return Notifs.barQueue.filter(n => n && !n.closed && n !== root.currentNotif);
    }
    readonly property int notifCount: (root.hasNotif ? 1 : 0) + olderNotifs.length

    onHasNotifChanged: {
        if (hasNotif) {
            entryPushAnim.restart();
            olderCascadeAnim.restart();
            notifDownwardPulseAnim.restart();
        } else {
            entryPushAnim.stop();
            olderCascadeAnim.stop();
            notifDownwardPulseAnim.stop();
            entryPushOffset = 0;
            olderCascadeOffset = 0;
            notifDownwardForce = 0;
        }
    }

    ListModel {
        id: olderCirclesModel
    }

    Connections {
        target: root
        function onOlderNotifsChanged() {
            const newNotifs = root.olderNotifs;
            for (let i = olderCirclesModel.count - 1; i >= 0; i--) {
                const nId = olderCirclesModel.get(i).notifId;
                if (!newNotifs.some(newN => newN && newN.id === nId)) {
                    olderCirclesModel.remove(i);
                }
            }
            const count = newNotifs.length;
            for (let i = 0; i < count; i++) {
                const n = newNotifs[i];
                const offset = root.computeStackOffset(i, count);
                if (i >= olderCirclesModel.count) {
                    olderCirclesModel.insert(i, { notif: n, notifId: n.id, explicitTargetOffset: offset });
                } else if (olderCirclesModel.get(i).notifId !== n.id) {
                    olderCirclesModel.insert(i, { notif: n, notifId: n.id, explicitTargetOffset: offset });
                } else {
                    olderCirclesModel.setProperty(i, "explicitTargetOffset", offset);
                }
            }
        }
    }

    readonly property int pillWidth: 48
    readonly property real pillRadius: pillWidth / 2

    readonly property int pillMorphDuration: 430

    // ── Dynamic visible slot & overflow calculations ──
    readonly property int maxOlderSlots: {
        if (root.height <= 0) return 1;
        const available = root.height - 96 - Tokens.spacing.small;
        const slotH = root.pillWidth + Tokens.spacing.small;
        return Math.max(1, Math.min(5, Math.floor(available / slotH)));
    }

    readonly property bool hasOverflow: olderCirclesModel.count > maxOlderSlots
    readonly property int maxVisibleCircles: hasOverflow ? (maxOlderSlots - 1) : maxOlderSlots
    readonly property int overflowCount: Math.max(0, olderCirclesModel.count - maxVisibleCircles)
    readonly property int displayedSlotCount: hasOverflow ? maxOlderSlots : olderCirclesModel.count

    function getOlderStackHeight(count) {
        if (count <= 0) return 0;
        const slots = count > root.maxOlderSlots ? root.maxOlderSlots : count;
        return slots * root.pillWidth + Math.max(0, slots - 1) * Tokens.spacing.small;
    }

    function getDisplayedSlotCount(count) {
        if (count <= 0) return 0;
        return count > root.maxOlderSlots ? root.maxOlderSlots : count;
    }

    function computeStackOffset(idx, totalCount) {
        if (totalCount <= 0) return 0;
        const slots = root.getDisplayedSlotCount(totalCount);
        const isOver = root.hasOverflow && idx >= root.maxVisibleCircles;
        const slot = isOver ? (slots - 1) : Math.min(idx, slots - 1);
        return (slots - slot) * root.pillWidth + Math.max(0, slots - 1 - slot) * Tokens.spacing.small;
    }

    readonly property real olderCirclesHeight: getOlderStackHeight(olderCirclesModel.count)
    
    property real currentOlderCirclesHeight: olderCirclesHeight
    Behavior on currentOlderCirclesHeight {
        NumberAnimation {
            duration: root.pillMorphDuration
            easing: Tokens.anim.expressiveSubtleSpatial
        }
    }

    readonly property real targetOlderCirclesSpacing: displayedSlotCount > 0 ? Tokens.spacing.small : 0
    property real currentOlderCirclesSpacing: targetOlderCirclesSpacing
    Behavior on currentOlderCirclesSpacing {
        NumberAnimation {
            duration: root.pillMorphDuration
            easing: Tokens.anim.expressiveSubtleSpatial
        }
    }

    readonly property real availableTopHeight: Math.max(0, root.height - currentOlderCirclesHeight - currentOlderCirclesSpacing)
    readonly property real targetTopHeight: Math.max(0, Math.min(availableTopHeight, root.height))

    opacity: (root.hasNotif || root.isDismissingLast) ? 1 : 0
    visible: (root.hasNotif || root.isDismissingLast) && opacity > 0.01

    implicitWidth: pillWidth
    implicitHeight: root.hasNotif ? (160 + displayedSlotCount * (pillWidth + Tokens.spacing.small)) : 0

    Behavior on implicitHeight {
        NumberAnimation {
            duration: root.pillMorphDuration
            easing: Tokens.anim.expressiveSubtleSpatial
        }
    }

    Layout.preferredWidth: pillWidth
    Layout.alignment: Qt.AlignHCenter

    function triggerExpand(sourceItem, iconItem, notifData) {
        if (!notifData)
            return;
        if (root.bar && typeof root.bar.expandNotificationMorphFromPill === "function") {
            root.bar.expandNotificationMorphFromPill(sourceItem, iconItem, null, notifData);
        }
    }

    property real entryPushOffset: 0
    property real olderCascadeOffset: 0
    property real notifDownwardForce: 0

    SequentialAnimation {
        id: notifDownwardPulseAnim
        NumberAnimation {
            target: root
            property: "notifDownwardForce"
            from: 0
            to: 22
            duration: 120
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "notifDownwardForce"
            from: 22
            to: 0
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: entryPushAnim
        NumberAnimation {
            target: root
            property: "entryPushOffset"
            from: 0
            to: 12
            duration: 110
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "entryPushOffset"
            from: 12
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: olderCascadeAnim
        NumberAnimation {
            target: root
            property: "olderCascadeOffset"
            from: 0
            to: 10
            duration: 110
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "olderCascadeOffset"
            from: 10
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    readonly property real upwardPush: {
        if (root.isDismissingLast)
            return 0;
        let push = entryPushOffset;
        if (incomingPill && incomingPill.visible) {
            const incY = incomingPill.useBottomEdge ? (incomingPill.targetBottomEdge - incomingPill.height) : incomingPill.y;
            if (incY < 0) {
                push = Math.max(push, -incY);
            }
        }
        return Math.min(18, push);
    }

    // ── Transition animation properties ──
    property bool isPushingDown: pushDownAnim.running
    property bool isPoppingUp: popUpAnim.running
    property bool isDismissingLast: dismissLastAnim.running
    property real lastDismissHeight: pillWidth
    property var animatingOldNotif: null
    property var animatingNewNotif: null

    Connections {
        target: Notifs

        function onNotificationPushed(newNotif, oldNotif) {
            if (dismissLastAnim.running) {
                dismissLastAnim.stop();
                root.isDismissingLast = false;
            }
            if (newNotif && oldNotif) {
                root.animatingOldNotif = oldNotif;
                root.animatingNewNotif = newNotif;
                
                const olderCountBefore = Math.max(0, olderCirclesModel.count - 1);
                const olderHeightBefore = root.getOlderStackHeight(olderCountBefore);
                const oldTopH = Math.max(root.pillWidth, root.height - olderHeightBefore - (olderCountBefore > 0 ? Tokens.spacing.small : 0));
                
                const olderCountAfter = olderCirclesModel.count;
                const olderHeightAfter = root.getOlderStackHeight(olderCountAfter);
                const targetCircY = Math.max(0, root.height - olderHeightAfter);
                const targetTopH = Math.max(root.pillWidth, root.height - olderHeightAfter - Tokens.spacing.small);

                incomingPill.useBottomEdge = false;
                incomingPill.manualY = 0;
                incomingPill.animHeight = root.pillWidth;
                incomingPill.opacity = 1.0;
                incomingPill.scale = 1.0;
                incomingPill.textAlpha = 0.0;

                shrinkingPill.manualY = root.pillWidth + Tokens.spacing.small;
                shrinkingPill.animHeight = Math.max(root.pillWidth, oldTopH - (root.pillWidth + Tokens.spacing.small));
                shrinkingPill.opacity = 1.0;
                shrinkingPill.textAlpha = 1.0;
                shrinkingPill.scale = 1.0;
                
                pushShrinkYAnim.to = targetCircY;
                pushShrinkHAnim.to = root.pillWidth;
                pushExpandHAnim.to = targetTopH;
                
                pushDownAnim.restart();
                entryPushAnim.restart();
                olderCascadeAnim.restart();
                notifDownwardPulseAnim.restart();
            }
        }

        function onNotificationPopped(poppedNotif, newTopNotif) {
            if (pushDownAnim.running)
                pushDownAnim.stop();

            if (poppedNotif && newTopNotif) {
                root.animatingOldNotif = poppedNotif;
                root.animatingNewNotif = newTopNotif;

                const isFromOverlay = (Notifs.activeMorphNotif && Notifs.activeMorphNotif.id === poppedNotif.id) || (Notifs.notifMorphRendering && Notifs.activeMorphNotif);

                const actualNewCount = root.olderNotifs.length;
                const actualOldCount = newTopNotif ? actualNewCount + 1 : 0;

                const oldCount = actualOldCount;
                const oldOlderCirclesHeight = root.getOlderStackHeight(oldCount);
                const oldTargetCircY = Math.max(0, root.height - oldOlderCirclesHeight);
                const oldTopH = Math.max(root.pillWidth, root.height - oldOlderCirclesHeight - (oldCount > 0 ? Tokens.spacing.small : 0));

                const newOlderCirclesHeight = root.getOlderStackHeight(actualNewCount);
                const finalTargetTopH = Math.max(root.pillWidth, root.height - newOlderCirclesHeight - (actualNewCount > 0 ? Tokens.spacing.small : 0));

                shrinkingPill.manualY = 0;
                shrinkingPill.animHeight = oldTopH;
                shrinkingPill.textAlpha = 0.0;
                shrinkingPill.opacity = isFromOverlay ? 0.0 : 1.0;
                shrinkingPill.scale = 1.0;

                incomingPill.useBottomEdge = false;
                incomingPill.manualY = oldTargetCircY;
                incomingPill.animHeight = root.pillWidth;
                incomingPill.textAlpha = 0.0;
                incomingPill.opacity = 1.0;

                popShrinkOpacityAnim.to = 0.0;
                popShrinkYAnim.from = 0;
                popShrinkYAnim.to = -(oldTopH + Tokens.spacing.small);
                popShrinkScaleAnim.from = 1.0;
                popShrinkScaleAnim.to = 0.8;
                
                popIncomingYAnim.from = oldTargetCircY;
                popIncomingYAnim.to = 0;
                popExpandHAnim.from = root.pillWidth;
                popExpandHAnim.to = finalTargetTopH;
                
                popUpAnim.restart();
            } else if (poppedNotif && !newTopNotif) {
                root.animatingOldNotif = poppedNotif;
                root.animatingNewNotif = null;

                const isFromOverlay = (Notifs.activeMorphNotif && Notifs.activeMorphNotif.id === poppedNotif.id) || (Notifs.notifMorphRendering && Notifs.activeMorphNotif);

                const currentH = (topPill && topPill.height > 0) ? topPill.height : (root.height > 0 ? root.height : root.pillWidth);
                root.lastDismissHeight = currentH;

                shrinkingPill.manualY = 0;
                shrinkingPill.animHeight = currentH;
                shrinkingPill.textAlpha = 1.0;
                shrinkingPill.opacity = isFromOverlay ? 0.0 : 1.0;
                shrinkingPill.scale = 1.0;

                dismissLastOpacityAnim.from = shrinkingPill.opacity;
                dismissLastOpacityAnim.to = 0.0;
                dismissLastYAnim.from = 0;
                dismissLastYAnim.to = -(currentH + Tokens.spacing.small);
                dismissLastScaleAnim.from = 1.0;
                dismissLastScaleAnim.to = 0.8;

                dismissLastAnim.restart();
            }
        }
    }

    // ── Push-Down Shrink Parallel Animation ──
    ParallelAnimation {
        id: pushDownAnim

        NumberAnimation {
            id: pushShrinkYAnim
            target: shrinkingPill
            property: "manualY"
            duration: root.pillMorphDuration
            easing: Tokens.anim.expressiveSubtleSpatial
        }
        NumberAnimation {
            id: pushShrinkHAnim
            target: shrinkingPill
            property: "animHeight"
            duration: root.pillMorphDuration
            easing: Tokens.anim.expressiveSubtleSpatial
        }
        NumberAnimation {
            target: shrinkingPill
            property: "textAlpha"
            to: 0.0
            duration: Math.round(root.pillMorphDuration * 0.35)
            easing: Tokens.anim.expressiveSubtleSpatial
        }

        NumberAnimation {
            id: pushExpandHAnim
            target: incomingPill
            property: "animHeight"
            duration: root.pillMorphDuration
            easing: Tokens.anim.expressiveSubtleSpatial
        }
        NumberAnimation {
            target: incomingPill
            property: "opacity"
            to: 1.0
            duration: Math.round(root.pillMorphDuration * 0.4)
            easing: Tokens.anim.expressiveSubtleSpatial
        }
        NumberAnimation {
            target: incomingPill
            property: "textAlpha"
            to: 1.0
            duration: root.pillMorphDuration
            easing: Tokens.anim.emphasizedDecel
        }
        NumberAnimation {
            target: incomingPill
            property: "scale"
            to: 1.0
            duration: root.pillMorphDuration
            easing: Tokens.anim.emphasizedDecel
        }

        onFinished: {
            root.animatingOldNotif = null;
            root.animatingNewNotif = null;
            incomingPill.scale = 1.0;
        }
    }

    ParallelAnimation {
        id: popUpAnim

        NumberAnimation {
            id: popShrinkOpacityAnim
            target: shrinkingPill
            property: "opacity"
            duration: Math.round(root.pillMorphDuration * 0.4)
            easing: Tokens.anim.expressiveSubtleSpatial
        }
        NumberAnimation {
            id: popShrinkYAnim
            target: shrinkingPill
            property: "manualY"
            duration: root.pillMorphDuration
            easing: Tokens.anim.expressiveSubtleSpatial
        }
        NumberAnimation {
            id: popShrinkScaleAnim
            target: shrinkingPill
            property: "scale"
            duration: root.pillMorphDuration
            easing: Tokens.anim.expressiveSubtleSpatial
        }


        NumberAnimation {
            id: popIncomingYAnim
            target: incomingPill
            property: "manualY"
            duration: root.pillMorphDuration
            easing: Tokens.anim.expressiveSubtleSpatial
        }

        NumberAnimation {
            id: popExpandHAnim
            target: incomingPill
            property: "animHeight"
            duration: root.pillMorphDuration
            easing: Tokens.anim.expressiveSubtleSpatial
        }
        NumberAnimation {
            target: incomingPill
            property: "textAlpha"
            to: 1.0
            duration: root.pillMorphDuration
            easing: Tokens.anim.emphasizedDecel
        }

        onFinished: {
            root.animatingOldNotif = null;
            root.animatingNewNotif = null;
        }
    }

    ParallelAnimation {
        id: dismissLastAnim

        NumberAnimation {
            id: dismissLastOpacityAnim
            target: shrinkingPill
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: Math.round(root.pillMorphDuration * 0.45)
            easing: Tokens.anim.expressiveSubtleSpatial
        }
        NumberAnimation {
            target: shrinkingPill
            property: "textAlpha"
            to: 0.0
            duration: Math.round(root.pillMorphDuration * 0.25)
            easing: Tokens.anim.expressiveSubtleSpatial
        }
        NumberAnimation {
            id: dismissLastYAnim
            target: shrinkingPill
            property: "manualY"
            duration: root.pillMorphDuration
            easing: Tokens.anim.expressiveSubtleSpatial
        }
        NumberAnimation {
            id: dismissLastScaleAnim
            target: shrinkingPill
            property: "scale"
            from: 1.0
            to: 0.8
            duration: root.pillMorphDuration
            easing: Tokens.anim.expressiveSubtleSpatial
        }

        onFinished: {
            root.animatingOldNotif = null;
            root.animatingNewNotif = null;
        }
    }

    // ── Transient Shrinking Pill (Active during Push-Down Animation) ──
    StyledRect {
        id: shrinkingPill
        width: root.pillWidth
        property real animHeight: root.pillWidth
        property real manualY: 0
        y: Math.min(root.height - root.pillWidth, manualY)
        height: Math.max(root.pillWidth, Math.min(animHeight, Math.max(root.pillWidth, root.height - y)))
        radius: Math.min(width / 2, height / 2)
        color: Colours.tPalette.m3surfaceContainerHigh
        visible: root.isPushingDown || root.isPoppingUp || root.isDismissingLast
        z: 8
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.alpha(Colours.palette.m3surfaceTint, 0.12)
            antialiasing: true
            smooth: true
        }

        property real textAlpha: 1.0
        readonly property bool isCompactCircle: height <= 52

        transform: [
            Translate {
                y: Math.min(root.olderCascadeOffset, Math.max(0, root.height - (shrinkingPill.y + shrinkingPill.height)))
            }
        ]

        Item {
            id: shrinkingBg
            width: 36
            height: 36
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: shrinkingPill.isCompactCircle ? Math.max(0, (shrinkingPill.height - height) / 2) : 6
            layer.enabled: true
            layer.smooth: true
            layer.effect: CircleMask {}

            Rectangle {
                anchors.fill: parent
                color: Colours.palette.m3surfaceContainerHighest
            }

            CachingIconImage {
                id: shrinkingIconImg
                anchors.fill: parent
                source: root.animatingOldNotif ? Icons.getNotificationIcon(root.animatingOldNotif) : ""
            }
        }

        Item {
            id: shrinkingTextContainer
            anchors.top: shrinkingBg.bottom
            anchors.topMargin: 6
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 4
            clip: true
            visible: !shrinkingPill.isCompactCircle && shrinkingPill.textAlpha > 0.01
            opacity: shrinkingPill.textAlpha

            Item {
                anchors.centerIn: parent
                width: Math.max(1, parent.height)
                height: 24
                transform: [ Rotation { angle: 90; origin.x: width / 2; origin.y: height / 2 } ]

                MarqueeText {
                    anchors.fill: parent
                    text: root.animatingOldNotif ? (root.animatingOldNotif.summary || root.animatingOldNotif.appName || "") : ""
                    color: Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.smaller
                }
            }
        }
    }

    // ── Transient Incoming Pill (Active during Push-Down Animation) ──
    StyledRect {
        id: incomingPill
        width: root.pillWidth
        property real animHeight: root.pillWidth
        height: Math.max(root.pillWidth, animHeight)
        radius: Math.min(width / 2, height / 2)
        color: Colours.tPalette.m3surfaceContainerHigh
        visible: root.isPushingDown || root.isPoppingUp
        z: 9
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.alpha(Colours.palette.m3surfaceTint, 0.12)
            antialiasing: true
            smooth: true
        }

        property bool useBottomEdge: false
        property real targetBottomEdge: 0
        property real manualY: 0
        y: useBottomEdge ? targetBottomEdge - height : manualY

        property real textAlpha: 0.0
        readonly property bool isCompactCircle: height <= 52

        transform: Translate {
            y: -root.entryPushOffset
        }

        Item {
            id: incomingBg
            width: 36
            height: 36
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: incomingPill.isCompactCircle ? Math.max(0, (incomingPill.height - height) / 2) : 6
            layer.enabled: true
            layer.smooth: true
            layer.effect: CircleMask {}

            Rectangle {
                anchors.fill: parent
                color: Colours.palette.m3surfaceContainerHighest
            }

            CachingIconImage {
                id: incomingIconImg
                anchors.fill: parent
                source: root.animatingNewNotif ? Icons.getNotificationIcon(root.animatingNewNotif) : ""
            }
        }

        Item {
            id: incomingTextContainer
            anchors.top: incomingBg.bottom
            anchors.topMargin: 6
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 4
            clip: true
            visible: !incomingPill.isCompactCircle && incomingPill.textAlpha > 0.01
            opacity: incomingPill.textAlpha

            Item {
                anchors.centerIn: parent
                width: Math.max(1, parent.height)
                height: 24
                transform: [ Rotation { angle: 90; origin.x: width / 2; origin.y: height / 2 } ]

                MarqueeText {
                    anchors.fill: parent
                    text: root.animatingNewNotif ? (root.animatingNewNotif.summary || root.animatingNewNotif.appName || "") : ""
                    color: Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.smaller
                }
            }
        }
    }

    readonly property real kineticShift: {
        if (!root.bar) return 0;
        const force = (typeof root.bar.cascadeForce === "number" && !isNaN(root.bar.cascadeForce)) ? root.bar.cascadeForce : 0;
        return force * 0.76;
    }

    property real animatedKineticShift: kineticShift
    Behavior on animatedKineticShift {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    readonly property real wsPushForce: (root.bar && typeof root.bar.wsPushForce === "number") ? root.bar.wsPushForce : 0

    // ── Settled Older Notifications: Mini Circles dynamically positioned with Y-glide animation ──
    Item {
        id: olderCirclesContainer
        anchors.fill: parent
        z: 1

        Repeater {
            model: olderCirclesModel

            delegate: StyledRect {
                id: olderCircleDelegate
                required property var notif
                required property var notifId
                required property int index
                required property real explicitTargetOffset

                readonly property bool isOverflowed: root.hasOverflow && index >= root.maxVisibleCircles

                property real circleScale: isOverflowed ? 0.7 : 1.0
                Behavior on circleScale {
                    NumberAnimation {
                        duration: root.pillMorphDuration
                        easing: Tokens.anim.expressiveSubtleSpatial
                    }
                }

                readonly property real dynamicStackOffset: root.computeStackOffset(index, olderCirclesModel.count)
                property real targetStackOffset: isNaN(dynamicStackOffset) ? explicitTargetOffset : dynamicStackOffset
                property real currentStackOffset: targetStackOffset
                
                Behavior on currentStackOffset {
                    NumberAnimation {
                        duration: root.pillMorphDuration
                        easing: Tokens.anim.expressiveSubtleSpatial
                    }
                }

                readonly property real totalCascadeForce: root.wsPushForce + root.notifDownwardForce
                readonly property real circleKineticShiftY: Math.min(14, totalCascadeForce * 0.14 * Math.pow(0.85, Math.min(index, root.maxOlderSlots)))
                property real animatedCircleShiftY: circleKineticShiftY
                Behavior on animatedCircleShiftY {
                    Anim { type: Anim.FastSpatial }
                }

                x: (parent.width - width) / 2
                y: Math.min(root.height - root.pillWidth, Math.max(0, root.height - currentStackOffset))
                width: root.pillWidth
                height: root.pillWidth
                radius: root.pillRadius
                color: Colours.tPalette.m3surfaceContainerHigh

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Qt.alpha(Colours.palette.m3surfaceTint, 0.12)
                    antialiasing: true
                    smooth: true
                }

                transform: [
                    Translate {
                        y: Math.min(
                            root.olderCascadeOffset * Math.pow(0.75, Math.min(index, root.maxOlderSlots)) + olderCircleDelegate.animatedCircleShiftY,
                            Math.max(0, root.height - (olderCircleDelegate.y + olderCircleDelegate.height))
                        )
                    },
                    Scale {
                        origin.x: olderCircleDelegate.width / 2
                        origin.y: olderCircleDelegate.height / 2
                        xScale: olderCircleDelegate.circleScale
                        yScale: olderCircleDelegate.circleScale
                    }
                ]
                readonly property bool isAnimatingThis: {
                    if (root.isPushingDown) {
                        if (index === 0) return true;
                        if (root.animatingOldNotif && (olderCircleDelegate.notifId === root.animatingOldNotif.id || (notif && notif.id === root.animatingOldNotif.id))) return true;
                    }
                    if (root.isPoppingUp) {
                        if (root.animatingNewNotif && (olderCircleDelegate.notifId === root.animatingNewNotif.id || (notif && notif.id === root.animatingNewNotif.id))) return true;
                        if (root.animatingOldNotif && (olderCircleDelegate.notifId === root.animatingOldNotif.id || (notif && notif.id === root.animatingOldNotif.id))) return true;
                    }
                    return false;
                }
                opacity: (Notifs.notifMorphRendering && Notifs.activeMorphNotif && ((notif && Notifs.activeMorphNotif.id === notif.id) || (olderCircleDelegate.notifId && Notifs.activeMorphNotif.id === olderCircleDelegate.notifId))) ? 0 : 
                         isOverflowed ? 0 : 1
                visible: !isAnimatingThis && opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: Math.round(root.pillMorphDuration * 0.4)
                        easing: Tokens.anim.expressiveSubtleSpatial
                    }
                }

                Behavior on color {
                    CAnim {
                        duration: Tokens.anim.durations.expressiveDefaultSpatial
                        easing: Tokens.anim.expressiveDefaultSpatial
                    }
                }

                SequentialAnimation {
                    id: circlePressSpring
                    NumberAnimation { target: olderCircleDelegate; property: "circleScale"; to: 0.92; duration: 90; easing.type: Easing.OutQuad }
                    NumberAnimation { target: olderCircleDelegate; property: "circleScale"; to: 1.0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                }

                Item {
                    id: circleIconFrame
                    anchors.centerIn: parent
                    width: 36
                    height: 36
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: CircleMask {}

                    Rectangle {
                        anchors.fill: parent
                        color: Colours.palette.m3surfaceContainerHighest
                    }

                    CachingIconImage {
                        id: circleIconImg
                        anchors.fill: parent
                        source: notif ? Icons.getNotificationIcon(notif) : ""
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                            Notifs.dismissNotif(notif);
                            return;
                        }
                        circlePressSpring.start();
                        root.triggerExpand(olderCircleDelegate, circleIconFrame, notif);
                    }
                }
            }
        }

        // ── Overflow Indicator Badge ─────────────────────────────────────
        StyledRect {
            id: overflowBadge
            z: 2
            x: (parent.width - width) / 2
            y: Math.min(root.height - root.pillWidth, Math.max(0, root.height - root.pillWidth))
            width: root.pillWidth
            height: root.pillWidth
            radius: root.pillRadius
            color: Colours.tPalette.m3surfaceContainerHighest

            visible: root.hasOverflow && opacity > 0.01
            opacity: root.hasOverflow ? 1.0 : 0.0
            scale: root.hasOverflow ? badgePulseScale : 0.6

            property real badgePulseScale: 1.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Math.round(root.pillMorphDuration * 0.5)
                    easing: Tokens.anim.expressiveSubtleSpatial
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: root.pillMorphDuration
                    easing: Tokens.anim.expressiveDefaultSpatial
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.alpha(Colours.palette.m3primary, 0.14)
                antialiasing: true
                smooth: true
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
                antialiasing: true
                smooth: true
            }

            transform: [
                Translate {
                    y: Math.min(
                        root.olderCascadeOffset * 0.5 + Math.min(10, (root.wsPushForce + root.notifDownwardForce) * 0.08),
                        Math.max(0, root.height - (overflowBadge.y + overflowBadge.height))
                    )
                },
                Scale {
                    origin.x: overflowBadge.width / 2
                    origin.y: overflowBadge.height / 2
                    xScale: overflowBadge.scale
                    yScale: overflowBadge.scale
                }
            ]

            SequentialAnimation {
                id: badgePressSpring
                NumberAnimation { target: overflowBadge; property: "badgePulseScale"; to: 0.90; duration: 90; easing.type: Easing.OutQuad }
                NumberAnimation { target: overflowBadge; property: "badgePulseScale"; to: 1.0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            }

            SequentialAnimation {
                id: badgeCountPulse
                NumberAnimation { target: overflowBadge; property: "badgePulseScale"; to: 1.15; duration: 110; easing.type: Easing.OutQuad }
                NumberAnimation { target: overflowBadge; property: "badgePulseScale"; to: 1.0; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            }

            Connections {
                target: root
                function onOverflowCountChanged() {
                    if (root.overflowCount > 0 && root.hasOverflow) {
                        badgeCountPulse.restart();
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 1

                StyledText {
                    text: "+"
                    color: Colours.palette.m3primary
                    font.family: Tokens.font.family.sans
                    font.weight: Font.Bold
                    textPointSize: Tokens.font.size.smaller
                    verticalAlignment: Text.AlignVCenter
                }

                StyledText {
                    text: `${root.overflowCount}`
                    color: Colours.palette.m3primary
                    font.family: Tokens.font.family.mono
                    font.weight: Font.Bold
                    textPointSize: Tokens.font.size.normal
                    verticalAlignment: Text.AlignVCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                        const notifsToDismiss = [];
                        for (let i = root.olderNotifs.length - 1; i >= root.maxVisibleCircles; i--) {
                            const n = root.olderNotifs[i];
                            if (n) notifsToDismiss.push(n);
                        }
                        for (let i = 0; i < notifsToDismiss.length; i++) {
                            Notifs.dismissNotif(notifsToDismiss[i]);
                        }
                        return;
                    }
                    badgePressSpring.start();
                    const vis = Visibilities.getForActive();
                    if (vis) {
                        vis.notificationcenter = !vis.notificationcenter;
                    }
                }
            }
        }
    }

    // ── Settled Top / Newest Notification: PILL (occupies all space above older circles with smooth height animation) ──
    StyledRect {
        id: topPill
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.pillWidth
        height: root.targetTopHeight
        radius: Math.min(width / 2, height / 2)
        color: Colours.tPalette.m3surfaceContainerHigh
        visible: !root.isPushingDown && !root.isPoppingUp && !root.isDismissingLast && root.hasNotif
        opacity: (Notifs.notifMorphRendering && Notifs.activeMorphNotif && root.currentNotif && Notifs.activeMorphNotif.id === root.currentNotif.id) ? 0 : 1
        z: 2
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.alpha(Colours.palette.m3surfaceTint, 0.12)
            antialiasing: true
            smooth: true
        }

        readonly property bool isCompactCircle: height <= 52

        Behavior on color {
            CAnim {
                duration: Tokens.anim.durations.expressiveDefaultSpatial
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }

        property real pillScale: 1.0

        transform: [
            Translate {
                y: -root.entryPushOffset
            },
            Scale {
                origin.x: topPill.width / 2
                origin.y: 0
                xScale: topPill.pillScale
                yScale: topPill.pillScale
            }
        ]

        SequentialAnimation {
            id: topPressSpring
            NumberAnimation { target: topPill; property: "pillScale"; to: 0.94; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: topPill; property: "pillScale"; to: 1.0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }

        Item {
            id: topAppBg
            width: 36
            height: 36
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: topPill.isCompactCircle ? Math.max(0, (topPill.height - height) / 2) : 6
            layer.enabled: true
            layer.smooth: true
            layer.effect: CircleMask {}

            Rectangle {
                anchors.fill: parent
                color: Colours.palette.m3surfaceContainerHighest
            }

            CachingIconImage {
                id: topAppIconImg
                anchors.fill: parent
                source: root.currentNotif ? Icons.getNotificationIcon(root.currentNotif) : ""
            }
        }

        Item {
            id: topTextFrame
            anchors.top: topAppBg.bottom
            anchors.topMargin: 6
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 4
            clip: true
            visible: root.hasNotif && !topPill.isCompactCircle
            opacity: (root.hasNotif && !topPill.isCompactCircle) ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.anim.durations.expressiveFastSpatial
                    easing: Tokens.anim.expressiveFastSpatial
                }
            }

            Item {
                id: rotatedMarqueeWrapper
                anchors.centerIn: parent
                width: Math.max(1, topTextFrame.height)
                height: 24

                property real slideOffset: 0

                transform: [
                    Rotation {
                        angle: 90
                        origin.x: rotatedMarqueeWrapper.width / 2
                        origin.y: rotatedMarqueeWrapper.height / 2
                    },
                    Translate {
                        x: rotatedMarqueeWrapper.slideOffset
                    }
                ]

                NumberAnimation {
                    id: titleSlideAnim
                    target: rotatedMarqueeWrapper
                    property: "slideOffset"
                    from: -20
                    to: 0
                    duration: 280
                    easing: Tokens.anim.emphasizedDecel
                }

                Connections {
                    target: root
                    function onCurrentNotifChanged() {
                        if (root.currentNotif) {
                            titleSlideAnim.restart();
                        }
                    }
                }

                Component.onCompleted: {
                    if (root.currentNotif) {
                        titleSlideAnim.restart();
                    }
                }

                MarqueeText {
                    anchors.fill: parent
                    text: root.currentNotif ? (root.currentNotif.summary || root.currentNotif.appName || qsTr("Notification")) : qsTr("Notification")
                    color: Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.smaller
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                    Notifs.dismissBarNotif();
                    return;
                }
                topPressSpring.start();
                root.triggerExpand(topPill, topAppBg, root.currentNotif);
            }
        }
    }

    // ── MarqueeText Component ──
    component MarqueeText: Item {
        id: marqueeRoot

        required property string text
        property color color: Colours.palette.m3onSurface
        property color fadeColor: Colours.tPalette.m3surfaceContainer
        property real textPointSize: Tokens.font.size.smaller
        property bool running: true

        height: primaryLabel.implicitHeight
        clip: true

        onTextChanged: {
            marqueeRow.scrollX = 0;
            marqueeAnim.restart();
        }

        readonly property real speed: 26
        readonly property bool needsMarquee: width > 0 && primaryLabel.implicitWidth > width + 2

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

        Rectangle {
            z: 2
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 8
            visible: marqueeRoot.needsMarquee
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: marqueeRoot.fadeColor }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Rectangle {
            z: 2
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 8
            visible: marqueeRoot.needsMarquee
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: marqueeRoot.fadeColor }
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
