import QtQuick
import Quickshell
import Quickshell.Widgets
import Olvex.Config
import qs.components
import qs.components.containers
import qs.components.widgets
import qs.services

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property Item osdPanel
    required property Item sessionPanel

    // Same inset on top / sides / bottom so the stack container padding matches
    readonly property int padding: Tokens.padding.large
    readonly property int cardRadius: Tokens.rounding.large
    // Resolve sizes on this Item (has screen Tokens), never inside Anim/NumberAnimation
    readonly property int notifWidth: Tokens.sizes.notifs.width

    readonly property var safeBorder: (typeof Config !== "undefined" && Config && Config.border) ? Config.border : {
        thickness: 0,
        rounding: 0,
        minThickness: 0,
        floating: false,
        smoothing: 0,
        clampedThickness: 0
    }

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right

    implicitWidth: root.notifWidth + padding * 2
    implicitHeight: {
        const count = list.count;
        if (count === 0)
            return 0;

        let height = (count - 1) * Tokens.spacing.smaller;
        for (let i = 0; i < count; i++)
            height += (list.itemAtIndex(i) as NotifWrapper)?.nonAnimHeight ?? 0;

        // Outer padding equal on all sides (top == sides == bottom)
        height += padding * 2;

        if (visibilities.osd) {
            const h = osdPanel.y - safeBorder.rounding * 2;
            if (height > h)
                height = h;
        }

        if (visibilities.session) {
            const h = sessionPanel.y - safeBorder.rounding * 2;
            if (height > h)
                height = h;
        }

        return Math.min(((QsWindow.window as QsWindow)?.screen?.height ?? 0) - safeBorder.thickness * 2, height);
    }

    // Container content area — equal padding on every side
    Item {
        anchors.fill: parent
        anchors.topMargin: root.padding
        anchors.bottomMargin: root.padding
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding

        StyledListView {
            id: list

            model: ScriptModel {
                values: Notifs.popups.filter(n => !n.closed)
            }

            anchors.fill: parent
            clip: true

            orientation: Qt.Vertical
            spacing: 0
            cacheBuffer: (QsWindow.window as QsWindow)?.screen.height ?? 0
            edgeFades: false

            delegate: NotifWrapper {}

            move: Transition {
                Anim {
                    property: "y"
                }
            }

            displaced: Transition {
                Anim {
                    property: "y"
                }
            }

            ExtraIndicator {
                anchors.top: parent.top
                extra: {
                    const count = list.count;
                    if (count === 0)
                        return 0;
                    const scrollY = list.contentY;
                    let height = 0;
                    for (let i = 0; i < count; i++) {
                        height += ((list.itemAtIndex(i) as NotifWrapper)?.nonAnimHeight ?? 0) + Tokens.spacing.smaller;
                        if (height - Tokens.spacing.smaller >= scrollY)
                            return i;
                    }
                    return count;
                }
            }

            ExtraIndicator {
                anchors.bottom: parent.bottom
                extra: {
                    const count = list.count;
                    if (count === 0)
                        return 0;
                    const scrollY = list.contentHeight - (list.contentY + list.height);
                    let height = 0;
                    for (let i = count - 1; i >= 0; i--) {
                        height += ((list.itemAtIndex(i) as NotifWrapper)?.nonAnimHeight ?? 0) + Tokens.spacing.smaller;
                        if (height - Tokens.spacing.smaller >= scrollY)
                            return count - i - 1;
                    }
                    return 0;
                }
            }
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }

    component NotifWrapper: Item {
        id: wrapper

        required property NotifData modelData
        required property int index
        readonly property alias nonAnimHeight: notif.nonAnimHeight
        property int idx

        onIndexChanged: {
            if (index !== -1)
                idx = index;
        }

        implicitWidth: root.notifWidth
        implicitHeight: notif.implicitHeight + (idx === 0 ? 0 : Tokens.spacing.smaller)
        width: ListView.view ? ListView.view.width : implicitWidth

        ListView.onRemove: removeAnim.start()

        SequentialAnimation {
            id: removeAnim

            PropertyAction {
                target: wrapper
                property: "ListView.delayRemove"
                value: true
            }
            PropertyAction {
                target: wrapper
                property: "enabled"
                value: false
            }
            PropertyAction {
                target: wrapper
                property: "implicitHeight"
                value: 0
            }
            PropertyAction {
                target: wrapper
                property: "z"
                value: 1
            }
            NumberAnimation {
                target: notif
                property: "x"
                // Use Content Item's notifWidth — never Tokens.sizes on Anim/NumberAnimation
                to: (notif.x >= 0 ? root.notifWidth : -root.notifWidth) * 2
                duration: root.Tokens.anim.durations.normal
                easing: root.Tokens.anim.emphasized
            }
            PropertyAction {
                target: wrapper
                property: "ListView.delayRemove"
                value: false
            }
        }

        StyledClippingRect {
            anchors.top: parent.top
            anchors.topMargin: wrapper.idx === 0 ? 0 : Tokens.spacing.smaller
            anchors.horizontalCenter: parent.horizontalCenter

            width: root.notifWidth
            height: Math.max(1, notif.implicitHeight)
            radius: root.cardRadius
            color: "transparent"
            antialiasing: true

            Notification {
                id: notif

                // Keep free x for slide-in animation
                width: root.notifWidth
                modelData: wrapper.modelData
            }
        }
    }

    // Duration/easing from this Item's Tokens (has screen), not on the animation object
    component Anim: NumberAnimation {
        duration: root.Tokens.anim.durations.expressiveDefaultSpatial
        easing: root.Tokens.anim.expressiveDefaultSpatial
    }
}
