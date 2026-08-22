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
    clip: true

    readonly property bool hasNotif: Notifs.hasBarNotif
    readonly property var currentNotif: Notifs.currentBarNotif
    readonly property var olderNotifs: {
        if (!Notifs.barQueue)
            return [];
        return Notifs.barQueue.filter(n => n && !n.closed && n !== root.currentNotif);
    }
    readonly property int notifCount: (root.hasNotif ? 1 : 0) + olderNotifs.length

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
            for (let i = 0; i < newNotifs.length; i++) {
                const n = newNotifs[i];
                if (i >= olderCirclesModel.count) {
                    olderCirclesModel.insert(i, { notif: n, notifId: n.id, explicitTargetOffset: 0 });
                } else if (olderCirclesModel.get(i).notifId !== n.id) {
                    olderCirclesModel.insert(i, { notif: n, notifId: n.id, explicitTargetOffset: 0 });
                }
            }
            
            const count = olderCirclesModel.count;
            for (let i = 0; i < count; i++) {
                const offset = (count - i) * root.pillWidth + Math.max(0, count - 1 - i) * Tokens.spacing.small;
                olderCirclesModel.setProperty(i, "explicitTargetOffset", offset);
            }
        }
    }

    readonly property int pillWidth: 48
    readonly property real pillRadius: pillWidth / 2

    readonly property real olderCirclesHeight: {
        const len = olderCirclesModel.count;
        if (len === 0) return 0;
        return len * root.pillWidth + (len - 1) * Tokens.spacing.small;
    }
    
    property real currentOlderCirclesHeight: olderCirclesHeight
    Behavior on currentOlderCirclesHeight {
        NumberAnimation {
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.expressiveDefaultSpatial
        }
    }

    readonly property real targetOlderCirclesSpacing: olderCirclesModel.count > 0 ? Tokens.spacing.small : 0
    property real currentOlderCirclesSpacing: targetOlderCirclesSpacing
    Behavior on currentOlderCirclesSpacing {
        NumberAnimation {
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.expressiveDefaultSpatial
        }
    }

    readonly property real targetTopHeight: {
        return Math.max(root.pillWidth, root.height - currentOlderCirclesHeight - currentOlderCirclesSpacing);
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

    // ── Transition animation properties ──
    property bool isPushingDown: pushDownAnim.running
    property bool isPoppingUp: popUpAnim.running
    property var animatingOldNotif: null
    property var animatingNewNotif: null

    Connections {
        target: Notifs

        function onNotificationPushed(newNotif: var, oldNotif: var): void {
            if (newNotif && oldNotif) {
                root.animatingOldNotif = oldNotif;
                root.animatingNewNotif = newNotif;
                
                const olderCountBefore = Math.max(0, olderCirclesModel.count - 1);
                const olderHeightBefore = olderCountBefore * root.pillWidth + Math.max(0, olderCountBefore - 1) * Tokens.spacing.small;
                const oldTopH = Math.max(root.pillWidth, root.height - olderHeightBefore - (olderCountBefore > 0 ? Tokens.spacing.small : 0));
                
                const initialOldY = root.pillWidth + Tokens.spacing.small;
                const initialOldH = Math.max(root.pillWidth, oldTopH - initialOldY);

                shrinkingPill.y = initialOldY;
                shrinkingPill.height = initialOldH;
                shrinkingPill.opacity = 1.0;
                shrinkingPill.textAlpha = 1.0;
                shrinkingPill.scale = 1.0;
                
                const olderCountAfter = olderCirclesModel.count;
                const olderHeightAfter = olderCountAfter * root.pillWidth + Math.max(0, olderCountAfter - 1) * Tokens.spacing.small;
                const targetCircY = Math.max(0, root.height - olderHeightAfter);
                const targetTopH = Math.max(root.pillWidth, root.height - olderHeightAfter - Tokens.spacing.small);

                incomingPill.y = 0;
                incomingPill.height = root.pillWidth;
                incomingPill.opacity = 0.0;
                incomingPill.scale = 0.6;
                
                pushShrinkYAnim.to = targetCircY;
                pushShrinkHAnim.to = root.pillWidth;
                pushExpandHAnim.to = targetTopH;
                
                pushDownAnim.restart();
            }
        }

        function onNotificationPopped(poppedNotif: var, newTopNotif: var): void {
            if (poppedNotif && newTopNotif) {
                root.animatingOldNotif = poppedNotif;
                root.animatingNewNotif = newTopNotif;

                const isFromOverlay = (Notifs.activeMorphNotif && Notifs.activeMorphNotif.id === poppedNotif.id) || (Notifs.notifMorphRendering && Notifs.activeMorphNotif);

                const oldCount = olderCirclesModel.count + 1;
                const oldOlderCirclesHeight = oldCount * root.pillWidth + Math.max(0, oldCount - 1) * Tokens.spacing.small;
                const oldTargetCircY = Math.max(0, root.height - oldOlderCirclesHeight);
                const oldTopH = Math.max(root.pillWidth, root.height - oldOlderCirclesHeight - Tokens.spacing.small);

                const newOlderCirclesHeight = olderCirclesModel.count * root.pillWidth + Math.max(0, olderCirclesModel.count - 1) * Tokens.spacing.small;
                const finalTargetTopH = Math.max(root.pillWidth, root.height - newOlderCirclesHeight - Tokens.spacing.small);

                shrinkingPill.y = 0;
                shrinkingPill.height = oldTopH;
                shrinkingPill.textAlpha = 0.0;
                shrinkingPill.opacity = isFromOverlay ? 0.0 : 1.0;
                shrinkingPill.scale = 1.0;

                incomingPill.y = oldTargetCircY;
                incomingPill.height = root.pillWidth;
                incomingPill.textAlpha = 0.0;
                incomingPill.opacity = 1.0;

                popShrinkOpacityAnim.to = 0.0;
                popShrinkYAnim.from = 0;
                popShrinkYAnim.to = -(oldTopH + Tokens.spacing.small);
                popShrinkScaleAnim.from = 1.0;
                popShrinkScaleAnim.to = 0.8;
                
                popExpandYAnim.to = 0;
                popExpandHAnim.to = finalTargetTopH;
                
                popUpAnim.restart();
            }
        }
    }

    // ── Push-Down Shrink Parallel Animation ──
    ParallelAnimation {
        id: pushDownAnim

        NumberAnimation {
            id: pushShrinkYAnim
            target: shrinkingPill
            property: "y"
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.expressiveDefaultSpatial
        }
        NumberAnimation {
            id: pushShrinkHAnim
            target: shrinkingPill
            property: "height"
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.expressiveDefaultSpatial
        }
        NumberAnimation {
            target: shrinkingPill
            property: "textAlpha"
            to: 0.0
            duration: Math.round(Tokens.anim.durations.expressiveDefaultSpatial * 0.35)
            easing: Tokens.anim.expressiveFastSpatial
        }

        NumberAnimation {
            id: pushExpandHAnim
            target: incomingPill
            property: "height"
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.expressiveDefaultSpatial
        }
        NumberAnimation {
            target: incomingPill
            property: "opacity"
            to: 1.0
            duration: Math.round(Tokens.anim.durations.expressiveDefaultSpatial * 0.4)
            easing: Tokens.anim.expressiveFastSpatial
        }
        NumberAnimation {
            target: incomingPill
            property: "textAlpha"
            to: 1.0
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.emphasizedDecel
        }
        NumberAnimation {
            target: incomingPill
            property: "scale"
            to: 1.0
            duration: Tokens.anim.durations.expressiveDefaultSpatial
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
            duration: Math.round(Tokens.anim.durations.expressiveDefaultSpatial * 0.4)
            easing: Tokens.anim.expressiveFastSpatial
        }
        NumberAnimation {
            id: popShrinkYAnim
            target: shrinkingPill
            property: "y"
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.expressiveDefaultSpatial
        }
        NumberAnimation {
            id: popShrinkScaleAnim
            target: shrinkingPill
            property: "scale"
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.expressiveDefaultSpatial
        }

        NumberAnimation {
            id: popExpandYAnim
            target: incomingPill
            property: "y"
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.expressiveDefaultSpatial
        }
        NumberAnimation {
            id: popExpandHAnim
            target: incomingPill
            property: "height"
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.expressiveDefaultSpatial
        }
        NumberAnimation {
            target: incomingPill
            property: "textAlpha"
            to: 1.0
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.emphasizedDecel
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
        radius: Math.min(width/2, height/2)
        color: Colours.palette.m3secondaryContainer
        visible: root.isPushingDown || root.isPoppingUp
        z: 8

        property real textAlpha: 1.0

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

                    StyledClippingRect {
                        id: shrinkingBg
                        anchors.fill: parent
                        radius: width / 2
                        color: Colours.palette.m3surfaceContainerHighest

                        CachingIconImage {
                            id: shrinkingIconImg
                            anchors.fill: parent
                            source: Icons.getNotificationIcon(root.animatingOldNotif)
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

    // ── Transient Incoming Pill (Active during Push-Down Animation) ──
    StyledRect {
        id: incomingPill
        width: root.pillWidth
        radius: Math.min(width/2, height/2)
        color: Colours.palette.m3secondaryContainer
        visible: root.isPushingDown || root.isPoppingUp
        z: 9

        property real textAlpha: 0.0

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

                    StyledClippingRect {
                        id: incomingBg
                        anchors.fill: parent
                        radius: width / 2
                        color: Colours.palette.m3surfaceContainerHighest

                        CachingIconImage {
                            id: incomingIconImg
                            anchors.fill: parent
                            source: Icons.getNotificationIcon(root.animatingNewNotif)
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    opacity: incomingPill.textAlpha

                    Item {
                        anchors.centerIn: parent
                        width: Math.max(1, parent.height)
                        height: 24
                        transform: [ Rotation { angle: 90; origin.x: width / 2; origin.y: height / 2 } ]

                        MarqueeText {
                            anchors.fill: parent
                            text: root.animatingNewNotif?.summary || root.animatingNewNotif?.appName || ""
                            color: Colours.palette.m3onSecondaryContainer
                            textPointSize: Tokens.font.size.smaller
                        }
                    }
                }
            }
        }
    }

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
                required property int index
                required property real explicitTargetOffset

                property real targetStackOffset: explicitTargetOffset
                property real currentStackOffset: targetStackOffset
                
                Behavior on currentStackOffset {
                    NumberAnimation {
                        duration: Tokens.anim.durations.expressiveDefaultSpatial
                        easing: Tokens.anim.expressiveDefaultSpatial
                    }
                }

                x: (parent.width - width) / 2
                y: Math.max(0, root.height - currentStackOffset)
                width: root.pillWidth
                height: root.pillWidth
                radius: root.pillRadius
                color: Colours.palette.m3secondaryContainer
                opacity: (Notifs.notifMorphRendering && Notifs.activeMorphNotif && notif && Notifs.activeMorphNotif.id === notif.id) ? 0 : 
                         ((root.isPushingDown || root.isPoppingUp) && root.animatingOldNotif && notif && notif.id === root.animatingOldNotif.id) ? 0 : 
                         ((root.isPushingDown || root.isPoppingUp) && root.animatingNewNotif && notif && notif.id === root.animatingNewNotif.id) ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { 
                        duration: (root.isPushingDown || root.isPoppingUp) ? 150 : 0
                        easing: Tokens.anim.expressiveFastSpatial 
                    }
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
                    NumberAnimation { target: olderCircleDelegate; property: "circleScale"; to: 0.92; duration: 90; easing.type: Easing.OutQuad }
                    NumberAnimation { target: olderCircleDelegate; property: "circleScale"; to: 1.0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                }

                StyledClippingRect {
                    id: circleIconFrame
                    anchors.centerIn: parent
                    width: 36
                    height: 36
                    radius: width / 2
                    color: Colours.palette.m3surfaceContainerHighest

                    CachingIconImage {
                        id: circleIconImg
                        anchors.fill: parent
                        source: Icons.getNotificationIcon(notif)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        circlePressSpring.start();
                        root.triggerExpand(olderCircleDelegate, circleIconFrame, notif);
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
        radius: root.pillRadius
        color: Colours.palette.m3secondaryContainer
        visible: !root.isPushingDown && !root.isPoppingUp && root.hasNotif
        opacity: (Notifs.notifMorphRendering && Notifs.activeMorphNotif && root.currentNotif && Notifs.activeMorphNotif.id === root.currentNotif.id) ? 0 : 1
        z: 2

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

                    StyledClippingRect {
                        id: topAppBg
                        anchors.fill: parent
                        radius: width / 2
                        color: Colours.palette.m3surfaceContainerHighest

                        CachingIconImage {
                            id: topAppIconImg
                            anchors.fill: parent
                            source: Icons.getNotificationIcon(root.currentNotif)
                        }
                    }
                }

                Item {
                    id: topTextFrame
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    visible: root.hasNotif
                    opacity: (root.hasNotif && !root.isPushingDown && !root.isPoppingUp) ? 1.0 : 0.0

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

    // ── MarqueeText Component ──
    component MarqueeText: Item {
        id: marqueeRoot

        required property string text
        property color color: Colours.palette.m3onSecondaryContainer
        property color fadeColor: Colours.palette.m3secondaryContainer
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
