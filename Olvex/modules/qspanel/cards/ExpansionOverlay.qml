import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../../bar/popouts" as Popouts

Item {
    id: root

    focus: active
    Keys.forwardTo: [contentLoader]

    required property var props
    required property DrawerVisibilities visibilities

    readonly property bool active: props.expansionActive !== ""
    property bool btEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    property string lastActiveType: ""
    property var passwordNetwork: null
    readonly property bool needsKeyboard: dummyPopoutState.currentName === "wirelesspassword"

    // ── Tile hiding ──────────────────────────────────────────────────────────
    // Tile stays hidden the ENTIRE time the overlay is visible.
    // Overlay always looks like the tile at collapsed state → seamless swap.
    Binding {
        target: props
        property: "isTransitioning"
        value: root._overlayVisible
    }

    // ── Overlay visibility (no opacity fade — use visible + Timer) ───────────
    property bool _overlayVisible: false
    visible: _overlayVisible
    opacity: 1
    z: 100

    Timer {
        id: hideTimer
        interval: root.collapseDur
        onTriggered: root._overlayVisible = false
    }

    // Save tile position at expansion start — collapse must return HERE exactly
    property point savedStartPoint:     Qt.point(0, 0)
    property size  savedStartSize:      Qt.size(100, 110)
    property real  savedIconPillY:      8
    property real  savedIconPillHeight: 55
    
    readonly property bool currentOn: {
        if (lastActiveType === "network") return Nmcli.wifiEnabled;
        if (lastActiveType === "bluetooth") return btEnabled;
        return true;
    }
    // For flat full-width pills (displayprojection), iconPill fills the entire tile
    readonly property real liveIconPillWidth: {
        if (lastActiveType === "displayprojection") return savedStartSize.width;
        return currentOn ? 100 : 55;
    }
    readonly property real liveIconPillX: {
        if (lastActiveType === "displayprojection") return 0;
        return (savedStartSize.width - liveIconPillWidth) / 2;
    }

    onActiveChanged: {
        if (active) {
            // Capture ALL element positions BEFORE expansion starts
            const srcItem = props.expansionSourceItem
            const pillW   = (srcItem && srcItem.checked) ? 100 : 55
            
            // Bulletproof coordinate mapping that works for all nested layouts (like customPillsColumn) and repeaters!
            var mapped = srcItem.mapToItem(root, 0, 0)
            const scale = srcItem.scale || 1.0
            if (scale !== 1.0) {
                const dx = (1.0 - scale) * srcItem.width / 2
                const dy = (1.0 - scale) * srcItem.height / 2
                mapped.x -= dx
                mapped.y -= dy
            }

            savedStartPoint    = Qt.point(mapped.x, mapped.y)
            savedStartSize     = Qt.size(props.expansionSource.width, props.expansionSource.height)
            // displayProjectionPill is flat full-width: iconPill starts at (0,0) filling entire tile
            if (props.expansionActive === "displayprojection") {
                savedIconPillY      = 0
                savedIconPillHeight = props.expansionSource.height
            } else {
                savedIconPillY      = 8
                savedIconPillHeight = 55
            }

            lastActiveType = props.expansionActive
            root.passwordNetwork = null; // Reset for new expansion
            if (lastActiveType === "network") {
                dummyPopoutState.currentName = "network";
                Nmcli.rescanWifi(); // Auto-scan when opening
            } else if (lastActiveType === "bluetooth") {
                dummyPopoutState.currentName = "bluetooth";
            } else if (lastActiveType === "powerprofile") {
                dummyPopoutState.currentName = "powerprofile";
            } else if (lastActiveType === "displayprojection") {
                dummyPopoutState.currentName = "displayprojection";
            }
            
            btEnabled = Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
            hideTimer.stop()
            _overlayVisible = true
        } else {
            // Reset rescan states on collapse
            Nmcli.stopWifiScan()
            const adapter = Bluetooth.defaultAdapter
            if (adapter) adapter.discovering = false
            
            hideTimer.start()
        }
    }

    // ── Bluetooth sync ───────────────────────────────────────────────────────
    Connections {
        target: Bluetooth
        function onDefaultAdapterChanged() {
            root.btEnabled = Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
        }
    }
    Connections {
        target: Bluetooth.defaultAdapter ?? null
        ignoreUnknownSignals: true
        function onEnabledChanged() {
            root.btEnabled = Bluetooth.defaultAdapter.enabled
        }
    }

    // ── Constants ────────────────────────────────────────────────────────────
    // Material Design 3 "Emphasized" two-segment PathInterpolator from Android source:
    //   M 0,0 C 0.05,0 0.133333,0.06 0.166666,0.4 C 0.208333,0.82 0.25,1 1,1
    readonly property var md3Emphasized: [0.05, 0, 0.133333, 0.06, 0.166666, 0.4, 0.208333, 0.82, 0.25, 1, 1, 1]
    // MD3 "Emphasized Decelerate" — cubic-bezier(0.05, 0.7, 0.1, 1.0)
    readonly property var md3EmphasizedDecelerate: [0.05, 0.7, 0.1, 1.0, 1, 1]
    readonly property int expandDur: 500
    readonly property int collapseDur: 400
    readonly property int dur: Tokens.anim.durations.normal
    readonly property int expandedHeight: Math.min(root.height - 80, Math.max(150, contentLoader.implicitHeight + 120))

    MouseArea {
        anchors.fill: parent
        enabled: root.active
        hoverEnabled: true
        propagateComposedEvents: false

        // Explicitly accept ALL press events so they never reach Wayland windows beneath
        onPressed: (mouse) => {
            mouse.accepted = true;
        }

        onClicked: (mouse) => {
            mouse.accepted = true;
            // Only collapse if clicked OUTSIDE the card
            const cardRect = card.mapToItem(root, 0, 0, card.width, card.height);
            if (mouse.x < cardRect.x || mouse.x > cardRect.x + cardRect.width ||
                mouse.y < cardRect.y || mouse.y > cardRect.y + cardRect.height) {
                root.props.expansionActive = "";
            }
        }
    }

    // ── Card ─────────────────────────────────────────────────────────────────
    StyledRect {
        id: card

        // Collapsed default — bound to SAVED position so collapse returns exactly here
        x: root.savedStartPoint.x
        y: root.savedStartPoint.y
        width: root.savedStartSize.width
        height: root.savedStartSize.height
        radius: 32
        color: Colours.tileGlass
        border.color: "transparent"
        border.width: 0
        clip: true

        Behavior on color { ColorAnimation { duration: 250 } }
        
        // Behaviors ensure that if the list grows/shrinks WHILE expanded, the card size adapts smoothly
        Behavior on height {
            enabled: card.state === "expanded" && !expandTransition.running && !collapseTransition.running
            NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
        }
        Behavior on y {
            enabled: card.state === "expanded" && !expandTransition.running && !collapseTransition.running
            NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
        }

        // ── States (music pill pattern) ──────────────────────────────────────
        state: root.active ? "expanded" : "collapsed"

        states: [
            State {
                name: "expanded"
                PropertyChanges {
                    target: card
                    x: 0
                    // Expand downwards from the tile's position, but clamp to fit inside the panel
                    y: Math.max(20, Math.min(root.savedStartPoint.y, root.height - root.expandedHeight - 20))
                    width: root.width
                    height: root.expandedHeight
                    radius: Tokens.rounding.large
                    color: Colours.tileFill
                    border.color: "transparent"
                    border.width: 0
                }
                PropertyChanges {
                    target: iconPill
                    x: headerControls.x + headerSwitch.x
                    y: headerControls.y + headerSwitch.y
                    width: headerSwitch.width
                    height: headerSwitch.height
                    radius: headerSwitch.height / 2
                    opacity: 0
                }
                PropertyChanges {
                    target: headerIcon
                    x: Tokens.padding.large
                    y: 12 + (48 - headerIcon.implicitHeight * headerIcon.smallScale) / 2
                    scale: headerIcon.smallScale
                    opacity: 0
                }
                PropertyChanges {
                    target: tileLabelSmall
                    x: Tokens.padding.large
                    y: 12 + (48 - tileLabel.implicitHeight) / 2
                    scale: tileLabelSmall.largeScale
                    opacity: 0
                }
                PropertyChanges {
                    target: tileLabel
                    x: Tokens.padding.large
                    y: 12 + (48 - tileLabel.implicitHeight) / 2
                    scale: 1
                    opacity: 1
                }
                PropertyChanges { target: tileStateLabel; opacity: 0 }
                PropertyChanges { target: headerControls; opacity: 1 }
                PropertyChanges { target: expandedContent; opacity: 1 }
            },
            State {
                name: "collapsed"
                PropertyChanges {
                    target: card
                    x: root.savedStartPoint.x
                    y: root.savedStartPoint.y
                    width: root.savedStartSize.width
                    height: root.savedStartSize.height
                    radius: 32
                    color: Colours.tileGlass
                    border.color: "transparent"
                    border.width: 0
                }
                PropertyChanges {
                    target: iconPill
                    x: root.liveIconPillX
                    y: root.savedIconPillY
                    width: root.liveIconPillWidth
                    height: root.savedIconPillHeight
                    radius: root.lastActiveType === "displayprojection" ? 32 : height / 2
                    opacity: 1
                }
                PropertyChanges {
                    target: headerIcon
                    x: root.lastActiveType === "displayprojection"
                        ? Tokens.padding.normal
                        : root.liveIconPillX + (root.liveIconPillWidth - headerIcon.implicitWidth) / 2
                    y: root.lastActiveType === "displayprojection"
                        ? root.savedIconPillY + (root.savedIconPillHeight - headerIcon.implicitHeight) / 2
                        : root.savedIconPillY + (55 - headerIcon.implicitHeight) / 2
                    scale: root.lastActiveType === "displayprojection" ? 1 : 1
                }
                PropertyChanges {
                    target: chevronRightIcon
                    x: root.savedStartSize.width - Tokens.padding.normal - chevronRightIcon.implicitWidth
                    y: root.savedIconPillY + (root.savedIconPillHeight - chevronRightIcon.implicitHeight) / 2
                    opacity: root.lastActiveType === "displayprojection" ? 1 : 0
                }
                PropertyChanges {
                    target: tileLabelSmall
                    // displayprojection: text centered inside pill (not below it)
                    x: (root.savedStartSize.width - tileLabelSmall.width) / 2
                    y: root.lastActiveType === "displayprojection"
                        ? root.savedIconPillY + (root.savedIconPillHeight - tileLabelSmall.implicitHeight) / 2
                        : 8 + 55 + 6
                    scale: 1
                    opacity: 1
                }
                PropertyChanges {
                    target: tileLabel
                    x: (root.savedStartSize.width - tileLabel.implicitWidth * tileLabel.smallScale) / 2
                    y: root.lastActiveType === "displayprojection"
                        ? root.savedIconPillY + (root.savedIconPillHeight - tileLabel.implicitHeight) / 2
                        : 8 + 55 + 6
                    scale: tileLabel.smallScale
                    opacity: 0
                }
                PropertyChanges {
                    target: tileStateLabel
                    x: (root.savedStartSize.width - tileStateLabel.implicitWidth) / 2
                    y: root.lastActiveType === "displayprojection"
                        ? root.savedIconPillY + root.savedIconPillHeight + 4
                        : 8 + 55 + 6 + tileLabelSmall.implicitHeight + 2
                    // Hide state label for displayprojection (pill shows no state below)
                    opacity: root.lastActiveType === "displayprojection" ? 0 : 0.8
                }
                PropertyChanges { target: headerControls; opacity: 0 }
                PropertyChanges { target: expandedContent; opacity: 0 }
            }
        ]

        // ── Transitions (all elements animate simultaneously) ────────────────
        // Uses the exact Material Design 3 "Emphasized" two-segment PathInterpolator
        // from Android source for premium, buttery-smooth container transforms.
        transitions: [
            Transition {
                id: expandTransition
                from: "collapsed"; to: "expanded"
                ParallelAnimation {
                    NumberAnimation {
                        target: card
                        properties: "x,y,width,height,radius"
                        duration: expandDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3Emphasized
                    }
                    NumberAnimation {
                        target: iconPill
                        properties: "x,y,width,height,radius"
                        duration: expandDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3Emphasized
                    }
                    NumberAnimation {
                        target: headerIcon
                        properties: "x,y,scale,opacity"
                        duration: expandDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3Emphasized
                    }
                    NumberAnimation {
                        target: chevronRightIcon
                        properties: "x,y,opacity"
                        duration: expandDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3Emphasized
                    }
                    NumberAnimation {
                        target: iconPill
                        property: "opacity"
                        duration: 120
                    }
                    NumberAnimation {
                        target: tileLabel
                        properties: "x,y,scale,opacity"
                        duration: expandDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3Emphasized
                    }
                    NumberAnimation {
                        target: tileLabelSmall
                        properties: "x,y,scale,opacity"
                        duration: expandDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3Emphasized
                    }
                    NumberAnimation {
                        target: tileStateLabel
                        properties: "x,y,opacity"
                        duration: 100
                    }
                    NumberAnimation {
                        target: headerControls
                        property: "opacity"
                        duration: 250; easing.type: Easing.Bezier; easing.bezierCurve: root.md3EmphasizedDecelerate
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 180 }
                        NumberAnimation {
                            target: expandedContent
                            property: "opacity"
                            duration: 280; easing.type: Easing.Bezier; easing.bezierCurve: root.md3EmphasizedDecelerate
                        }
                    }
                }
            },
            Transition {
                id: collapseTransition
                from: "expanded"; to: "collapsed"
                ParallelAnimation {
                    NumberAnimation {
                        target: card
                        properties: "x,y,width,height,radius"
                        duration: collapseDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3Emphasized
                    }
                    NumberAnimation {
                        target: iconPill
                        properties: "x,y,width,height,radius"
                        duration: collapseDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3Emphasized
                    }
                    NumberAnimation {
                        target: headerIcon
                        properties: "x,y,scale,opacity"
                        duration: collapseDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3Emphasized
                    }
                    NumberAnimation {
                        target: chevronRightIcon
                        properties: "x,y,opacity"
                        duration: collapseDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3Emphasized
                    }
                    NumberAnimation {
                        target: iconPill
                        property: "opacity"
                        duration: collapseDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3EmphasizedDecelerate
                    }
                    // Expanded content hides fast
                    NumberAnimation {
                        target: expandedContent
                        property: "opacity"
                        duration: 100; easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: headerControls
                        property: "opacity"
                        duration: 100; easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: tileLabel
                        properties: "x,y,scale,opacity"
                        duration: collapseDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3Emphasized
                    }
                    NumberAnimation {
                        target: tileLabelSmall
                        properties: "x,y,scale,opacity"
                        duration: collapseDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3Emphasized
                    }
                    NumberAnimation {
                        target: tileStateLabel
                        properties: "x,y,opacity"
                        duration: collapseDur; easing.type: Easing.Bezier; easing.bezierCurve: root.md3EmphasizedDecelerate
                    }
                }
            }
        ]

        // ── Header (icon pill + controls) ────────────────────────────────────
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 65

            StyledRect {
                id: iconPill
                // Collapsed default — bound to live values
                x: root.liveIconPillX
                y: root.savedIconPillY
                width: root.liveIconPillWidth
                height: root.savedIconPillHeight
                radius: root.lastActiveType === "displayprojection" ? 32 : height / 2
                color: {
                    // displayprojection has no on/off state — always transparent
                    if (root.lastActiveType === "displayprojection") return "transparent";
                    const on = root.lastActiveType === "network" ? Nmcli.wifiEnabled : (root.lastActiveType === "bluetooth" ? root.btEnabled : true);
                    if (root.active) {
                        return on ? Colours.palette.m3primary : "transparent";
                    } else {
                        return on ? Colours.palette.m3primary : Colours.tPalette.m3surfaceVariant;
                    }
                }
                
                border.width: {
                    if (root.lastActiveType === "displayprojection") return 0;
                    const on = root.lastActiveType === "network" ? Nmcli.wifiEnabled : (root.lastActiveType === "bluetooth" ? root.btEnabled : true);
                    return (root.active && !on) ? 2 : 0;
                }
                border.color: Colours.palette.m3outline

                Behavior on color { ColorAnimation { duration: root.dur; easing.type: Easing.OutExpo } }
                Behavior on border.width { NumberAnimation { duration: root.dur; easing.type: Easing.OutExpo } }
            }

            MaterialIcon {
                id: headerIcon
                
                property real smallScale: root.lastActiveType === "displayprojection" ? 1 : Tokens.font.size.normal / Tokens.font.size.large
                iconPointSize: root.lastActiveType === "displayprojection" ? Tokens.font.size.normal : Tokens.font.size.large
                transformOrigin: Item.TopLeft
                
                // Static coordinates so animation doesn't fight bindings
                property real startX: root.lastActiveType === "displayprojection"
                    ? Tokens.padding.normal
                    : root.liveIconPillX + (root.liveIconPillWidth - implicitWidth) / 2
                property real startY: root.lastActiveType === "displayprojection"
                    ? root.savedIconPillY + (root.savedIconPillHeight - implicitHeight) / 2
                    : root.savedIconPillY + (55 - implicitHeight) / 2
                
                x: startX
                y: startY
                scale: 1

                text: {
                    if (root.lastActiveType === "network") return "wifi"
                    if (root.lastActiveType === "bluetooth") return "bluetooth"
                    if (root.lastActiveType === "powerprofile") {
                        const p = PowerProfiles.profile;
                        if (p === PowerProfile.PowerSaver) return "energy_savings_leaf";
                        if (p === PowerProfile.Performance) return "rocket_launch";
                        return "balance";
                    }
                    if (root.lastActiveType === "displayprojection") {
                        const mode = DisplayProjection.activeProjection;
                        if (mode === "primary") return "laptop";
                        if (mode === "secondary") return "tv";
                        if (mode === "mirror") return "sync";
                        return "grid_view";
                    }
                    return ""
                }
                color: {
                    if (root.lastActiveType === "displayprojection") return Colours.palette.m3onSurface;
                    const on = (root.lastActiveType === "network" ? Nmcli.wifiEnabled : (root.lastActiveType === "bluetooth" ? root.btEnabled : true));
                    return on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface;
                }

                Behavior on color { ColorAnimation { duration: root.dur; easing.type: Easing.OutExpo } }
            }

            MaterialIcon {
                id: chevronRightIcon
                visible: root.lastActiveType === "displayprojection" && !root.active
                text: "chevron_right"
                color: Colours.palette.m3onSurfaceVariant
                iconPointSize: Tokens.font.size.normal
                
                property real startX: root.savedStartSize.width - Tokens.padding.normal - implicitWidth
                property real startY: root.savedIconPillY + (root.savedIconPillHeight - implicitHeight) / 2
                
                x: startX
                y: startY
                opacity: root.active ? 0 : 1

                Behavior on opacity { Anim { type: Anim.FastEffects } }
            }

            RowLayout {
                id: headerControls
                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.large
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: 36 // 12 + 48/2
                spacing: Tokens.spacing.normal
                opacity: 0
                visible: opacity > 0

                StyledSwitch {
                    id: headerSwitch
                    padding: 0
                    visible: root.lastActiveType !== "powerprofile" && root.lastActiveType !== "displayprojection"
                    checked: root.lastActiveType === "network" ? Nmcli.wifiEnabled : (root.lastActiveType === "bluetooth" ? root.btEnabled : false)
                    onToggled: {
                        if (root.lastActiveType === "network") {
                            Nmcli.enableWifi(checked)
                        } else if (root.lastActiveType === "bluetooth") {
                            const a = Bluetooth.defaultAdapter
                            if (a) a.enabled = checked
                        }
                    }
                }

                Item {
                    id: wifiScanCtl
                    visible: root.lastActiveType === "network"
                    implicitWidth: 36
                    implicitHeight: 36
                    readonly property bool scanning: Nmcli.scanning
                    readonly property bool canScan: Nmcli.wifiEnabled

                    LoadingIndicator {
                        anchors.centerIn: parent
                        implicitSize: 30
                        color: Colours.palette.m3primary
                        animated: wifiScanCtl.scanning
                        opacity: wifiScanCtl.scanning ? 1 : 0
                        scale: wifiScanCtl.scanning ? 1 : 0.72
                        visible: opacity > 0.01

                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                        Behavior on scale { Anim { type: Anim.DefaultSpatial } }
                    }

                    IconButton {
                        anchors.centerIn: parent
                        type: IconButton.Text
                        icon: "refresh"
                        inactiveOnColour: Colours.palette.m3primary
                        disabled: !wifiScanCtl.canScan
                        opacity: wifiScanCtl.scanning ? 0 : 1
                        visible: opacity > 0.01
                        enabled: wifiScanCtl.canScan && !wifiScanCtl.scanning

                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                        onClicked: if (Nmcli.wifiEnabled) Nmcli.rescanWifi()
                    }
                }

                Item {
                    id: btScanCtl
                    visible: root.lastActiveType === "bluetooth"
                    implicitWidth: 36
                    implicitHeight: 36
                    readonly property bool scanning: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discovering : false
                    readonly property bool canScan: root.btEnabled && (Bluetooth.defaultAdapter !== null)

                    LoadingIndicator {
                        anchors.centerIn: parent
                        implicitSize: 30
                        color: Colours.palette.m3primary
                        animated: btScanCtl.scanning
                        opacity: btScanCtl.scanning ? 1 : 0
                        scale: btScanCtl.scanning ? 1 : 0.72
                        visible: opacity > 0.01

                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                        Behavior on scale { Anim { type: Anim.DefaultSpatial } }
                    }

                    IconButton {
                        anchors.centerIn: parent
                        type: IconButton.Text
                        icon: "refresh"
                        inactiveOnColour: Colours.palette.m3primary
                        disabled: !btScanCtl.canScan
                        opacity: btScanCtl.scanning ? 0 : 1
                        visible: opacity > 0.01
                        enabled: btScanCtl.canScan && !btScanCtl.scanning

                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                        onClicked: {
                            const a = Bluetooth.defaultAdapter;
                            if (a) a.discovering = !a.discovering;
                        }
                    }
                }
            }
        }

        // ── Tile labels (visible in collapsed, morphs to header when expanded) ───
        StyledText {
            id: tileLabelSmall
            property real largeScale: Tokens.font.size.large / Tokens.font.size.small
            textPointSize: Tokens.font.size.small
            transformOrigin: Item.TopLeft
            font.bold: true
            color: Colours.palette.m3onSurface
            
            width: Math.min(implicitWidth, root.lastActiveType === "displayprojection" ? root.savedStartSize.width - Tokens.padding.normal * 2 - headerIcon.implicitWidth - chevronRightIcon.implicitWidth - Tokens.spacing.small * 2 : root.savedStartSize.width)
            elide: Text.ElideRight
            
            text: {
                if (root.lastActiveType === "network") return qsTr("Wi-Fi");
                if (root.lastActiveType === "bluetooth") return qsTr("Bluetooth");
                if (root.lastActiveType === "powerprofile") return qsTr("Power Profile");
                if (root.lastActiveType === "displayprojection") {
                    // Show mode name — matches what the pill shows
                    const mode = DisplayProjection.activeProjection;
                    if (mode === "primary") return qsTr("Primary");
                    if (mode === "secondary") return qsTr("Secondary Only");
                    if (mode === "mirror") return qsTr("Mirror");
                    return qsTr("Extend");
                }
                return "";
            }
        }

        StyledText {
            id: tileLabel
            property real smallScale: Tokens.font.size.small / Tokens.font.size.large
            textPointSize: Tokens.font.size.large
            transformOrigin: Item.TopLeft
            font.bold: true
            color: Colours.palette.m3onSurface
            text: {
                if (root.lastActiveType === "network") return qsTr("Wi-Fi");
                if (root.lastActiveType === "bluetooth") return qsTr("Bluetooth");
                if (root.lastActiveType === "powerprofile") return qsTr("Power Profile");
                if (root.lastActiveType === "displayprojection") return qsTr("Display Projection");
                return "";
            }
        }

        StyledText {
            id: tileStateLabel
            text: {
                if (root.lastActiveType === "network") return Nmcli.wifiEnabled ? qsTr("On") : qsTr("Off");
                if (root.lastActiveType === "bluetooth") return root.btEnabled ? qsTr("On") : qsTr("Off");
                if (root.lastActiveType === "powerprofile") return PowerProfile.toString(PowerProfiles.profile);
                if (root.lastActiveType === "displayprojection") {
                    const mode = DisplayProjection.activeProjection;
                    if (mode === "primary") return qsTr("Primary");
                    if (mode === "secondary") return qsTr("Secondary");
                    if (mode === "mirror") return qsTr("Mirror");
                    return qsTr("Expand");
                }
                return "";
            }
            textPointSize: Tokens.font.size.small - 2
            color: Colours.palette.m3onSurfaceVariant
        }

        // ── Expanded content ─────────────────────────────────────────────────
        ColumnLayout {
            id: expandedContent
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 0
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.large
            anchors.bottomMargin: Tokens.padding.large
            spacing: 0
            opacity: 0
            visible: opacity > 0


            Loader {
                id: contentLoader
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                focus: true
                
                sourceComponent: {
                    if (root.lastActiveType === "network") {
                        if (dummyPopoutState.currentName === "wirelesspassword") {
                            return wirelessPasswordComp;
                        }
                        return networkComp;
                    }
                    if (root.lastActiveType === "bluetooth") return bluetoothComp;
                    if (root.lastActiveType === "powerprofile") return powerProfileComp;
                    if (root.lastActiveType === "displayprojection") return displayProjectionComp;
                    return null;
                }
                active: root._overlayVisible

                onLoaded: {
                    Qt.callLater(() => {
                        if (item) item.forceActiveFocus();
                    });
                }
            }
        }
    }

    Component { 
        id: networkComp; 
        Popouts.Network { 
            popouts: dummyPopoutState
            onPasswordNetworkChanged: {
                if (passwordNetwork) {
                    if (Nmcli.active && Nmcli.active.ssid) {
                        NetworkConnection.previousSsid = Nmcli.active.ssid;
                    }
                    root.passwordNetwork = passwordNetwork;
                    dummyPopoutState.currentName = "wirelesspassword";
                }
            }
        } 
    }
    Component { 
        id: wirelessPasswordComp; 
        Popouts.WirelessPassword { 
            popouts: dummyPopoutState
            network: root.passwordNetwork
        } 
    }
    Component { id: bluetoothComp; Popouts.Bluetooth { popouts: dummyPopoutState } }
    Component {
        id: powerProfileComp
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                Layout.bottomMargin: Tokens.spacing.small
                Layout.rightMargin: Tokens.padding.small
                text: qsTr("Select power mode:")
                color: Colours.palette.m3onSurfaceVariant
                textPointSize: Tokens.font.size.small
            }

            PowerProfileItem {
                profile: PowerProfile.PowerSaver
                icon: "energy_savings_leaf"
                title: qsTr("Power Saver")
                description: qsTr("Reduces performance to save battery life.")
            }

            PowerProfileItem {
                profile: PowerProfile.Balanced
                icon: "balance"
                title: qsTr("Balanced")
                description: qsTr("Standard performance and power usage.")
            }

            PowerProfileItem {
                profile: PowerProfile.Performance
                icon: "rocket_launch"
                title: qsTr("Performance")
                description: qsTr("Maximizes system speed and responsiveness.")
            }
        }
    }

    component PowerProfileItem: StyledRect {
        id: itemRoot
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: Tokens.rounding.large

        required property int profile
        required property string icon
        required property string title
        required property string description

        readonly property bool isActive: PowerProfiles.profile === profile

        color: isActive ? Colours.palette.m3primary : Colours.tileFill
        border.width: 0
        border.color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.normal
            anchors.rightMargin: Tokens.padding.normal
            spacing: Tokens.spacing.normal

            MaterialIcon {
                text: itemRoot.icon
                color: itemRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                iconPointSize: Tokens.font.size.large
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                StyledText {
                    text: itemRoot.title
                    font.weight: itemRoot.isActive ? 600 : 400
                    color: itemRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.small
                    Layout.fillWidth: true
                }

                MarqueeText {
                    text: itemRoot.description
                    color: itemRoot.isActive ? Qt.alpha(Colours.palette.m3onPrimary, 0.8) : Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.smaller
                }
            }

            MaterialIcon {
                visible: itemRoot.isActive
                text: "check_circle"
                color: Colours.palette.m3onPrimary
                iconPointSize: Tokens.font.size.normal
                Layout.alignment: Qt.AlignVCenter
            }
        }

        StateLayer {
            anchors.fill: parent
            color: itemRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: PowerProfiles.profile = itemRoot.profile
        }
    }

    Component {
        id: displayProjectionComp
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            DisplayProjectionItem {
                mode: "primary"
                icon: "laptop"
                title: qsTr("PC screen only")
                description: qsTr("Turn off external displays, use built-in screen.")
            }

            DisplayProjectionItem {
                mode: "mirror"
                icon: "sync"
                title: qsTr("Duplicate")
                description: qsTr("Duplicate your screen onto external display.")
            }

            DisplayProjectionItem {
                mode: "expand"
                icon: "splitscreen"
                title: qsTr("Extend")
                description: qsTr("Extend your desktop across both screens.")
            }

            DisplayProjectionItem {
                mode: "secondary"
                icon: "tv"
                title: qsTr("Second screen only")
                description: qsTr("Turn off built-in display, use external screen.")
            }
        }
    }

    component DisplayProjectionItem: StyledRect {
        id: projItemRoot
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: Tokens.rounding.large

        required property string mode
        required property string icon
        required property string title
        required property string description

        readonly property bool isActive: DisplayProjection.activeProjection === mode

        color: isActive ? Colours.palette.m3primary : Colours.tileFill
        border.width: 0
        border.color: "transparent"

        scale: projMa.pressed ? 0.98 : 1.0
        Behavior on scale {
            SpringAnimation {
                spring: 5.0
                damping: 0.70
            }
        }

        Behavior on color { CAnim {} }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.normal
            anchors.rightMargin: Tokens.padding.normal
            spacing: Tokens.spacing.normal

            MaterialIcon {
                text: projItemRoot.icon
                color: projItemRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                iconPointSize: Tokens.font.size.large
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                StyledText {
                    text: projItemRoot.title
                    font.weight: projItemRoot.isActive ? 600 : 400
                    color: projItemRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.small
                    Layout.fillWidth: true
                }

                MarqueeText {
                    text: projItemRoot.description
                    color: projItemRoot.isActive ? Qt.alpha(Colours.palette.m3onPrimary, 0.8) : Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.smaller
                }
            }

            MaterialIcon {
                visible: projItemRoot.isActive
                text: "check_circle"
                color: Colours.palette.m3onPrimary
                iconPointSize: Tokens.font.size.normal
                Layout.alignment: Qt.AlignVCenter
            }
        }

        StateLayer {
            id: projMa
            anchors.fill: parent
            color: projItemRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            preventStealing: false
            onClicked: DisplayProjection.applyProjection(projItemRoot.mode)
        }
    }

    Popouts.PopoutState { 
        id: dummyPopoutState
        onCurrentNameChanged: {
            if (currentName === "network") {
                root.passwordNetwork = null;
                Nmcli.connectionCheckTimer.stop();
                Nmcli.immediateCheckTimer.stop();
                Nmcli.pendingConnection = null;
            }
        }
    }

    component MarqueeText: Item {
        id: marqueeContainer
        required property string text
        property alias color: labelText.color
        property alias font: labelText.font
        property alias textPointSize: labelText.textPointSize
        property alias verticalAlignment: labelText.verticalAlignment
        
        Layout.fillWidth: true
        Layout.preferredHeight: labelText.implicitHeight
        clip: true

        readonly property bool needsMarquee: labelText.implicitWidth > width
        readonly property real speed: 30 // pixels per second

        layer.enabled: needsMarquee
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: ShaderEffectSource {
                sourceItem: Rectangle {
                    width: marqueeContainer.width
                    height: marqueeContainer.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.1; color: "black" }
                        GradientStop { position: 0.9; color: "black" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }
        }

        Row {
            id: marqueeRow
            spacing: 40
            property real marqueeX: 0
            height: parent.height

            StyledText {
                id: labelText
                text: marqueeContainer.text
                height: parent.height
            }

            StyledText {
                text: marqueeContainer.text
                textPointSize: labelText.textPointSize
                color: labelText.color
                visible: marqueeContainer.needsMarquee
                height: parent.height
            }

            SequentialAnimation {
                id: marqueeAnim
                running: marqueeContainer.needsMarquee && root.active
                loops: Animation.Infinite

                PauseAnimation { duration: 2500 }

                NumberAnimation {
                    target: marqueeRow
                    property: "marqueeX"
                    from: 0
                    to: -(labelText.implicitWidth + 40)
                    duration: Math.max(3000, (labelText.implicitWidth) * 1000 / marqueeContainer.speed)
                    easing.type: Easing.InOutQuad
                }

                PauseAnimation { duration: 1500 }

                PropertyAnimation { target: marqueeRow; property: "opacity"; to: 0; duration: 400 }
                PropertyAction { target: marqueeRow; property: "marqueeX"; value: 0 }
                PropertyAnimation { target: marqueeRow; property: "opacity"; to: 1; duration: 400 }
            }
        }

        states: [
            State {
                name: "static"
                when: !marqueeContainer.needsMarquee
                PropertyChanges { target: marqueeRow; marqueeX: 0; x: 0 }
            },
            State {
                name: "animating"
                when: marqueeContainer.needsMarquee
                PropertyChanges { target: marqueeRow; x: marqueeRow.marqueeX }
            }
        ]
    }
}