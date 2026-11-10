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

// Android 17 (M3 Expressive) Connected Setting Row
// Features dynamic corner rounding (22dp outer, 6dp inner), optional squircle icon,
// and full-row click activation for switches.
StyledRect {
    id: root

    property Session session: null
    property string highlightKey: ""
    property string title: ""
    property string description: ""
    property string icon: ""
    property Component customIcon: null
    property var keys: []
    property bool clickable: false
    property bool divider: false // Deprecated: connected stack uses gap spacing instead of hairline divider

    // Clean neutral variant for description text — follows M3 specification
    property color descriptionColor: Colours.light
        ? Qt.alpha(Colours.palette.m3onSurface, 0.76)
        : Colours.palette.m3onSurfaceVariant

    // Optional icon background tint (defaults to primaryContainer, set transparent for clean borderless icon)
    property bool showIconBackground: true
    property color iconContainerColor: showIconBackground ? Qt.alpha(Colours.palette.m3primary, 0.15) : "transparent"
    property color iconColor: Colours.palette.m3primary

    // Group position flags (automatically managed by Section.qml)
    property bool isFirstInGroup: false
    property bool isLastInGroup: false
    property bool isSingleInGroup: false

    default property alias control: controlHolder.data

    signal clicked

    Layout.fillWidth: true
    implicitWidth: parent ? parent.width : 0
    implicitHeight: Math.max(58, Math.max(textCol.implicitHeight, controlHolder.implicitHeight) + 20)
    width: parent ? parent.width : implicitWidth

    // Variable corner radiuses matching Android 17 Connected Stack
    readonly property real topR: (isSingleInGroup || isFirstInGroup) ? 22 : 6
    readonly property real bottomR: (isSingleInGroup || isLastInGroup) ? 22 : 6
    topLeftRadius: topR
    topRightRadius: topR
    bottomLeftRadius: bottomR
    bottomRightRadius: bottomR

    property bool isReady: false

    Behavior on topLeftRadius { enabled: root.isReady; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on topRightRadius { enabled: root.isReady; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on bottomLeftRadius { enabled: root.isReady; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on bottomRightRadius { enabled: root.isReady; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    property color customCardColor: "transparent"
    property color customCardHoverColor: "transparent"

    border.width: 0
    border.color: "transparent"
    color: {
        const isHovered = clickArea.containsMouse && (root.clickable || root.hasSwitch) && root.enabled;
        if (root.customCardColor.a > 0) {
            return (isHovered && root.customCardHoverColor.a > 0) ? root.customCardHoverColor : root.customCardColor;
        }
        return isHovered ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainerHigh;
    }

    Behavior on color { CAnim {} }

    opacity: root.enabled ? 1.0 : 0.45
    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // ── Optional Squircle Icon Box (Only shown if icon is explicitly provided) ──
    Item {
        id: iconHolder
        visible: !!root.customIcon || (root.icon !== "")
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? 40 : 0
        height: 40

        StyledRect {
            anchors.fill: parent
            radius: 12
            color: root.iconContainerColor
            border.width: 0

            Loader {
                id: customIconLoader
                visible: !!root.customIcon
                active: !!root.customIcon
                sourceComponent: root.customIcon
                anchors.centerIn: parent
            }

            MaterialIcon {
                id: iconItem
                visible: !root.customIcon && !!root.icon
                anchors.centerIn: parent
                text: root.icon
                color: root.iconColor
                iconPointSize: 20
            }
        }
    }

    // ── Label Column (Title + Description) ──────────────────────────────────
    Column {
        id: textCol
        anchors.left: iconHolder.visible ? iconHolder.right : parent.left
        anchors.leftMargin: iconHolder.visible ? 14 : 18
        anchors.right: controlHolder.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        RowLayout {
            width: parent.width
            spacing: 8

            StyledText {
                text: root.title
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                font.weight: Font.DemiBold
                font.letterSpacing: -0.1
                lineHeight: 1.25
                lineHeightMode: Text.ProportionalHeight
                color: Colours.palette.m3onSurface
                textPointSize: Tokens.font.size.normal
                verticalAlignment: Text.AlignVCenter
            }

            RowLayout {
                visible: root.keys && root.keys.length > 0
                spacing: 3
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: root.keys

                    delegate: RowLayout {
                        id: keyItem
                        required property var modelData
                        required property int index
                        readonly property int totalCount: root.keys.length
                        spacing: 3

                        StyledRect {
                            implicitHeight: 22
                            implicitWidth: Math.max(22, keyLabel.implicitWidth + 12)
                            radius: 6
                            color: keyItem.modelData.isTrigger
                                ? Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.20 : 0.22)
                                : (Colours.light ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : Qt.alpha(Colours.palette.m3primary, 0.14))
                            border.width: 0
                            border.color: "transparent"

                            StyledText {
                                id: keyLabel
                                anchors.centerIn: parent
                                text: keyItem.modelData.text
                                color: keyItem.modelData.isTrigger
                                    ? Colours.palette.m3primary
                                    : Colours.palette.m3onSurface
                                font.family: Tokens.font.family.mono || "monospace"
                                font.weight: Font.DemiBold
                                textPointSize: 9
                            }
                        }

                        StyledText {
                            visible: keyItem.index < keyItem.totalCount - 1
                            text: "+"
                            color: Colours.light ? Qt.alpha(Colours.palette.m3onSurface, 0.5) : Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.5)
                            font.weight: Font.DemiBold
                            textPointSize: 8
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        StyledText {
            width: parent.width
            visible: !!root.description
            text: root.description
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            color: root.descriptionColor
            font.weight: Font.Normal
            font.letterSpacing: 0.1
            lineHeight: 1.35
            lineHeightMode: Text.ProportionalHeight
            textPointSize: Tokens.font.size.small
        }
    }

    // ── Control Slot (Switch, Slider, Segmented, OptionPicker) ───────────────
    Item {
        id: controlHolder
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: {
            if (children.length === 0) return 0;
            let c = children[0];
            if (c.width > 0 && c.implicitWidth > 0 && c.width !== c.implicitWidth) {
                return c.width;
            }
            return c.implicitWidth || c.width || Math.max(0, childrenRect.width);
        }
        implicitHeight: {
            if (children.length === 0) return 0;
            let c = children[0];
            if (c.height > 0 && c.implicitHeight > 0 && c.height !== c.implicitHeight) {
                return c.height;
            }
            return c.implicitHeight || c.height || Math.max(0, childrenRect.height);
        }
        width: implicitWidth
        height: implicitHeight
        z: 3

        onChildrenChanged: {
            if (children.length > 0) {
                let c = children[0];
                if (c && !c.anchors.right && !c.anchors.fill) {
                    c.anchors.right = controlHolder.right;
                }
            }
            Qt.callLater(root.updateSwitchTarget);
        }
    }

    // ── Switch Auto-Detection for Whole-Row Toggle Activation ────────────────
    property Item switchTarget: null

    function updateSwitchTarget() {
        switchTarget = findSwitch(controlHolder);
    }

    function findSwitch(parentItem) {
        if (!parentItem) return null;
        for (let i = 0; i < parentItem.children.length; i++) {
            let child = parentItem.children[i];
            if (child && (child.hasOwnProperty("toggled") || (child.hasOwnProperty("checked") && typeof child.toggle === "function"))) {
                return child;
            }
            if (child && child.children && child.children.length > 0) {
                let nested = findSwitch(child);
                if (nested) return nested;
            }
        }
        return null;
    }

    readonly property bool hasSwitch: switchTarget !== null

    MouseArea {
        id: clickArea
        anchors.fill: parent
        anchors.rightMargin: root.hasSwitch ? (controlHolder.width + 16) : 0
        visible: root.clickable || root.hasSwitch
        enabled: root.clickable || root.hasSwitch
        hoverEnabled: true
        cursorShape: (root.clickable || root.hasSwitch) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.hasSwitch && root.switchTarget) {
                if (typeof root.switchTarget.toggle === "function") {
                    root.switchTarget.toggle();
                } else if (root.switchTarget.hasOwnProperty("checked")) {
                    root.switchTarget.checked = !root.switchTarget.checked;
                }
            }
            if (root.clickable) {
                root.clicked();
            }
        }
    }

    // ── Ultra-sanitize for search target highlighting ────────────────────────
    function ultraSanitize(str) {
        if (!str) return "";
        return String(str).toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function isTargetHighlighted() {
        if (!PaneRegistry.highlightTimestamp || (Date.now() - PaneRegistry.highlightTimestamp > 4000))
            return false;

        const hTitle = ultraSanitize(PaneRegistry.highlightTitle);
        const hId = ultraSanitize(PaneRegistry.highlightId);
        const hKey = ultraSanitize(PaneRegistry.highlightKey);

        if (!hTitle && !hId && !hKey)
            return false;

        const myKey = ultraSanitize(root.highlightKey);
        const myTitle = ultraSanitize(root.title);

        if (myKey && (myKey === hKey || myKey === hId || myKey === hTitle))
            return true;

        if (myTitle && hTitle) {
            if (myTitle === hTitle)
                return true;
            if (myTitle.length >= 3 && (hTitle.endsWith(myTitle) || hTitle.startsWith(myTitle)))
                return true;
        }

        if (myTitle && hId && hId.endsWith(myTitle))
            return true;

        return false;
    }

    function triggerFlash() {
        if (rowFlashAnim.running)
            rowFlashAnim.stop();
        rowFlashAnim.restart();
    }

    // ── Android-style Row Highlight Flash (3 Pulses) ──────────────────────
    StyledRect {
        id: rowFlashOverlay
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: Qt.alpha(Colours.palette.m3primary, 0.24)
        border.width: 0
        opacity: 0.0
        z: 10
        visible: opacity > 0.001

        SequentialAnimation {
            id: rowFlashAnim
            running: false
            PauseAnimation { duration: 240 }
            NumberAnimation { target: rowFlashOverlay; property: "opacity"; from: 0.0; to: 1.0; duration: 120; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 60 }
            NumberAnimation { target: rowFlashOverlay; property: "opacity"; from: 1.0; to: 0.15; duration: 140; easing.type: Easing.InOutQuad }
            NumberAnimation { target: rowFlashOverlay; property: "opacity"; from: 0.15; to: 1.0; duration: 120; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 60 }
            NumberAnimation { target: rowFlashOverlay; property: "opacity"; from: 1.0; to: 0.15; duration: 140; easing.type: Easing.InOutQuad }
            NumberAnimation { target: rowFlashOverlay; property: "opacity"; from: 0.15; to: 1.0; duration: 120; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 100 }
            NumberAnimation { target: rowFlashOverlay; property: "opacity"; from: 1.0; to: 0.0; duration: 600; easing.type: Easing.OutCubic }
        }
    }

    Connections {
        target: PaneRegistry
        function onHighlightTimestampChanged() {
            if (root.isTargetHighlighted()) {
                root.triggerFlash();
            }
        }
    }

    function notifySection() {
        let p = root.parent;
        while (p) {
            if (typeof p.updateRowPositions === "function") {
                p.updateRowPositions();
                break;
            }
            p = p.parent;
        }
    }

    Component.onCompleted: {
        updateSwitchTarget();
        notifySection();
        if (root.isTargetHighlighted()) {
            root.triggerFlash();
        }
        Qt.callLater(() => { root.isReady = true; });
    }
}
