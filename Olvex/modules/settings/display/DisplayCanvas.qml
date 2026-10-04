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
    readonly property int padNormal: (Tokens.padding && typeof Tokens.padding.normal !== "undefined") ? Tokens.padding.normal : 12
    readonly property int padSmall: (Tokens.padding && typeof Tokens.padding.small !== "undefined") ? Tokens.padding.small : 8
    readonly property int fNormal: (Tokens.font && typeof Tokens.font.size.normal !== "undefined") ? Tokens.font.size.normal : 14
    readonly property int fSmall: (Tokens.font && typeof Tokens.font.size.small !== "undefined") ? Tokens.font.size.small : 12
    readonly property int fSmaller: (Tokens.font && typeof Tokens.font.size.smaller !== "undefined") ? Tokens.font.size.smaller : 11

    color: Colours.palette.m3surfaceContainerLowest
    radius: root.rLarge
    clip: true

    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.3)

    // ── Zoom & Pan (Fixed Canvas top-left origin) ───────────────────────────
    property real viewScale: 0.10
    property real panX: root.padNormal
    property real panY: root.padNormal

    Behavior on viewScale {
        Anim {
            type: Anim.Emphasized
        }
    }

    // Helper functions for monitor canvas coordinates
    function getMonitorCanvasX(idx) {
        if (!monitors || idx < 0 || idx >= monitors.length) return Math.round(root.panX);
        const m = monitors[idx];
        const mx = (m && typeof m.x === "number") ? m.x : 0;
        return Math.round(root.panX + (mx * root.viewScale));
    }

    function getMonitorCanvasY(idx) {
        if (!monitors || idx < 0 || idx >= monitors.length) return Math.round(root.panY);
        const m = monitors[idx];
        const my = (m && typeof m.y === "number") ? m.y : 0;
        return Math.round(root.panY + (my * root.viewScale));
    }

    // Compute scale so all connected displays comfortably fit in the canvas
    function fitToView() {
        if (!monitors || monitors.length === 0) return;
        if (root.width <= 100 || root.height <= 80) return;

        let maxX = 0, maxY = 0;
        for (let i = 0; i < monitors.length; i++) {
            const m = monitors[i];
            const mx = (m && typeof m.x === "number" && !isNaN(m.x)) ? Math.max(0, m.x) : 0;
            const my = (m && typeof m.y === "number" && !isNaN(m.y)) ? Math.max(0, m.y) : 0;
            const mw = (m && typeof m.logicalWidth === "number" && m.logicalWidth > 0) ? m.logicalWidth : ((m && m.width) ? m.width : 1920);
            const mh = (m && typeof m.logicalHeight === "number" && m.logicalHeight > 0) ? m.logicalHeight : ((m && m.height) ? m.height : 1080);
            
            if (mx + mw > maxX) maxX = mx + mw;
            if (my + mh > maxY) maxY = my + mh;
        }
        
        const totalW = Math.max(1920, maxX);
        const totalH = Math.max(1080, maxY);
        
        const pad = (root.padNormal || 12) * 2 + 64;
        const availW = Math.max(100, root.width - pad);
        const availH = Math.max(80, root.height - pad);

        const scaleW = availW / totalW;
        const scaleH = availH / totalH;
        const fitted = Math.min(0.25, Math.max(0.04, Math.min(scaleW, scaleH)));

        if (!isNaN(fitted) && fitted > 0) {
            root.viewScale = fitted;
        }
        root.panX = root.padNormal;
        root.panY = root.padNormal;
    }

    // Zoom adjusts the display element scale from top-left origin
    function zoomAt(factor) {
        const oldScale = root.viewScale;
        const newScale = Math.min(0.25, Math.max(0.04, oldScale * factor));
        if (Math.abs(newScale - oldScale) < 0.0001) return;
        
        root.viewScale = newScale;
    }

    Component.onCompleted: {
        root.panX = root.padNormal;
        root.panY = root.padNormal;
        Qt.callLater(root.fitToView);
    }

    onWidthChanged: Qt.callLater(root.fitToView)
    onHeightChanged: Qt.callLater(root.fitToView)
    onIsFullscreenChanged: Qt.callLater(root.fitToView)

    // ── Static Clean Canvas Grid (Fixed background) ─────────────────────────
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

    // ── Mouse Area for Canvas Pan and Zoom ──────────────────────────────────
    MouseArea {
        id: canvasPanArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton // Disable clicking/panning on background
        
        onWheel: (wheel) => {
            const factor = wheel.angleDelta.y > 0 ? 1.12 : 0.88;
            root.zoomAt(factor, wheel.x, wheel.y);
        }

        // ── Stage Container (Panned & Scaled) ───────────────────────────────────
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

                    readonly property bool isSelected: root.selectedIndex === index
                    readonly property bool isPrimary: (delegateRoot.modelData && delegateRoot.modelData.x === 0 && delegateRoot.modelData.y === 0)
                    readonly property int itemW: Math.max(40, Math.round(((modelData && modelData.logicalWidth) || (modelData && modelData.width) || 1920) * root.viewScale))
                    readonly property int itemH: Math.max(25, Math.round(((modelData && modelData.logicalHeight) || (modelData && modelData.height) || 1080) * root.viewScale))

                    readonly property real targetCanvasX: Math.round(root.panX + (((delegateRoot.modelData && typeof delegateRoot.modelData.x === "number" && !isNaN(delegateRoot.modelData.x)) ? Math.max(0, delegateRoot.modelData.x) : 0) * root.viewScale))
                    readonly property real targetCanvasY: Math.round(root.panY + (((delegateRoot.modelData && typeof delegateRoot.modelData.y === "number" && !isNaN(delegateRoot.modelData.y)) ? Math.max(0, delegateRoot.modelData.y) : 0) * root.viewScale))

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
                        z: delegateRoot.isDragging ? 100 : (delegateRoot.isSelected ? 10 : 1)

                        StyledRect {
                            id: cardBody
                            anchors.fill: parent
                            radius: Math.min(root.rMed, Math.max(4, Math.round(delegateRoot.itemH * 0.15)))
                            color: delegateRoot.modelData.disabled
                                   ? Colours.palette.m3surfaceContainerLowest
                                   : (delegateRoot.isSelected ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh)

                            border.width: delegateRoot.isSelected ? 2 : 1
                            border.color: delegateRoot.isSelected ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.4)

                            Behavior on border.color { CAnim {} }

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
                                        visible: delegateRoot.itemH >= 75 && delegateRoot.itemW >= 135
                                        text: delegateRoot.modelData ? `${(delegateRoot.modelData.scale || 1.0).toFixed(2)}x · (${Math.round(delegateRoot.modelData.x || 0)}, ${Math.round(delegateRoot.modelData.y || 0)})` : ""
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

                        // Direct Smooth Drag & Click Area
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                            property real startMouseStageX: 0
                            property real startMouseStageY: 0
                            property real startModelX: 0
                            property real startModelY: 0
                            property real currentDragModelX: 0
                            property real currentDragModelY: 0

                            onPressed: (mouse) => {
                                root.selectMonitor(delegateRoot.index);
                                
                                startModelX = (delegateRoot.modelData && typeof delegateRoot.modelData.x === "number" && !isNaN(delegateRoot.modelData.x)) ? Math.max(0, delegateRoot.modelData.x) : 0;
                                startModelY = (delegateRoot.modelData && typeof delegateRoot.modelData.y === "number" && !isNaN(delegateRoot.modelData.y)) ? Math.max(0, delegateRoot.modelData.y) : 0;
                                currentDragModelX = startModelX;
                                currentDragModelY = startModelY;

                                delegateRoot.dragScreenX = delegateRoot.targetCanvasX;
                                delegateRoot.dragScreenY = delegateRoot.targetCanvasY;

                                const pt = mapToItem(stage, mouse.x, mouse.y);
                                startMouseStageX = pt.x;
                                startMouseStageY = pt.y;
                                delegateRoot.isDragging = true;
                            }

                            onPositionChanged: (mouse) => {
                                if (!pressed || !delegateRoot.isDragging) return;

                                const pt = mapToItem(stage, mouse.x, mouse.y);
                                const deltaCanvasX = pt.x - startMouseStageX;
                                const deltaCanvasY = pt.y - startMouseStageY;

                                const scale = Math.max(0.01, root.viewScale);
                                let targetModelX = startModelX + (deltaCanvasX / scale);
                                let targetModelY = startModelY + (deltaCanvasY / scale);

                                targetModelX = Math.max(0, targetModelX);
                                targetModelY = Math.max(0, targetModelY);

                                // Snapping in model units
                                const snapModelThresh = Math.round(18 / scale);

                                if (targetModelX < snapModelThresh) targetModelX = 0;
                                if (targetModelY < snapModelThresh) targetModelY = 0;

                                const thisW = (delegateRoot.modelData && delegateRoot.modelData.logicalWidth) || 1920;
                                const thisH = (delegateRoot.modelData && delegateRoot.modelData.logicalHeight) || 1080;

                                for (let j = 0; j < (root.monitors ? root.monitors.length : 0); j++) {
                                    if (j === delegateRoot.index) continue;
                                    const other = root.monitors[j];
                                    if (!other) continue;
                                    const ox = (typeof other.x === "number" && !isNaN(other.x)) ? other.x : 0;
                                    const oy = (typeof other.y === "number" && !isNaN(other.y)) ? other.y : 0;
                                    const ow = (other.logicalWidth) || 1920;
                                    const oh = (other.logicalHeight) || 1080;

                                    // Snap right edge to other left
                                    if (Math.abs((targetModelX + thisW) - ox) < snapModelThresh) {
                                        targetModelX = ox - thisW;
                                    }
                                    // Snap left edge to other right
                                    if (Math.abs(targetModelX - (ox + ow)) < snapModelThresh) {
                                        targetModelX = ox + ow;
                                    }
                                    // Snap top edge to other top
                                    if (Math.abs(targetModelY - oy) < snapModelThresh) {
                                        targetModelY = oy;
                                    }
                                    // Snap bottom edge to other bottom
                                    if (Math.abs((targetModelY + thisH) - (oy + oh)) < snapModelThresh) {
                                        targetModelY = (oy + oh) - thisH;
                                    }
                                    // Snap top edge to other bottom
                                    if (Math.abs(targetModelY - (oy + oh)) < snapModelThresh) {
                                        targetModelY = oy + oh;
                                    }
                                    // Snap bottom edge to other top
                                    if (Math.abs((targetModelY + thisH) - oy) < snapModelThresh) {
                                        targetModelY = oy - thisH;
                                    }
                                }

                                targetModelX = Math.max(0, targetModelX);
                                targetModelY = Math.max(0, targetModelY);

                                currentDragModelX = targetModelX;
                                currentDragModelY = targetModelY;

                                delegateRoot.dragScreenX = Math.round(root.panX + (targetModelX * root.viewScale));
                                delegateRoot.dragScreenY = Math.round(root.panY + (targetModelY * root.viewScale));
                            }

                            onReleased: {
                                if (delegateRoot.isDragging) {
                                    delegateRoot.isDragging = false;
                                    
                                    let newMonitors = JSON.parse(JSON.stringify(root.monitors));
                                    newMonitors[delegateRoot.index].x = Math.max(0, Math.round(currentDragModelX));
                                    newMonitors[delegateRoot.index].y = Math.max(0, Math.round(currentDragModelY));
                                    
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

    // ── Floating Action Bar inside Canvas (Zoom, Fit, Identify) ─────────────
    StyledRect {
        id: zoomHud
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: root.padNormal
        implicitWidth: hudLayout.implicitWidth + (Tokens.padding ? Tokens.padding.normal * 2 : 24)
        implicitHeight: 44
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
                implicitWidth: 32
                implicitHeight: 32
                type: IconButton.Tonal
                icon: "visibility"
                iconPointSize: root.fSmall
                onClicked: DisplayManager.identifyDisplays()
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
                implicitWidth: 32
                implicitHeight: 32
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
                implicitWidth: 32
                implicitHeight: 32
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
