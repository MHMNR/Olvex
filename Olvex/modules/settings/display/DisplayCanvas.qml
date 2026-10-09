import "."
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Olvex.Config
import qs.services

StyledClippingRect {
    id: root

    required property var monitors
    required property int selectedIndex
    required property var draftWorkspaces

    property bool isFullscreen: false

    signal selectMonitor(int index)
    signal monitorsUpdated(var newMonitors)
    signal autoAlignRequested(string alignment)
    signal toggleFullscreenRequested(bool isFullscreen)

    // Token fallbacks
    readonly property int rLarge: (Tokens.rounding && typeof Tokens.rounding.large !== "undefined") ? Tokens.rounding.large : 16
    readonly property int rMed: (Tokens.rounding && typeof Tokens.rounding.normal !== "undefined") ? Tokens.rounding.normal : 12
    readonly property int rSmall: (Tokens.rounding && typeof Tokens.rounding.small !== "undefined") ? Tokens.rounding.small : 8
    readonly property int rFull: (Tokens.rounding && typeof Tokens.rounding.full !== "undefined") ? Tokens.rounding.full : 999
    readonly property int padNormal: (Tokens.padding && typeof Tokens.padding.normal !== "undefined") ? Tokens.padding.normal : 16
    readonly property int padSmall: (Tokens.padding && typeof Tokens.padding.small !== "undefined") ? Tokens.padding.small : 8
    readonly property int fNormal: (Tokens.font && typeof Tokens.font.size.normal !== "undefined") ? Tokens.font.size.normal : 14
    readonly property int fSmall: (Tokens.font && typeof Tokens.font.size.small !== "undefined") ? Tokens.font.size.small : 12
    readonly property int fSmaller: (Tokens.font && typeof Tokens.font.size.smaller !== "undefined") ? Tokens.font.size.smaller : 11

    color: Colours.palette.m3surfaceContainerLowest
    radius: root.rLarge
    clip: true

    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.3)

    // ── Zoom & Canvas Coordinates ───────────────────────────────────────────
    property real viewScale: 0.10

    Behavior on viewScale { Anim { type: Anim.Emphasized } }

    // Direct mapping from model coordinates to full canvas pixel space
    function getMonitorCanvasX(idx) {
        const pad = root.padSmall || 8;
        if (!monitors || idx < 0 || idx >= monitors.length) return pad;
        const m = monitors[idx];
        const mx = (m && typeof m.x === "number" && !isNaN(m.x)) ? m.x : 0;
        const mw = (m && (m.logicalWidth || m.width)) ? Math.max(48, Math.round((m.logicalWidth || m.width) * root.viewScale)) : 48;
        const maxX = Math.max(pad, root.width - mw - pad);
        return Math.min(maxX, Math.max(pad, Math.round(pad + (mx * root.viewScale))));
    }

    function getMonitorCanvasY(idx) {
        const pad = root.padSmall || 8;
        if (!monitors || idx < 0 || idx >= monitors.length) return pad;
        const m = monitors[idx];
        const my = (m && typeof m.y === "number" && !isNaN(m.y)) ? m.y : 0;
        const mh = (m && (m.logicalHeight || m.height)) ? Math.max(32, Math.round((m.logicalHeight || m.height) * root.viewScale)) : 32;
        const maxY = Math.max(pad, root.height - mh - pad);
        return Math.min(maxY, Math.max(pad, Math.round(pad + (my * root.viewScale))));
    }

    // Compute scale so all connected displays comfortably fit inside the canvas
    function fitToView() {
        if (!monitors || monitors.length === 0) return;
        if (root.width <= 100 || root.height <= 80) return;

        let maxX = 0, maxY = 0;
        for (let i = 0; i < monitors.length; i++) {
            const m = monitors[i];
            if (!m) continue;
            const mx = (typeof m.x === "number" && !isNaN(m.x)) ? Math.max(0, m.x) : 0;
            const my = (typeof m.y === "number" && !isNaN(m.y)) ? Math.max(0, m.y) : 0;
            const mw = (typeof m.logicalWidth === "number" && m.logicalWidth > 0) ? m.logicalWidth : ((m && m.width) ? m.width : 1920);
            const mh = (typeof m.logicalHeight === "number" && m.logicalHeight > 0) ? m.logicalHeight : ((m && m.height) ? m.height : 1080);

            if (mx + mw > maxX) maxX = mx + mw;
            if (my + mh > maxY) maxY = my + mh;
        }

        const totalW = Math.max(1920, maxX);
        const totalH = Math.max(1080, maxY);

        const pad = root.padSmall || 8;
        const availW = Math.max(100, root.width - pad * 2);
        const availH = Math.max(80, root.height - pad * 2);

        const scaleW = availW / totalW;
        const scaleH = availH / totalH;
        const fitted = Math.min(0.20, Math.max(0.04, Math.min(scaleW, scaleH)));

        if (!isNaN(fitted) && fitted > 0) {
            root.viewScale = fitted;
        }
    }

    // Zoom adjusts the display element scale
    function zoomAt(factor) {
        const oldScale = root.viewScale;
        const newScale = Math.min(0.25, Math.max(0.03, oldScale * factor));
        if (Math.abs(newScale - oldScale) < 0.0001) return;

        root.viewScale = newScale;
    }

    Component.onCompleted: {
        Qt.callLater(root.fitToView);
    }

    onWidthChanged: Qt.callLater(root.fitToView)
    onHeightChanged: Qt.callLater(root.fitToView)
    onIsFullscreenChanged: Qt.callLater(root.fitToView)

    // ── Static Clean Canvas Grid ────────────────────────────────────────────
    Canvas {
        id: gridBg
        anchors.fill: parent
        opacity: 0.45
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.save();
            ctx.beginPath();
            if (typeof ctx.roundedRect === "function") {
                ctx.roundedRect(0, 0, width, height, root.rLarge, root.rLarge);
                ctx.clip();
            }
            ctx.strokeStyle = Colours.palette.m3outlineVariant;
            ctx.lineWidth = 1;
            const step = 28;
            for (let x = 0; x < width; x += step) {
                ctx.beginPath();
                ctx.moveTo(x, 0);
                ctx.lineTo(x, height);
                ctx.stroke();
            }
            for (let y = 0; y < height; y += step) {
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
                ctx.stroke();
            }
            ctx.restore();
        }

        Connections {
            target: Colours
            function onPaletteChanged() { gridBg.requestPaint(); }
        }
    }

    // ── Canvas Wheel Area for Zoom ──────────────────────────────────────────
    MouseArea {
        id: canvasPanArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        onWheel: (wheel) => {
            const factor = wheel.angleDelta.y > 0 ? 1.12 : 0.88;
            root.zoomAt(factor);
        }

        // ── Stage Container ─────────────────────────────────────────────────
        Item {
            id: stage
            anchors.fill: parent

            // Render connected monitors
            Repeater {
                model: root.monitors

                delegate: Item {
                    id: delegateRoot
                    required property var modelData
                    required property int index

                    readonly property bool isMultipleMonitors: root.monitors && root.monitors.length > 1
                    readonly property bool isSelected: root.selectedIndex === index
                    readonly property bool isPrimary: !!(delegateRoot.modelData && delegateRoot.modelData.isPrimary)
                    readonly property int itemW: Math.max(48, Math.round(((modelData && modelData.logicalWidth) || (modelData && modelData.width) || 1920) * root.viewScale))
                    readonly property int itemH: Math.max(32, Math.round(((modelData && modelData.logicalHeight) || (modelData && modelData.height) || 1080) * root.viewScale))

                    readonly property real targetCanvasX: root.getMonitorCanvasX(delegateRoot.index)
                    readonly property real targetCanvasY: root.getMonitorCanvasY(delegateRoot.index)

                    property bool isDragging: false
                    property real dragScreenX: targetCanvasX
                    property real dragScreenY: targetCanvasY

                    onTargetCanvasXChanged: {
                        if (!isDragging) dragScreenX = targetCanvasX;
                    }
                    onTargetCanvasYChanged: {
                        if (!isDragging) dragScreenY = targetCanvasY;
                    }

                    // Visual Monitor Card
                    Item {
                        id: monitorVisual
                        x: Math.round(delegateRoot.isDragging ? delegateRoot.dragScreenX : delegateRoot.targetCanvasX)
                        y: Math.round(delegateRoot.isDragging ? delegateRoot.dragScreenY : delegateRoot.targetCanvasY)
                        width: delegateRoot.itemW
                        height: delegateRoot.itemH
                        z: delegateRoot.isDragging ? 150 : (delegateRoot.isSelected ? 10 : 1)
                        scale: delegateRoot.isDragging ? 1.03 : 1.0

                        Behavior on scale {
                            Anim {
                                type: Anim.Emphasized
                                duration: Tokens.anim ? Tokens.anim.durations.small : 150
                            }
                        }

                        StyledRect {
                            id: cardBody
                            anchors.fill: parent
                            radius: Math.min(root.rMed, Math.max(4, Math.round(delegateRoot.itemH * 0.15)))
                            color: delegateRoot.modelData.disabled
                                   ? Colours.palette.m3surfaceContainerLowest
                                   : (delegateRoot.isSelected ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh)

                            border.width: delegateRoot.isSelected ? 2 : (delegateRoot.isDragging ? 2 : 1)
                            border.color: delegateRoot.isDragging
                                          ? Colours.palette.m3primary
                                          : (delegateRoot.isSelected ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.4))

                            Behavior on border.color { CAnim {} }
                            Behavior on color { CAnim {} }

                            // Monitor inner screen container
                            Rectangle {
                                id: cardInner
                                anchors.fill: parent
                                anchors.margins: Math.round(Math.max(2, Math.min(6, delegateRoot.itemH * 0.06)))
                                radius: Math.max(2, Math.round(cardBody.radius - 2))
                                color: delegateRoot.modelData.disabled
                                       ? Qt.alpha(Colours.palette.m3surfaceDim, 0.8)
                                       : Qt.alpha(Colours.palette.m3surface, 0.7)
                                clip: true

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width - 4, implicitWidth)
                                    spacing: 1

                                    // Monitor Port Name & Icon (Always visible)
                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.maximumWidth: cardInner.width - 4
                                        spacing: 3

                                        MaterialIcon {
                                            visible: delegateRoot.isPrimary && !delegateRoot.modelData.disabled
                                            text: "star"
                                            fill: 1
                                            color: Colours.palette.m3primary
                                            iconPointSize: delegateRoot.itemH >= 55 ? root.fSmall : root.fSmaller
                                        }

                                        MaterialIcon {
                                            text: (delegateRoot.modelData && delegateRoot.modelData.name && delegateRoot.modelData.name.startsWith("eDP")) ? "laptop" : "desktop_windows"
                                            fill: 1
                                            color: delegateRoot.isSelected ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                            iconPointSize: delegateRoot.itemH >= 55 ? root.fNormal : root.fSmall
                                        }

                                        StyledText {
                                            text: delegateRoot.modelData ? delegateRoot.modelData.name : ""
                                            font.weight: Font.Bold
                                            color: delegateRoot.isSelected ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                            textPointSize: delegateRoot.itemH >= 55 ? root.fSmall : root.fSmaller
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: cardInner.width - (delegateRoot.isPrimary ? 36 : 22)
                                        }
                                    }

                                    // Mode / Refresh Rate badge
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.maximumWidth: cardInner.width - 6
                                        elide: Text.ElideRight
                                        visible: delegateRoot.itemH >= 60 && delegateRoot.itemW >= 125
                                        text: delegateRoot.modelData ? `${delegateRoot.modelData.width}x${delegateRoot.modelData.height} @ ${Math.round(delegateRoot.modelData.refreshRate)}Hz` : ""
                                        color: Colours.palette.m3onSurfaceVariant
                                        textPointSize: root.fSmaller - 2
                                        font.weight: Font.Medium
                                    }

                                    // Scale & Position badge
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.maximumWidth: cardInner.width - 6
                                        elide: Text.ElideRight
                                        visible: delegateRoot.itemH >= 70 && delegateRoot.itemW >= 120
                                        text: {
                                            const posX = delegateRoot.isDragging ? dragArea.currentTargetModelX : ((delegateRoot.modelData && typeof delegateRoot.modelData.x === "number") ? delegateRoot.modelData.x : 0);
                                            const posY = delegateRoot.isDragging ? dragArea.currentTargetModelY : ((delegateRoot.modelData && typeof delegateRoot.modelData.y === "number") ? delegateRoot.modelData.y : 0);
                                            return delegateRoot.modelData ? `${(delegateRoot.modelData.scale || 1.0).toFixed(2)}x · (${Math.round(posX)}, ${Math.round(posY)})` : "";
                                        }
                                        color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.8)
                                        textPointSize: root.fSmaller - 3
                                        font.weight: Font.Normal
                                    }
                                }
                            }

                            // Disabled overlay badge
                            StyledRect {
                                visible: delegateRoot.modelData.disabled
                                anchors.centerIn: parent
                                implicitWidth: 70
                                implicitHeight: 22
                                radius: root.rSmall
                                color: Qt.alpha(Colours.palette.m3errorContainer, 0.9)

                                StyledText {
                                    anchors.centerIn: parent
                                    text: qsTr("Disabled")
                                    color: Colours.palette.m3onErrorContainer
                                    textPointSize: root.fSmaller - 2
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        // Direct Smooth Drag & Click Area across entire canvas
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                            property real startMouseRootX: 0
                            property real startMouseRootY: 0
                            property real startCanvasX: 0
                            property real startCanvasY: 0
                            property real currentTargetModelX: 0
                            property real currentTargetModelY: 0

                            onPressed: (mouse) => {
                                root.selectMonitor(delegateRoot.index);

                                startCanvasX = monitorVisual.x;
                                startCanvasY = monitorVisual.y;
                                currentTargetModelX = (delegateRoot.modelData && typeof delegateRoot.modelData.x === "number") ? delegateRoot.modelData.x : 0;
                                currentTargetModelY = (delegateRoot.modelData && typeof delegateRoot.modelData.y === "number") ? delegateRoot.modelData.y : 0;

                                const pt = mapToItem(root, mouse.x, mouse.y);
                                startMouseRootX = pt.x;
                                startMouseRootY = pt.y;

                                delegateRoot.dragScreenX = startCanvasX;
                                delegateRoot.dragScreenY = startCanvasY;
                                delegateRoot.isDragging = true;
                            }

                            onPositionChanged: (mouse) => {
                                if (!pressed || !delegateRoot.isDragging) return;

                                const pt = mapToItem(root, mouse.x, mouse.y);
                                const deltaX = pt.x - startMouseRootX;
                                const deltaY = pt.y - startMouseRootY;

                                let newCanvasX = startCanvasX + deltaX;
                                let newCanvasY = startCanvasY + deltaY;

                                // STRICT FULL CANVAS BOUNDS CLAMPING: Card can move to the very bottom and top without clipping
                                const pad = root.padSmall || 8;
                                const minX = pad;
                                const minY = pad;
                                const maxX = Math.max(minX, root.width - delegateRoot.itemW - pad);
                                const maxY = Math.max(minY, root.height - delegateRoot.itemH - pad);

                                newCanvasX = Math.min(maxX, Math.max(minX, newCanvasX));
                                newCanvasY = Math.min(maxY, Math.max(minY, newCanvasY));

                                // Magnetic edge snapping in canvas pixel space if multi-monitor
                                if (root.monitors && root.monitors.length > 1) {
                                    const snapDist = 20;
                                    let bestX = newCanvasX;
                                    let bestY = newCanvasY;
                                    let minDx = snapDist;
                                    let minDy = snapDist;

                                    for (let j = 0; j < root.monitors.length; j++) {
                                        if (j === delegateRoot.index) continue;
                                        const other = root.monitors[j];
                                        if (!other) continue;
                                        const otherX = root.getMonitorCanvasX(j);
                                        const otherY = root.getMonitorCanvasY(j);
                                        const otherW = Math.max(48, Math.round(((other.logicalWidth || other.width || 1920)) * root.viewScale));
                                        const otherH = Math.max(32, Math.round(((other.logicalHeight || other.height || 1080)) * root.viewScale));

                                        // X Snapping
                                        if (Math.abs(newCanvasX - (otherX + otherW)) < minDx) { minDx = Math.abs(newCanvasX - (otherX + otherW)); bestX = otherX + otherW; }
                                        if (Math.abs((newCanvasX + delegateRoot.itemW) - otherX) < minDx) { minDx = Math.abs((newCanvasX + delegateRoot.itemW) - otherX); bestX = otherX - delegateRoot.itemW; }
                                        if (Math.abs(newCanvasX - otherX) < minDx) { minDx = Math.abs(newCanvasX - otherX); bestX = otherX; }
                                        if (Math.abs((newCanvasX + delegateRoot.itemW) - (otherX + otherW)) < minDx) { minDx = Math.abs((newCanvasX + delegateRoot.itemW) - (otherX + otherW)); bestX = otherX + otherW - delegateRoot.itemW; }

                                        // Y Snapping
                                        if (Math.abs(newCanvasY - (otherY + otherH)) < minDy) { minDy = Math.abs(newCanvasY - (otherY + otherH)); bestY = otherY + otherH; }
                                        if (Math.abs((newCanvasY + delegateRoot.itemH) - otherY) < minDy) { minDy = Math.abs((newCanvasY + delegateRoot.itemH) - otherY); bestY = otherY - delegateRoot.itemH; }
                                        if (Math.abs(newCanvasY - otherY) < minDy) { minDy = Math.abs(newCanvasY - otherY); bestY = otherY; }
                                        if (Math.abs((newCanvasY + delegateRoot.itemH) - (otherY + otherH)) < minDy) { minDy = Math.abs((newCanvasY + delegateRoot.itemH) - (otherY + otherH)); bestY = otherY + otherH - delegateRoot.itemH; }
                                    }

                                    newCanvasX = Math.min(maxX, Math.max(minX, bestX));
                                    newCanvasY = Math.min(maxY, Math.max(minY, bestY));
                                }

                                const scale = Math.max(0.01, root.viewScale);
                                currentTargetModelX = Math.max(0, Math.round((newCanvasX - pad) / scale));
                                currentTargetModelY = Math.max(0, Math.round((newCanvasY - pad) / scale));

                                delegateRoot.dragScreenX = newCanvasX;
                                delegateRoot.dragScreenY = newCanvasY;
                            }

                            onReleased: {
                                if (delegateRoot.isDragging) {
                                    delegateRoot.isDragging = false;

                                    let newMonitors = JSON.parse(JSON.stringify(root.monitors));
                                    newMonitors[delegateRoot.index].x = currentTargetModelX;
                                    newMonitors[delegateRoot.index].y = currentTargetModelY;

                                    root.monitorsUpdated(newMonitors);
                                }
                            }

                            onCanceled: {
                                delegateRoot.isDragging = false;
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Floating Action Bar inside Canvas (Zoom, Fit, Identify, Align) ─────────────
    StyledRect {
        id: zoomHud
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: root.padSmall || 8
        implicitWidth: hudLayout.implicitWidth + (Tokens.padding ? Tokens.padding.normal * 2 : 24)
        implicitHeight: 40
        radius: root.rFull
        color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.95)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.5)
        z: 100

        RowLayout {
            id: hudLayout
            anchors.centerIn: parent
            spacing: Tokens.spacing ? Tokens.spacing.small : 8

            // Identify button
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 30
                implicitHeight: 30
                type: IconButton.Tonal
                icon: "visibility"
                iconPointSize: root.fSmall
                onClicked: DisplayManager.identifyDisplays()
            }

            // Multi-monitor Quick Align Helpers
            RowLayout {
                visible: root.monitors && root.monitors.length > 1
                spacing: Tokens.spacing ? Tokens.spacing.small : 8

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 18
                    color: Colours.palette.m3outlineVariant
                }

                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 30
                    implicitHeight: 30
                    type: IconButton.Text
                    icon: "align_horizontal_left"
                    iconPointSize: root.fSmall
                    onClicked: root.autoAlignRequested("horizontal")
                }

                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 30
                    implicitHeight: 30
                    type: IconButton.Text
                    icon: "align_vertical_top"
                    iconPointSize: root.fSmall
                    onClicked: root.autoAlignRequested("vertical")
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: Colours.palette.m3outlineVariant
            }

            // Zoom Stepper (Olvex CustomSpinBox)
            CustomSpinBox {
                Layout.alignment: Qt.AlignVCenter
                min: 20
                max: 250
                step: 10
                value: Math.round(root.viewScale * 1000)
                onValueModified: (v) => {
                    root.viewScale = Math.min(0.25, Math.max(0.02, v / 1000));
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: Colours.palette.m3outlineVariant
            }

            // Fit to View
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 30
                implicitHeight: 30
                type: IconButton.Text
                icon: "fit_screen"
                iconPointSize: root.fSmall
                onClicked: root.fitToView()
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: Colours.palette.m3outlineVariant
            }

            // Fullscreen Toggle
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 30
                implicitHeight: 30
                type: root.isFullscreen ? IconButton.Tonal : IconButton.Text
                icon: root.isFullscreen ? "fullscreen_exit" : "fullscreen"
                iconPointSize: root.fSmall
                onClicked: {
                    root.isFullscreen = !root.isFullscreen;
                    root.toggleFullscreenRequested(root.isFullscreen);
                    Qt.callLater(root.fitToView);
                }
            }
        }
    }
}
