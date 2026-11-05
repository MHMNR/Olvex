import ".."
import "."
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

// Android 17 (M3 Expressive) Connected Stack Section
// Renders clean group title + connected row stack with variable corner radiuses
Item {
    id: root

    property string title: ""
    property string description: ""
    property string icon: ""
    property color accentColor: Colours.palette.m3primary
    property bool collapsible: false
    property bool collapsed: false

    default property alias content: col.data

    Layout.fillWidth: true
    implicitWidth: parent ? parent.width : 0
    width: parent ? parent.width : implicitWidth
    implicitHeight: (header.visible ? header.height + 8 : 0) + contentHolder.height

    // ── Group Header (Clean title in primary accent, Android 17 style) ──
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        height: root.title !== "" ? 28 : 0
        visible: root.title !== ""

        RowLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.small

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: root.title.toUpperCase()
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                textPointSize: 11
                color: {
                    const c = root.accentColor ? root.accentColor.toString() : "";
                    if (c && c !== "#000000" && c !== "#ff000000" && c !== "#00000000") {
                        return root.accentColor;
                    }
                    return Colours.palette.m3primary;
                }
            }

            Item { Layout.fillWidth: true }

            // Collapsible Chevron Indicator
            StyledRect {
                id: collapseToggleBtn
                visible: root.collapsible
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: Tokens.rounding.full
                color: collapseMa.pressed ? Qt.alpha(Colours.palette.m3onSurface, 0.16)
                     : collapseMa.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : "transparent"

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "expand_more"
                    iconPointSize: 18
                    color: (root.accentColor && root.accentColor != "#000000") ? root.accentColor : Colours.palette.m3secondary
                    rotation: root.collapsed ? -90 : 0
                    Behavior on rotation { Anim { type: Anim.DefaultSpatial } }
                }

                MouseArea {
                    id: collapseMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.collapsed = !root.collapsed;
                        root.scheduleUpdate();
                    }
                }
            }
        }
    }

    // ── Animated Collapsible Content Wrapper ──────────────────────────────
    Item {
        id: contentHolder
        anchors.top: header.visible ? header.bottom : parent.top
        anchors.topMargin: header.visible ? 8 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.collapsed ? 0 : col.implicitHeight
        opacity: root.collapsed ? 0.0 : 1.0
        clip: true
        visible: height > 0 || opacity > 0.01

        Behavior on height {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // ── Connected Stack Column ───────────────────────────────────────────
        Column {
            id: col
            width: parent.width
            spacing: 3 // Signature Android 17 connected stack gap

            onChildrenChanged: root.scheduleUpdate()
        }
    }

    Timer {
        id: updateDebounceTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (col) {
                root.updateRowPositions();
            }
        }
    }

    // Dynamic connection tracker using Set to avoid assigning dynamic properties to QML QObjects
    readonly property var trackedItems: new Set()

    function scheduleUpdate() {
        if (updateDebounceTimer && !updateDebounceTimer.running) {
            updateDebounceTimer.restart();
        }
    }

    function updateRowPositions() {
        if (!col) return;
        let visibleRows = [];

        function collectRows(item, parentVisible) {
            if (!item) return;
            let isItemVis = (parentVisible !== false) && (item.visible !== false);
            let ch = item.children || [];
            for (let i = 0; i < ch.length; i++) {
                let c = ch[i];
                if (!c) continue;

                // Watch Repeater count/model changes if present
                if (c.hasOwnProperty("count") && c.hasOwnProperty("model")) {
                    if (!root.trackedItems.has(c)) {
                        root.trackedItems.add(c);
                        if (c.countChanged) {
                            c.countChanged.connect(root.scheduleUpdate);
                        }
                    }
                }

                // If child is a SettingRow / row item with isFirstInGroup property
                if (c.hasOwnProperty("isFirstInGroup")) {
                    if (!root.trackedItems.has(c)) {
                        root.trackedItems.add(c);
                        if (c.visibleChanged) {
                            c.visibleChanged.connect(root.scheduleUpdate);
                        }
                    }
                    if (isItemVis && c.visible) {
                        visibleRows.push(c);
                    }
                } else if (c.children && c.children.length > 0) {
                    if (!root.trackedItems.has(c)) {
                        root.trackedItems.add(c);
                        if (c.visibleChanged) {
                            c.visibleChanged.connect(root.scheduleUpdate);
                        }
                    }
                    collectRows(c, isItemVis);
                }
            }
        }

        collectRows(col, true);

        for (let i = 0; i < visibleRows.length; i++) {
            let r = visibleRows[i];
            r.isFirstInGroup = (i === 0);
            r.isLastInGroup = (i === visibleRows.length - 1);
            r.isSingleInGroup = (visibleRows.length === 1);
        }
    }

    Component.onCompleted: {
        root.updateRowPositions();
        root.scheduleUpdate();
    }
}
