pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Olvex Clipboard — M3 Expressive split command canvas (redesigned from scratch)
Window {
    id: win

    width: 1020
    height: 620
    minimumWidth: 860
    minimumHeight: 480
    visible: true
    title: qsTr("Olvex Clipboard")
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowCloseButtonHint
    color: tok.palette.stage

    // ── App state ─────────────────────────────────────────────────────────────
    ListModel { id: clipListModel }
    property string searchQuery: ""
    property int selectedIndex: 0
    property string selectedEntryId: ""
    property string statusMessage: ""
    property bool busy: false
    property string filterMode: "all"
    property bool keyboardNavActive: true
    // When false, list hover must not steal selection (arrow keys vs cursor-over-list)
    property bool listHoverSelectEnabled: true
    property real listHoverFreezeX: 0
    property real listHoverFreezeY: 0
    property int selectionPulse: 0
    property int previewRev: 0
    property int imageRev: 0
    property real shellOpacity: 1
    property real shellScale: 0.96
    property real previewOpacity: 1
    property string previewEditText: ""
    property string previewAppliedText: ""
    property string previewLastText: ""
    property var previewUndoStack: []
    property var previewRedoStack: []
    property bool previewUndoLock: false
    property bool previewEditing: false
    readonly property bool previewDirty: previewEditText !== previewAppliedText
    readonly property bool hasClips: clipListModel.count > 0
    readonly property bool canPreviewUndo: previewUndoStack.length > 1
    readonly property bool canPreviewRedo: previewRedoStack.length > 0

    readonly property var activeClip: (clipListModel.count > 0
        && selectedIndex >= 0 && selectedIndex < clipListModel.count)
        ? clipListModel.get(selectedIndex) : null

    readonly property bool reducedMotion: false

    // ── M3 tokens — extracted from current wallpaper (same pipeline as Olvex shell) ─
    readonly property QtObject tok: QtObject {
        readonly property QtObject palette: QtObject {
            readonly property color primary: SystemAccent.primary
            readonly property color fgPrimary: SystemAccent.fgPrimary
            readonly property color primaryContainer: SystemAccent.primaryContainer
            readonly property color fgPrimaryContainer: SystemAccent.fgPrimaryContainer
            readonly property color secondaryContainer: SystemAccent.secondaryContainer
            readonly property color fgSecondaryContainer: SystemAccent.fgSecondaryContainer
            readonly property color tertiary: SystemAccent.tertiary
            readonly property color tertiaryContainer: SystemAccent.tertiaryContainer
            readonly property color fgTertiaryContainer: SystemAccent.fgTertiaryContainer
            readonly property color surface: SystemAccent.surface
            readonly property color fgSurface: SystemAccent.fgSurface
            readonly property color fgMuted: SystemAccent.fgMuted
            readonly property color rail: SystemAccent.rail
            readonly property color stage: SystemAccent.stage
            readonly property color stageHigh: SystemAccent.stageHigh
            readonly property color stageContent: SystemAccent.stageContent
            readonly property color outline: SystemAccent.outline
            readonly property color outlineVariant: SystemAccent.outlineVariant
            readonly property color error: SystemAccent.error
            readonly property color errorContainer: SystemAccent.errorContainer
            readonly property color fgErrorContainer: SystemAccent.fgErrorContainer
        }
        readonly property QtObject shape: QtObject {
            readonly property int xs: 4
            readonly property int sm: 8
            readonly property int md: 12
            readonly property int lg: 16
            readonly property int xl: 24
            readonly property int full: 999
        }
        // M3 Expressive motion — spatial + effects schemes (m3.material.io)
        readonly property QtObject motion: QtObject {
            readonly property QtObject spatialExpressive: QtObject {
                readonly property real fastSpring: 7.0
                readonly property real fastDamping: 0.50
                readonly property real defaultSpring: 3.8
                readonly property real defaultDamping: 0.36
                readonly property real bounceDamping: 0.32
                readonly property real slowSpring: 2.0
                readonly property real slowDamping: 0.40
                readonly property real overshoot: 1.4
            }
            readonly property QtObject effectsExpressive: QtObject {
                readonly property int fast: 80
                readonly property int defaultMs: 200
                readonly property int slow: 350
            }
            readonly property QtObject spatialStandard: QtObject {
                readonly property real defaultSpring: 3.8
                readonly property real defaultDamping: 0.70
            }
            readonly property real springMass: 1.0
            readonly property real springEpsilon: 0.01
            readonly property int spatialFastMs: 150
            readonly property int spatialDefaultMs: 250
            readonly property real expressiveOvershoot: 1.15
            // M3 emphasized — spatial + effects (m3.material.io)
            readonly property var emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]
            readonly property int emphasizedLong: 400
            readonly property int emphasizedMedium: 250
        }
        readonly property QtObject type: QtObject {
            readonly property font title: Qt.font({ family: "Sans Serif", pixelSize: 15, weight: Font.DemiBold })
            readonly property font titleEmph: Qt.font({ family: "Sans Serif", pixelSize: 20, weight: Font.Bold })
            readonly property font body: Qt.font({ family: "Sans Serif", pixelSize: 14, weight: Font.Normal })
            readonly property font bodyEmph: Qt.font({ family: "Sans Serif", pixelSize: 14, weight: Font.Medium })
            readonly property font label: Qt.font({ family: "Sans Serif", pixelSize: 12, weight: Font.Medium })
            readonly property font labelEmph: Qt.font({ family: "Sans Serif", pixelSize: 12, weight: Font.DemiBold })
            readonly property font mono: Qt.font({ family: "Monospace", pixelSize: 13, weight: Font.Normal })
            readonly property font preview: Qt.font({ family: "Sans Serif", pixelSize: 17, weight: Font.Normal })
            readonly property font previewEmph: Qt.font({ family: "Sans Serif", pixelSize: 28, weight: Font.DemiBold })
        }
    }

    // ── Components ──────────────────────────────────────────────────────────

    // M3 Expressive ButtonGroup — fixed pill indicator, smooth slide, stable layout
    component FilterButtonGroup: Item {
        id: fbg
        property int current: 0
        property var options: []
        signal picked(int index, string value)

        implicitHeight: 44
        readonly property int segmentCount: Math.max(1, options.length)
        readonly property real segmentWidth: width > 0 ? width / segmentCount : 0
        readonly property real inset: 4
        readonly property real indicatorW: Math.max(0, segmentWidth - inset * 2)

        Rectangle {
            anchors.fill: parent
            radius: tok.shape.full
            color: tok.palette.secondaryContainer
        }

        Rectangle {
            id: fbgIndicator
            z: 0
            y: inset
            height: parent.height - inset * 2
            width: indicatorW
            x: inset + current * segmentWidth
            radius: tok.shape.full
            color: tok.palette.primary

            Behavior on x {
                enabled: !win.reducedMotion
                NumberAnimation {
                    duration: tok.motion.spatialDefaultMs
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on width {
                enabled: !win.reducedMotion
                NumberAnimation {
                    duration: tok.motion.effectsExpressive.fast
                    easing.type: Easing.OutCubic
                }
            }
        }

        Row {
            id: fbgRow
            anchors.fill: parent
            z: 1

            Repeater {
                model: fbg.options
                delegate: Item {
                    id: fbgSeg
                    required property var modelData
                    required property int index

                    property bool active: fbg.current === index
                    property int tabCount: win.filterCount(modelData.value)

                    width: fbg.segmentWidth
                    height: fbgRow.height

                    Rectangle {
                        anchors.fill: parent
                        radius: tok.shape.full
                        color: tok.palette.fgSurface
                        opacity: segMa.pressed ? 0.1
                            : (segMa.containsMouse && !fbgSeg.active ? 0.06 : 0)
                        Behavior on opacity {
                            enabled: !win.reducedMotion
                            NumberAnimation {
                                duration: tok.motion.effectsExpressive.fast
                                easing.type: Easing.OutQuad
                            }
                        }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            id: segGlyph
                            scale: fbgSeg.active ? 1.12 : 1.0

                            Behavior on scale {
                                enabled: !win.reducedMotion
                                NumberAnimation {
                                    duration: tok.motion.effectsExpressive.defaultMs
                                    easing.type: Easing.OutBack
                                    easing.overshoot: tok.motion.expressiveOvershoot
                                }
                            }
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            Layout.alignment: Qt.AlignVCenter
                            text: fbgSeg.modelData.glyph || ""
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            font.family: "Monospace"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: fbgSeg.active
                                ? tok.palette.fgPrimary : tok.palette.fgMuted

                            Behavior on color {
                                enabled: !win.reducedMotion
                                ColorAnimation {
                                    duration: tok.motion.effectsExpressive.fast
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        Text {
                            id: segLabel
                            Layout.preferredHeight: 22
                            Layout.alignment: Qt.AlignVCenter
                            text: fbgSeg.modelData.label
                            font: fbgSeg.active ? tok.type.labelEmph : tok.type.label
                            verticalAlignment: Text.AlignVCenter
                            color: fbgSeg.active
                                ? tok.palette.fgPrimary : tok.palette.fgMuted

                            Behavior on color {
                                enabled: !win.reducedMotion
                                ColorAnimation {
                                    duration: tok.motion.effectsExpressive.defaultMs
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            visible: fbgSeg.tabCount > 0
                            width: countLbl.implicitWidth + 10
                            height: 20
                            radius: tok.shape.full
                            color: fbgSeg.active
                                ? tok.palette.fgPrimary
                                : tok.palette.stageHigh
                            scale: fbgSeg.active ? 1.08 : 1.0

                            Behavior on color {
                                enabled: !win.reducedMotion
                                ColorAnimation {
                                    duration: tok.motion.effectsExpressive.fast
                                    easing.type: Easing.OutQuad
                                }
                            }
                            Behavior on scale {
                                enabled: !win.reducedMotion
                                NumberAnimation {
                                    duration: tok.motion.effectsExpressive.defaultMs
                                    easing.type: Easing.OutBack
                                    easing.overshoot: tok.motion.expressiveOvershoot
                                }
                            }

                            Text {
                                id: countLbl
                                anchors.centerIn: parent
                                text: String(fbgSeg.tabCount)
                                font: tok.type.labelEmph
                                color: fbgSeg.active
                                    ? tok.palette.primary
                                    : tok.palette.fgSecondaryContainer

                                Behavior on color {
                                    enabled: !win.reducedMotion
                                    ColorAnimation { duration: tok.motion.effectsExpressive.fast }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: segMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fbg.picked(fbgSeg.index, fbgSeg.modelData.value)
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: fbgSeg.modelData.label
                }
            }
        }
    }

    component IconButton: Rectangle {
        id: ib
        property string glyph: ""
        property string accessibleName: ""
        property string tone: "neutral"
        signal triggered()

        implicitWidth: 34
        implicitHeight: 34
        radius: tok.shape.full
        color: {
            if (ib.tone === "error")
                return ibMa.pressed
                    ? Qt.darker(tok.palette.errorContainer, 1.08)
                    : (ibMa.containsMouse ? tok.palette.errorContainer : tok.palette.errorContainer)
            return ibMa.pressed
                ? tok.palette.stageHigh
                : (ibMa.containsMouse ? tok.palette.secondaryContainer : "transparent")
        }
        border.width: 0
        scale: ibMa.pressed ? 0.9 : (ibMa.containsMouse ? 1.06 : 1.0)

        Behavior on scale {
            enabled: !win.reducedMotion
            NumberAnimation {
                duration: tok.motion.effectsExpressive.fast
                easing.type: Easing.OutBack
                easing.overshoot: tok.motion.expressiveOvershoot
            }
        }
        Behavior on color {
            enabled: !win.reducedMotion
            ColorAnimation { duration: tok.motion.effectsExpressive.fast; easing.type: Easing.OutQuad }
        }

        Text {
            anchors.centerIn: parent
            text: ib.glyph
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: ib.tone === "error" ? tok.palette.fgErrorContainer : tok.palette.fgMuted
            scale: ibMa.pressed ? 0.9 : 1.0

            Behavior on scale {
                enabled: !win.reducedMotion
                NumberAnimation { duration: tok.motion.effectsExpressive.fast; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }
            Behavior on color {
                enabled: !win.reducedMotion
                ColorAnimation { duration: tok.motion.effectsExpressive.fast }
            }
        }

        MouseArea {
            id: ibMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.triggered()
        }

        Accessible.role: Accessible.Button
        Accessible.name: ib.accessibleName.length > 0 ? ib.accessibleName : ib.glyph
    }

    component PrimaryButton: Rectangle {
        id: pbtn
        property string label: ""
        property string glyph: ""
        signal triggered()

        implicitHeight: 40
        implicitWidth: Math.max(92, pbtnRow.implicitWidth + 28)
        radius: tok.shape.full
        color: pMa.pressed ? Qt.darker(tok.palette.primary, 1.1) : tok.palette.primary
        opacity: enabled ? 1 : 0.38
        scale: enabled && pMa.pressed ? 0.92 : (enabled && pMa.containsMouse ? 1.05 : 1.0)

        Behavior on scale {
            enabled: !win.reducedMotion
            NumberAnimation {
                duration: tok.motion.effectsExpressive.fast
                easing.type: Easing.OutBack
                easing.overshoot: tok.motion.spatialExpressive.overshoot
            }
        }
        Behavior on color {
            enabled: !win.reducedMotion
            ColorAnimation { duration: tok.motion.effectsExpressive.fast; easing.type: Easing.OutQuad }
        }
        Behavior on opacity {
            enabled: !win.reducedMotion
            NumberAnimation { duration: tok.motion.effectsExpressive.fast; easing.type: Easing.OutCubic }
        }

        RowLayout {
            id: pbtnRow
            anchors.centerIn: parent
            spacing: 6

            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                visible: pbtn.glyph.length > 0

                Text {
                    anchors.centerIn: parent
                    text: pbtn.glyph
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.family: pbtn.glyph.length > 1 ? "Monospace" : "Sans Serif"
                    horizontalAlignment: Text.AlignHCenter
                    color: tok.palette.fgPrimary
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: pbtn.label
                font: tok.type.labelEmph
                color: tok.palette.fgPrimary
            }
        }

        MouseArea {
            id: pMa
            anchors.fill: parent
            enabled: pbtn.enabled
            hoverEnabled: pbtn.enabled
            cursorShape: pbtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (pbtn.enabled) pbtn.triggered()
        }

        Accessible.role: Accessible.Button
        Accessible.name: pbtn.label
    }

    component TonalButton: Rectangle {
        id: tbtn
        property string label: ""
        property string glyph: ""
        property string tone: "neutral" // neutral | error
        signal triggered()

        readonly property color _fg: tbtn.tone === "error"
            ? tok.palette.fgErrorContainer
            : tok.palette.fgSecondaryContainer
        readonly property color _bg: {
            if (tbtn.tone === "error")
                return tMa.pressed
                    ? Qt.darker(tok.palette.errorContainer, 1.08)
                    : tok.palette.errorContainer
            return tMa.pressed ? tok.palette.stageHigh : tok.palette.secondaryContainer
        }

        implicitHeight: 40
        implicitWidth: Math.max(tbtn.label.length > 0 ? 88 : 40, tbtnRow.implicitWidth + 24)
        radius: tok.shape.full
        color: tbtn._bg
        border.width: 0
        opacity: enabled ? 1 : 0.38
        scale: enabled && tMa.pressed ? 0.94
            : (enabled && tMa.containsMouse ? 1.03 : 1.0)

        Behavior on scale {
            enabled: !win.reducedMotion
            NumberAnimation {
                duration: tok.motion.effectsExpressive.fast
                easing.type: Easing.OutBack
                easing.overshoot: tok.motion.expressiveOvershoot
            }
        }
        Behavior on color {
            enabled: !win.reducedMotion
            ColorAnimation { duration: tok.motion.effectsExpressive.fast; easing.type: Easing.OutQuad }
        }
        Behavior on opacity {
            enabled: !win.reducedMotion
            NumberAnimation { duration: tok.motion.effectsExpressive.fast; easing.type: Easing.OutCubic }
        }

        RowLayout {
            id: tbtnRow
            anchors.centerIn: parent
            spacing: 6

            Item {
                Layout.preferredWidth: tbtn.glyph.length > 0 ? 22 : 0
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                visible: tbtn.glyph.length > 0

                Text {
                    anchors.centerIn: parent
                    text: tbtn.glyph
                    font.pixelSize: tbtn.glyph.length > 1 ? 11 : 13
                    font.weight: Font.DemiBold
                    font.family: tbtn.glyph.length > 1 ? "Monospace" : "Sans Serif"
                    horizontalAlignment: Text.AlignHCenter
                    color: tbtn._fg
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: tbtn.label.length > 0
                text: tbtn.label
                font: tok.type.labelEmph
                color: tbtn._fg
            }
        }

        MouseArea {
            id: tMa
            anchors.fill: parent
            enabled: tbtn.enabled
            hoverEnabled: tbtn.enabled
            cursorShape: tbtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (tbtn.enabled) tbtn.triggered()
        }

        Accessible.role: Accessible.Button
        Accessible.name: tbtn.label.length > 0 ? tbtn.label : tbtn.glyph
    }

    // Compact kbd hint chip for footer shortcuts — solid M3 surface
    component KbdHint: Rectangle {
        id: kh
        property string keys: ""
        property string caption: ""

        implicitHeight: 22
        implicitWidth: khRow.implicitWidth + 10
        radius: tok.shape.sm
        color: "transparent"

        Row {
            id: khRow
            anchors.centerIn: parent
            spacing: 5

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: Math.max(22, keyLbl.implicitWidth + 10)
                implicitHeight: 18
                radius: 5
                color: tok.palette.stageHigh
                border.width: 1
                border.color: tok.palette.outlineVariant

                Text {
                    id: keyLbl
                    anchors.centerIn: parent
                    text: kh.keys
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.family: "Monospace"
                    color: tok.palette.fgMuted
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: kh.caption
                font: tok.type.label
                color: tok.palette.fgMuted
            }
        }
    }

    component WavyBar: Item {
        id: wbar
        property real phase: 0
        implicitHeight: 3

        Timer {
            interval: 16
            running: win.busy && !win.reducedMotion
            repeat: true
            onTriggered: { wbar.phase += 0.09; wavyCanvas.requestPaint() }
        }

        Connections {
            target: SystemAccent
            function onPaletteChanged() { wavyCanvas.requestPaint() }
        }

        Canvas {
            id: wavyCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                const W = width, H = height, mid = H / 2
                ctx.clearRect(0, 0, W, H)
                ctx.beginPath()
                for (let x = 0; x <= W; x += 2) {
                    const y = mid + Math.sin(x * 0.07 + wbar.phase) * 1.4
                    if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                ctx.strokeStyle = tok.palette.primary
                ctx.lineWidth = H
                ctx.lineCap = "round"
                ctx.stroke()
            }
        }
    }

    // M3 list row — tonal surface, radius morph, emphasized motion
    component ClipListRow : Item {
        id: row

        required property int index
        required property string entryId
        required property string entryPreview
        required property string entryRaw
        required property string entryText
        required property bool isImage
        required property string imagePath
        required property bool imageDecodeFailed
        required property bool decoded
        required property bool edited
        property bool isCurrent: false

        signal activated()
        signal deleteRequested()

        width: ListView.view ? ListView.view.width : implicitWidth
        height: 60
        implicitHeight: 60
        opacity: 1

        // Hover on visual only — MouseArea fills row for click without fighting delete
        HoverHandler {
            id: rowHover
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            id: rowMa

            anchors.fill: parent
            hoverEnabled: false
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }

        Item {
            id: rowBody

            anchors.fill: parent
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            scale: rowMa.pressed ? 0.985 : (row.isCurrent ? 1.0 : 1.0)
            transformOrigin: Item.Center

            Behavior on scale {
                enabled: !win.reducedMotion
                SpringAnimation {
                    spring: rowMa.pressed ? 5.0 : 4.2
                    damping: rowMa.pressed ? 0.65 : 0.70
                    mass: tok.motion.springMass
                    epsilon: tok.motion.springEpsilon
                }
            }

            Connections {
                target: win
                function onSelectionPulseChanged() {
                    if (row.isCurrent && !win.reducedMotion)
                        rowPulse.restart()
                }
            }

            SequentialAnimation {
                id: rowPulse

                running: false
                NumberAnimation {
                    target: rowBody
                    property: "scale"
                    to: 1.02
                    duration: 80
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: rowBody
                    property: "scale"
                    to: 1.0
                    duration: 180
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.1
                }
            }

            // Selection fill is the sliding listFocusMarker. Rows: solid M3 hover only.
            Rectangle {
                id: rowSurface

                anchors.fill: parent
                radius: rowMa.pressed ? tok.shape.lg : tok.shape.md
                color: {
                    if (row.isCurrent)
                        return "transparent"
                    if (rowHover.hovered)
                        return tok.palette.stageContent
                    return "transparent"
                }
                border.width: 0

                Behavior on radius {
                    enabled: !win.reducedMotion
                    NumberAnimation {
                        duration: tok.motion.emphasizedMedium
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: tok.motion.emphasized
                    }
                }
                Behavior on color {
                    enabled: !win.reducedMotion
                    ColorAnimation {
                        duration: tok.motion.effectsExpressive.fast
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                // Room for gliding delete on focus marker
                anchors.rightMargin: 44
                spacing: 10
                z: 1

                // ID chip — solid M3
                Rectangle {
                    Layout.preferredWidth: Math.max(36, idLbl.implicitWidth + 12)
                    Layout.preferredHeight: 24
                    radius: tok.shape.full
                    color: row.isCurrent
                        ? tok.palette.primary
                        : tok.palette.stageContent
                    border.width: 0

                    Behavior on color {
                        enabled: !win.reducedMotion
                        ColorAnimation {
                            duration: tok.motion.emphasizedMedium
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: tok.motion.emphasized
                        }
                    }

                    Text {
                        id: idLbl
                        anchors.centerIn: parent
                        text: row.entryId
                        font: tok.type.labelEmph
                        color: row.isCurrent ? tok.palette.fgPrimary : tok.palette.fgMuted

                        Behavior on color {
                            enabled: !win.reducedMotion
                            ColorAnimation {
                                duration: tok.motion.emphasizedMedium
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: tok.motion.emphasized
                            }
                        }
                    }
                }

                // Image thumb — solid primaryContainer
                Rectangle {
                    visible: row.isImage
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: tok.shape.sm
                    color: tok.palette.primaryContainer
                    clip: true
                    border.width: 0

                    Image {
                        id: thumbImg
                        anchors.fill: parent
                        anchors.margins: 1
                        source: {
                            const _rev = win.imageRev
                            return (row.imagePath && row.imagePath.length > 0)
                                ? ("file://" + row.imagePath) : ""
                        }
                        sourceSize: Qt.size(84, 84)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            enabled: !win.reducedMotion
                            NumberAnimation { duration: tok.motion.effectsExpressive.fast }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: thumbImg.status !== Image.Ready
                        text: "▦"
                        font.pixelSize: 16
                        color: tok.palette.fgPrimaryContainer
                    }
                }

                Rectangle {
                    visible: row.isImage
                    Layout.preferredWidth: imgChipLbl.implicitWidth + 12
                    Layout.preferredHeight: 22
                    radius: tok.shape.full
                    color: tok.palette.tertiaryContainer
                    border.width: 0

                    Text {
                        id: imgChipLbl

                        anchors.centerIn: parent
                        text: qsTr("Image")
                        font: tok.type.label
                        color: tok.palette.fgTertiaryContainer
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: row.isImage
                        ? (row.entryPreview.length > 0 ? row.entryPreview : qsTr("Image clip"))
                        : row.entryPreview
                    font: row.isCurrent ? tok.type.bodyEmph : tok.type.body
                    color: row.isCurrent ? tok.palette.fgSurface : tok.palette.fgMuted
                    elide: Text.ElideRight
                    maximumLineCount: 1

                    Behavior on color {
                        enabled: !win.reducedMotion
                        ColorAnimation {
                            duration: tok.motion.emphasizedMedium
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: tok.motion.emphasized
                        }
                    }
                }
            }
        }

        Accessible.role: Accessible.ListItem
        Accessible.name: row.entryPreview
    }

    // ── Logic (unchanged behaviour) ───────────────────────────────────────────

    function clipId(entry) {
        if (!entry) return ""
        const idx = String(entry).indexOf("\t")
        return idx > 0 ? String(entry).slice(0, idx).trim() : ""
    }

    function clipText(entry) {
        if (!entry) return ""
        const idx = String(entry).indexOf("\t")
        return idx > 0 ? String(entry).slice(idx + 1).trim() : String(entry).trim()
    }

    function isImage(entry) {
        return (typeof Cliphist !== "undefined" && Cliphist) ? Cliphist.entryIsImage(entry) : false
    }

    function cliphistItems() {
        if (typeof Cliphist === "undefined" || !Cliphist)
            return []

        const parsed = Cliphist.items
        if (parsed && parsed.length > 0)
            return parsed

        const entries = Cliphist.entries
        if (!entries || entries.length === 0)
            return []

        const built = []
        const seen = {}
        for (let i = 0; i < entries.length; i++) {
            const entry = String(entries[i])
            const tabIdx = entry.indexOf("\t")
            if (tabIdx <= 0)
                continue
            const entryId = entry.slice(0, tabIdx).trim()
            if (!entryId || seen[entryId])
                continue
            seen[entryId] = true
            const entryPreview = entry.slice(tabIdx + 1).trim()
            built.push({
                entryId: entryId,
                entryPreview: entryPreview,
                entryRaw: entry,
                entryText: entryPreview,
                isImage: Cliphist.entryIsImage(entry),
                imagePath: "",
                decoded: false,
                edited: false
            })
        }
        return built
    }

    function filteredCliphistItems() {
        const items = cliphistItems()
        const q = searchQuery.trim().toLowerCase()
        const out = []
        for (let i = 0; i < items.length; i++) {
            const it = items[i]
            if (filterMode === "text" && it.isImage) continue
            if (filterMode === "image" && !it.isImage) continue
            const blob = (it.entryId + " " + it.entryPreview + " " + it.entryRaw).toLowerCase()
            if (q && blob.indexOf(q) === -1) continue
            out.push(it)
        }
        return out
    }

    function clipListMatches(items) {
        if (clipListModel.count !== items.length)
            return false
        for (let i = 0; i < items.length; i++) {
            const row = clipListModel.get(i)
            const it = items[i]
            if (!row || row.entryId !== it.entryId
                || row.entryPreview !== it.entryPreview
                || row.isImage !== it.isImage)
                return false
        }
        return true
    }

    function rebuildClipList() {
        const items = filteredCliphistItems()
        if (clipListMatches(items))
            return false

        clipListModel.clear()
        for (let i = 0; i < items.length; i++) {
            const it = items[i]
            clipListModel.append({
                entryId: it.entryId,
                entryPreview: it.entryPreview,
                entryRaw: it.entryRaw,
                entryText: it.entryText,
                isImage: it.isImage,
                imagePath: it.imagePath || "",
                imageDecodeFailed: false,
                decoded: it.decoded || false,
                edited: it.edited || false
            })
        }

        if (selectedIndex >= clipListModel.count)
            selectedIndex = Math.max(0, clipListModel.count - 1)
        return true
    }

    signal filteredHistoryChanged()

    function refreshHistory() {
        const keepId = activeClip ? activeClip.entryId : ""
        const rebuilt = rebuildClipList()
        if (keepId.length > 0) {
            let found = -1
            for (let i = 0; i < clipListModel.count; i++) {
                if (clipListModel.get(i).entryId === keepId) {
                    found = i
                    break
                }
            }
            selectedIndex = found >= 0 ? found : 0
        } else if (selectedIndex >= clipListModel.count) {
            selectedIndex = Math.max(0, clipListModel.count - 1)
        }
        if (rebuilt) {
            previewRev++
            filteredHistoryChanged()
        }
        syncPreviewText()
        if (listView) {
            if (keepId.length === 0)
                Qt.callLater(() => listView.positionViewAtBeginning())
            else
                syncListSelection()
        }
    }

    function applyFilter() {
        rebuildClipList()
    }

    function clipAtIndex(idx) {
        if (idx < 0 || idx >= clipListModel.count)
            return null
        return clipListModel.get(idx)
    }

    function indexAtListPoint(viewX, viewY) {
        if (!listView || clipListModel.count === 0)
            return -1
        const contentY = viewY + listView.contentY
        // Position walk is reliable with fixed-height rows + spacing (indexAt can be ±1 here).
        for (let i = 0; i < clipListModel.count; i++) {
            const item = listView.itemAtIndex(i)
            if (!item)
                continue
            if (contentY >= item.y && contentY < item.y + item.height)
                return i
        }
        return -1
    }

    function selectClipAtIndex(idx) {
        if (idx < 0 || idx >= clipListModel.count || idx === selectedIndex)
            return
        keyboardNavActive = false
        selectedIndex = idx
    }

    // Keyboard moved focus — ignore list hover until the pointer actually moves
    function freezeListHoverSelect() {
        listHoverSelectEnabled = false
        if (listHover && listHover.hovered) {
            listHoverFreezeX = listHover.point.position.x
            listHoverFreezeY = listHover.point.position.y
        }
    }

    function maybeResumeListHoverSelect(px, py) {
        if (listHoverSelectEnabled)
            return true
        const dx = px - listHoverFreezeX
        const dy = py - listHoverFreezeY
        // ~4px real mouse move re-arms hover selection
        if ((dx * dx + dy * dy) < 16)
            return false
        listHoverSelectEnabled = true
        keyboardNavActive = false
        return true
    }

    function syncListSelection() {
        if (!listView || clipListModel.count === 0) return
        const idx = Math.max(0, Math.min(selectedIndex, clipListModel.count - 1))
        if (idx !== selectedIndex)
            selectedIndex = idx
        if (listView.currentIndex !== idx)
            listView.currentIndex = idx
        if (keyboardNavActive && typeof listView.smoothEnsureVisible === "function")
            listView.smoothEnsureVisible(idx)
    }

    function bumpPreview() {
        previewRev++
    }

    function resetPreviewHistory(baseText) {
        previewUndoStack = [baseText]
        previewRedoStack = []
        previewLastText = baseText
    }

    function clipImagePath(entryId) {
        return "/tmp/olvex-clip/" + entryId + ".png"
    }

    function requestDecodeClipImage(listIndex) {
        if (listIndex < 0 || listIndex >= clipListModel.count)
            return
        const item = clipListModel.get(listIndex)
        if (!item || !item.isImage)
            return
        if (item.imagePath && item.imagePath.length > 0)
            return
        if (typeof Cliphist === "undefined" || !Cliphist)
            return
        if (typeof Cliphist.requestDecodeImageById !== "function")
            return
        Cliphist.requestDecodeImageById(item.entryId, clipImagePath(item.entryId))
    }

    function applyDecodedText(entryId, fullText) {
        if (!entryId || !fullText)
            return
        for (let i = 0; i < clipListModel.count; i++) {
            if (clipListModel.get(i).entryId !== entryId)
                continue
            clipListModel.setProperty(i, "entryText", fullText)
            clipListModel.setProperty(i, "decoded", true)
            if (entryId === selectedEntryId && !previewEditing) {
                setPreviewEditorText(fullText)
                previewAppliedText = fullText
                resetPreviewHistory(fullText)
                bumpPreview()
            }
            break
        }
    }

    function applyDecodedImage(entryId, path, ok) {
        for (let i = 0; i < clipListModel.count; i++) {
            if (clipListModel.get(i).entryId !== entryId)
                continue
            if (ok && path.length > 0)
                clipListModel.setProperty(i, "imagePath", path)
            else
                clipListModel.setProperty(i, "imageDecodeFailed", true)
            if (entryId === selectedEntryId)
                imageRev++
            break
        }
    }

    function syncPreviewText() {
        previewEditing = false
        previewUndoLock = false
        const clip = clipAtIndex(selectedIndex)
        selectedEntryId = clip ? clip.entryId : ""
        if (clip && !clip.isImage) {
            const preview = clip.entryText || clip.entryPreview || ""
            setPreviewEditorText(preview)
            previewAppliedText = preview
            resetPreviewHistory(preview)
            bumpPreview()
            if (!clip.decoded && typeof Cliphist !== "undefined" && Cliphist
                && typeof Cliphist.requestDecodeTextById === "function")
                Cliphist.requestDecodeTextById(clip.entryId)
        } else {
            setPreviewEditorText("")
            previewAppliedText = ""
            resetPreviewHistory("")
            bumpPreview()
        }
    }

    function beginPreviewEdit() {
        if (!activeClip || activeClip.isImage)
            return
        previewEditing = true
        resetPreviewHistory(previewEditText)
        // Defer focus until after edit UI enables (avoids race with overlays)
        Qt.callLater(function() {
            if (!previewEditor || !win.previewEditing)
                return
            previewEditor.readOnly = false
            previewEditor.cursorVisible = true
            previewEditor.forceActiveFocus(Qt.MouseFocusReason)
            // Caret at end if empty selection
            if (previewEditor.cursorPosition < 0)
                previewEditor.cursorPosition = previewEditor.text.length
        })
    }

    function setPreviewEditorText(text) {
        previewUndoLock = true
        previewEditText = text
        if (previewEditor)
            previewEditor.text = text
        previewLastText = text
        previewUndoLock = false
    }

    function pushPreviewUndo(state) {
        const stack = previewUndoStack
        if (stack.length > 0 && stack[stack.length - 1] === state)
            return
        previewUndoStack = stack.concat([state])
        previewRedoStack = []
    }

    function undoPreview() {
        if (!canPreviewUndo)
            return
        previewRedoStack = previewRedoStack.concat([previewEditText])
        const stack = previewUndoStack.slice(0, -1)
        previewUndoStack = stack
        setPreviewEditorText(stack[stack.length - 1])
    }

    function redoPreview() {
        if (!canPreviewRedo)
            return
        const redoStack = previewRedoStack
        const next = redoStack[redoStack.length - 1]
        previewUndoStack = previewUndoStack.concat([previewEditText])
        previewRedoStack = redoStack.slice(0, -1)
        setPreviewEditorText(next)
    }

    function applyPreviewEdit() {
        if (!activeClip || activeClip.isImage)
            return
        previewAppliedText = previewEditText
        clipListModel.setProperty(selectedIndex, "entryText", previewEditText)
        clipListModel.setProperty(selectedIndex, "edited", true)
        previewEditing = false
        resetPreviewHistory(previewEditText)
        if (previewEditor)
            previewEditor.focus = false
        reclaimFocus()
    }

    function exitPreviewEdit() {
        if (!previewEditing)
            return false
        setPreviewEditorText(previewAppliedText)
        previewEditing = false
        resetPreviewHistory(previewAppliedText)
        if (previewEditor)
            previewEditor.focus = false
        reclaimFocus()
        return true
    }

    function copySelected() {
        if (!clipListModel.count) return
        const item = clipListModel.get(selectedIndex)
        if (!item) return
        if (item.isImage) {
            Cliphist.copy(item.entryRaw)
        } else if (item.edited || previewDirty) {
            Cliphist.copyText(previewEditing ? previewEditText : item.entryText)
        } else {
            Cliphist.copy(item.entryRaw)
        }
        win.close()
    }

    function deleteSelected() {
        if (!clipListModel.count) return
        const item = clipListModel.get(selectedIndex)
        if (!item) return
        busy = true
        Cliphist.deleteEntry(item.entryRaw)
        refreshHistory()
    }

    function wipeAll() {
        if (typeof Cliphist === "undefined" || !Cliphist) return
        busy = true
        Cliphist.wipe()
        refreshHistory()
    }

    function moveSelection(delta) {
        if (!clipListModel.count) return
        keyboardNavActive = true
        freezeListHoverSelect()
        const next = Math.max(0, Math.min(clipListModel.count - 1, selectedIndex + delta))
        if (next === selectedIndex) return
        selectedIndex = next
        selectionPulse++
        bumpPreview()
        syncListSelection()
    }

    function jumpSelection(toIndex) {
        if (!clipListModel.count) return
        keyboardNavActive = true
        freezeListHoverSelect()
        const next = Math.max(0, Math.min(clipListModel.count - 1, toIndex))
        if (next === selectedIndex) return
        selectedIndex = next
        selectionPulse++
        bumpPreview()
        syncListSelection()
    }

    function reclaimFocus() {
        rootFocus.forceActiveFocus(Qt.ShortcutFocusReason)
    }

    function handleEscape() {
        if (previewEditing) {
            exitPreviewEdit()
            return
        }
        if (searchField.activeFocus && searchField.text.length > 0) {
            searchField.clear()
            reclaimFocus()
            return
        }
        if (searchField.activeFocus) {
            reclaimFocus()
            return
        }
        close()
    }

    function handleFilterArrow(event) {
        if (!event || previewEditing)
            return false
        if (event.key !== Qt.Key_Left && event.key !== Qt.Key_Right)
            return false
        if (searchField.activeFocus && searchField.text.length > 0)
            return false
        shiftFilter(event.key === Qt.Key_Right ? 1 : -1)
        event.accepted = true
        return true
    }

    function handleKey(event) {
        if (!event)
            return

        if (event.key === Qt.Key_Escape) {
            handleEscape()
            event.accepted = true
            return
        }

        if (handleFilterArrow(event))
            return

        if (previewEditing)
            return

        if (!clipListModel.count)
            return

        if (event.key === Qt.Key_Up) { moveSelection(-1); event.accepted = true }
        else if (event.key === Qt.Key_Down) { moveSelection(1); event.accepted = true }
        else if (event.key === Qt.Key_Home) { jumpSelection(0); event.accepted = true }
        else if (event.key === Qt.Key_End) { jumpSelection(clipListModel.count - 1); event.accepted = true }
        else if (event.key === Qt.Key_PageUp) {
            moveSelection(-Math.max(1, Math.floor(listView.height / 48))); event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            moveSelection(Math.max(1, Math.floor(listView.height / 48))); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { copySelected(); event.accepted = true }
        else if (event.key === Qt.Key_Delete) { deleteSelected(); event.accepted = true }
    }

    readonly property var filterModes: ["all", "text", "image"]

    function setFilter(mode) {
        if (filterMode === mode)
            return
        filterMode = mode
        // Defer list rebuild so indicator slide isn't blocked same frame
        Qt.callLater(function() {
            selectedIndex = 0
            applyFilter()
            bumpPreview()
        })
    }

    function shiftFilter(delta) {
        const idx = filterIndexForMode(filterMode)
        const count = filterModes.length
        const next = ((idx + delta) % count + count) % count
        const mode = filterModes[next]
        if (mode === filterMode)
            return
        keyboardNavActive = true
        setFilter(mode)
        if (!(searchField.activeFocus && searchField.text.length > 0))
            reclaimFocus()
    }

    function filterIndexForMode(mode) {
        if (mode === "text") return 1
        if (mode === "image") return 2
        return 0
    }

    function filterCount(mode) {
        let n = 0
        const items = cliphistItems()
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (mode === "text" && item.isImage) continue
            if (mode === "image" && !item.isImage) continue
            n++
        }
        return n
    }

    // ── Backend ───────────────────────────────────────────────────────────────

    Connections {
        target: (typeof Cliphist !== "undefined") ? Cliphist : null
        function onEntriesChanged() { win.refreshHistory() }
        function onLoadingChanged() {
            if (Cliphist) busy = Cliphist.loading
        }
        function onErrorChanged() {
            if (Cliphist && Cliphist.hasError) statusMessage = Cliphist.errorMessage
        }
        function onTextDecoded(entryId, text) {
            win.applyDecodedText(entryId, text)
        }
        function onImageDecoded(entryId, path, ok) {
            win.applyDecodedImage(entryId, path, ok)
        }
    }

    Shortcut { sequence: "Ctrl+K"; onActivated: searchField.forceActiveFocus(Qt.ShortcutFocusReason) }

    Shortcut {
        sequence: "Escape"
        onActivated: win.handleEscape()
    }

    // Window shortcuts — work even when list steals focus under the cursor
    Shortcut {
        sequence: "Up"
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0
        onActivated: moveSelection(-1)
    }
    Shortcut {
        sequence: "Down"
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0
        onActivated: moveSelection(1)
    }
    Shortcut {
        sequences: ["Home", StandardKey.MoveToStartOfDocument]
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0
        onActivated: jumpSelection(0)
    }
    Shortcut {
        sequences: ["End", StandardKey.MoveToEndOfDocument]
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0
        onActivated: jumpSelection(clipListModel.count - 1)
    }
    Shortcut {
        sequences: ["PgUp", StandardKey.MoveToPreviousPage]
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0
        onActivated: moveSelection(-Math.max(1, Math.floor(listView.height / 48)))
    }
    Shortcut {
        sequences: ["PgDown", StandardKey.MoveToNextPage]
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0
        onActivated: moveSelection(Math.max(1, Math.floor(listView.height / 48)))
    }
    Shortcut {
        sequences: ["Return", "Enter", StandardKey.InsertParagraphSeparator, StandardKey.InsertLineSeparator]
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0
        onActivated: copySelected()
    }
    Shortcut {
        sequence: "Delete"
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0
        onActivated: deleteSelected()
    }

    Component.onCompleted: {
        if (!reducedMotion)
            shellEntrance.start()
        else
            shellScale = 1
        reclaimFocus()
        if (typeof Cliphist !== "undefined" && Cliphist)
            refreshHistory()
    }

    NumberAnimation {
        id: shellEntrance
        running: false
        target: win
        property: "shellScale"
        from: 0.96
        to: 1
        duration: tok.motion.effectsExpressive.fast
        easing.type: Easing.OutCubic
    }

    onSelectedIndexChanged: {
        syncPreviewText()
        if (activeClip && activeClip.isImage)
            requestDecodeClipImage(selectedIndex)
        syncListSelection()
        bumpPreview()
    }
    onVisibleChanged: if (!visible) Qt.quit()

    // ── Shell ─────────────────────────────────────────────────────────────────

    FocusScope {
        id: rootFocus
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) { win.handleKey(event) }

        Item {
            id: shell
            anchors.fill: parent
            opacity: win.shellOpacity
            scale: win.shellScale
            transformOrigin: Item.Center

            // Reclaim focus after mouse clicks so arrow keys reach rootFocus / handleKey.
            // Never steal focus while the text editor is active (kills the caret).
            MouseArea {
                anchors.fill: parent
                z: -1
                hoverEnabled: false
                propagateComposedEvents: true
                onPressed: function(mouse) {
                    if (!win.previewEditing)
                        win.reclaimFocus()
                    mouse.accepted = false
                }
            }

            Rectangle {
                id: paletteHud
                visible: SystemAccent.debugHud
                z: 9999
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 22
                color: Qt.rgba(0, 0, 0, 0.78)
                Text {
                    anchors.centerIn: parent
                    font.pixelSize: 11
                    color: tok.palette.fgSurface
                    text: (SystemAccent.wallpaperSource || "no wallpaper")
                        + " | primary: " + SystemAccent.primary
                        + " | " + (SystemAccent.schemeName || "extracting…")
                }
            }

            Behavior on opacity {
                enabled: !win.reducedMotion
                NumberAnimation { duration: tok.motion.effectsExpressive.defaultMs; easing.type: Easing.OutCubic }
            }

            WavyBar {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                opacity: win.busy ? 1 : 0
                visible: opacity > 0
                z: 10

                Behavior on opacity {
                    enabled: !win.reducedMotion
                    NumberAnimation {
                        duration: tok.motion.effectsExpressive.fast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 18

                // ═══ LEFT RAIL — command + timeline ═══════════════════════════
                Rectangle {
                    id: rail
                    Layout.preferredWidth: 400
                    Layout.fillHeight: true
                    color: tok.palette.stageHigh
                    radius: tok.shape.xl
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Layout.bottomMargin: 2

                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: qsTr("Clipboard")
                                    font: tok.type.titleEmph
                                    color: tok.palette.fgSurface
                                }

                                Text {
                                    id: statusLbl
                                    text: statusMessage.length > 0
                                        ? statusMessage
                                        : qsTr("%1 clips in history").arg(clipListModel.count)
                                    font: tok.type.label
                                    color: tok.palette.fgMuted
                                    opacity: 0.9

                                    Connections {
                                        target: win
                                        function onFilteredHistoryChanged() {
                                            if (!win.reducedMotion)
                                                statusPulse.restart()
                                        }
                                        function onStatusMessageChanged() {
                                            if (!win.reducedMotion)
                                                statusPulse.restart()
                                        }
                                    }

                                    SequentialAnimation {
                                        id: statusPulse
                                        running: false
                                        NumberAnimation {
                                            target: statusLbl
                                            property: "opacity"
                                            to: 0.4
                                            duration: win.reducedMotion ? 1 : 80
                                        }
                                        NumberAnimation {
                                            target: statusLbl
                                            property: "opacity"
                                            to: 0.9
                                            duration: win.reducedMotion ? 1 : 160
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }

                            // Count chip — solid primaryContainer
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: Math.max(36, countChipLbl.implicitWidth + 14)
                                implicitHeight: 28
                                radius: height / 2
                                color: tok.palette.primaryContainer
                                border.width: 0
                                visible: clipListModel.count > 0 && statusMessage.length === 0

                                Text {
                                    id: countChipLbl
                                    anchors.centerIn: parent
                                    text: String(clipListModel.count)
                                    font: tok.type.labelEmph
                                    color: tok.palette.fgPrimaryContainer
                                }
                            }

                            // Clear history — soft destructive, never solid red blob
                            TonalButton {
                                Layout.alignment: Qt.AlignVCenter
                                label: qsTr("Clear")
                                glyph: "⌫"
                                tone: "error"
                                implicitHeight: 32
                                enabled: clipListModel.count > 0
                                onTriggered: win.wipeAll()
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4
                        }

                        // Command search — solid M3 field
                        Rectangle {
                            id: searchBox
                            Layout.fillWidth: true
                            property int boxHeight: searchField.activeFocus ? 50 : 44
                            Layout.preferredHeight: boxHeight
                            radius: searchField.activeFocus ? tok.shape.xl : tok.shape.lg
                            color: searchField.activeFocus
                                ? tok.palette.primaryContainer
                                : tok.palette.stageContent
                            border.width: searchField.activeFocus ? 2 : 0
                            border.color: tok.palette.primary

                            Behavior on boxHeight {
                                enabled: !win.reducedMotion
                                NumberAnimation {
                                    duration: tok.motion.effectsExpressive.fast
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.15
                                }
                            }
                            Behavior on radius {
                                enabled: !win.reducedMotion
                                NumberAnimation { duration: tok.motion.effectsExpressive.fast; easing.type: Easing.OutQuad }
                            }
                            Behavior on color {
                                ColorAnimation { duration: tok.motion.effectsExpressive.fast }
                            }
                            Behavior on border.color {
                                ColorAnimation { duration: tok.motion.effectsExpressive.fast }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "⌕"
                                    font.pixelSize: 24
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    color: searchField.activeFocus
                                        ? tok.palette.fgPrimaryContainer
                                        : tok.palette.fgMuted
                                    scale: searchField.activeFocus ? 1.12 : 1.0

                                    Behavior on color {
                                        enabled: !win.reducedMotion
                                        ColorAnimation { duration: tok.motion.effectsExpressive.fast }
                                    }
                                    Behavior on scale {
                                        enabled: !win.reducedMotion
                                        NumberAnimation {
                                            duration: tok.motion.effectsExpressive.defaultMs
                                            easing.type: Easing.OutBack
                                            easing.overshoot: tok.motion.expressiveOvershoot
                                        }
                                    }
                                }

                                TextField {
                                    id: searchField
                                    Layout.fillWidth: true
                                    placeholderText: qsTr("Search or jump…")
                                    text: searchQuery
                                    font: tok.type.body
                                    color: searchField.activeFocus
                                        ? tok.palette.fgPrimaryContainer
                                        : tok.palette.fgSurface
                                    placeholderTextColor: searchField.activeFocus
                                        ? tok.palette.fgPrimaryContainer
                                        : tok.palette.fgMuted
                                    selectByMouse: true
                                    background: Item {}
                                    onTextChanged: {
                                        searchQuery = text
                                        selectedIndex = 0
                                        applyFilter()
                                    }
                                    Keys.priority: Keys.BeforeItem
                                    Keys.onUpPressed: function(event) {
                                        win.moveSelection(-1)
                                        event.accepted = true
                                    }
                                    Keys.onDownPressed: function(event) {
                                        win.moveSelection(1)
                                        event.accepted = true
                                    }
                                    Keys.onReturnPressed: function(event) {
                                        win.copySelected()
                                        event.accepted = true
                                    }
                                    Keys.onEnterPressed: function(event) {
                                        win.copySelected()
                                        event.accepted = true
                                    }
                                    Keys.onPressed: function(event) {
                                        if (win.handleFilterArrow(event))
                                            return
                                        win.handleKey(event)
                                    }
                                }

                                Text {
                                    visible: searchField.text.length === 0
                                    text: "Ctrl+K"
                                    font: tok.type.label
                                    color: tok.palette.fgMuted
                                    opacity: searchField.text.length === 0 ? 0.55 : 0

                                    Behavior on opacity {
                                        enabled: !win.reducedMotion
                                        NumberAnimation {
                                            duration: tok.motion.effectsExpressive.fast
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                IconButton {
                                    opacity: searchField.text.length > 0 ? 1 : 0
                                    visible: opacity > 0
                                    glyph: "×"
                                    accessibleName: qsTr("Clear search")
                                    onTriggered: searchField.clear()

                                    Behavior on opacity {
                                        enabled: !win.reducedMotion
                                        NumberAnimation {
                                            duration: tok.motion.effectsExpressive.fast
                                            easing.type: Easing.OutBack
                                            easing.overshoot: 1.1
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            z: 2
                            clip: true

                            FilterButtonGroup {
                                id: filterSeg
                                anchors.fill: parent
                                current: win.filterIndexForMode(filterMode)
                                options: [
                                    { label: qsTr("All"), value: "all", glyph: "☰" },
                                    { label: qsTr("Text"), value: "text", glyph: "T" },
                                    { label: qsTr("Images"), value: "image", glyph: "▤" }
                                ]
                                onPicked: function(index, value) { win.setFilter(value) }
                            }
                        }

                        // Timeline list — empty text fixed; list sheet slides over it
                        Item {
                            id: listRoot
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ColumnLayout {
                                id: railEmptyState
                                anchors.fill: parent
                                z: 0
                                spacing: 6
                                visible: !win.hasClips
                                opacity: visible ? 1 : 0

                                Behavior on opacity {
                                    enabled: !win.reducedMotion
                                    NumberAnimation {
                                        duration: tok.motion.effectsExpressive.defaultMs
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: searchQuery.length > 0 || filterMode !== "all"
                                        ? qsTr("No matches")
                                        : qsTr("History is empty")
                                    font: tok.type.title
                                    color: tok.palette.fgMuted
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: qsTr("Copy something to populate the list")
                                    font: tok.type.label
                                    color: tok.palette.fgMuted
                                    opacity: 0.65
                                }

                                Item { Layout.fillHeight: true }
                            }

                            Item {
                                id: listPage
                                anchors.fill: parent
                                visible: win.hasClips
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    color: tok.palette.stageHigh
                                }

                            // List-level pointer routing — avoids scaled-row hitbox overlap (±1 bug)
                            HoverHandler {
                                id: listHover
                                target: listView
                                acceptedDevices: PointerDevice.Mouse
                                    | PointerDevice.TouchScreen
                                    | PointerDevice.TouchPad

                                function syncFromPointer() {
                                    if (!hovered)
                                        return
                                    const px = point.position.x
                                    const py = point.position.y
                                    // After arrow keys, ignore hover until the mouse moves
                                    if (!win.maybeResumeListHoverSelect(px, py))
                                        return
                                    const idx = win.indexAtListPoint(px, py)
                                    win.selectClipAtIndex(idx)
                                }

                                onHoveredChanged: {
                                    if (!hovered)
                                        return
                                    // Fresh enter always allows hover select
                                    win.listHoverSelectEnabled = true
                                    syncFromPointer()
                                }
                                onPointChanged: syncFromPointer()
                            }

                            // Sliding focus marker fill — BEHIND list so row text stays visible
                            Item {
                                id: listFocusMarker

                                readonly property Item targetItem: {
                                    if (win.selectedIndex < 0 || win.selectedIndex >= clipListModel.count)
                                        return null
                                    return listView.itemAtIndex(win.selectedIndex)
                                }
                                readonly property bool active: win.selectedIndex >= 0 && win.selectedIndex < clipListModel.count && clipListModel.count > 0
                                readonly property int insetX: 6
                                readonly property int insetY: 4

                                property bool springEnabled: false
                                property real markerY: 0
                                property real markerH: 48

                                z: 0
                                x: insetX
                                width: Math.max(0, listPage.width - insetX * 2)
                                y: markerY
                                height: markerH
                                opacity: active ? 1 : 0
                                enabled: false

                                function retarget(animate) {
                                    const item = targetItem
                                    let ny = 0
                                    let nh = 48
                                    if (item && item.y !== undefined) {
                                        const rowH = item.height > 0 ? item.height : 60
                                        ny = item.y - listView.contentY + insetY
                                        nh = Math.max(36, rowH - insetY * 2)
                                    } else if (win.selectedIndex >= 0 && win.selectedIndex < clipListModel.count) {
                                        const estItemY = win.selectedIndex * 60 + win.selectedIndex * listView.spacing
                                        ny = estItemY - listView.contentY + insetY
                                        nh = Math.max(36, 60 - insetY * 2)
                                    } else {
                                        return
                                    }
                                    if (animate && !win.reducedMotion)
                                        springEnabled = true
                                    markerY = ny
                                    markerH = nh
                                }

                                onTargetItemChanged: {
                                    if (targetItem || win.selectedIndex >= 0)
                                        retarget(true)
                                }
                                onActiveChanged: {
                                    if (active)
                                        retarget(true)
                                }

                                Connections {
                                    target: win
                                    function onSelectedIndexChanged() {
                                        listFocusMarker.retarget(true)
                                    }
                                }

                                Connections {
                                    target: listView
                                    function onContentYChanged() {
                                        listFocusMarker.retarget(listFocusMarker.springEnabled)
                                    }
                                    function onCountChanged() {
                                        Qt.callLater(function() {
                                            listFocusMarker.retarget(false)
                                        })
                                    }
                                    function onHeightChanged() {
                                        listFocusMarker.retarget(false)
                                    }
                                }

                                Behavior on markerY {
                                    enabled: listFocusMarker.springEnabled
                                    SpringAnimation {
                                        spring: 4.6
                                        damping: 0.74
                                        mass: 1.0
                                        epsilon: 0.005
                                    }
                                }
                                Behavior on markerH {
                                    enabled: listFocusMarker.springEnabled
                                    SpringAnimation {
                                        spring: 5.0
                                        damping: 0.78
                                        mass: 1.0
                                        epsilon: 0.005
                                    }
                                }
                                Behavior on opacity {
                                    enabled: !win.reducedMotion
                                    NumberAnimation {
                                        duration: tok.motion.effectsExpressive.defaultMs
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                // Soft tonal pill under row content — secondaryContainer for clearer contrast vs rail
                                Rectangle {
                                    anchors.fill: parent
                                    // Less stadium, more M3 container (was height/2)
                                    radius: tok.shape.md
                                    color: tok.palette.secondaryContainer
                                    border.width: 1
                                    border.color: tok.palette.outlineVariant
                                }
                            }

                            ListView {
                                id: listView
                                z: 1
                                anchors.fill: parent
                                clip: true
                                model: clipListModel
                                spacing: 8
                                boundsBehavior: Flickable.StopAtBounds
                                keyNavigationEnabled: false
                                highlightFollowsCurrentItem: false
                                cacheBuffer: 600
                                reuseItems: false

                                displaced: Transition {
                                    enabled: !win.reducedMotion
                                    NumberAnimation {
                                        properties: "x,y"
                                        duration: tok.motion.emphasizedMedium
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: tok.motion.emphasized
                                    }
                                }

                                // Smooth scroll — mouse: animated notches; touchpad: pixel-direct
                                readonly property real scrollLineStep: 56
                                readonly property real scrollLinesPerNotch: 3

                                NumberAnimation {
                                    id: smoothScrollAnim
                                    target: listView
                                    property: "contentY"
                                    duration: tok.motion.emphasizedMedium
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: tok.motion.emphasized
                                }

                                onMovementStarted: smoothScrollAnim.stop()
                                onFlickStarted: smoothScrollAnim.stop()

                                function clampScrollY(y) {
                                    const maxScroll = Math.max(0, contentHeight - height)
                                    return Math.max(0, Math.min(maxScroll, y))
                                }

                                function applyScrollDelta(deltaPx, animate, animMs) {
                                    const targetY = clampScrollY(
                                        (smoothScrollAnim.running ? smoothScrollAnim.to : contentY) + deltaPx)
                                    if (animate && !win.reducedMotion) {
                                        smoothScrollAnim.stop()
                                        smoothScrollAnim.duration = animMs
                                        smoothScrollAnim.to = targetY
                                        smoothScrollAnim.start()
                                    } else {
                                        smoothScrollAnim.stop()
                                        contentY = targetY
                                    }
                                }

                                function smoothEnsureVisible(idx) {
                                    if (idx < 0 || idx >= clipListModel.count) return
                                    const item = itemAtIndex(idx)
                                    let itemY = idx * 60 + idx * spacing
                                    let itemH = 60
                                    if (item && item.height > 0) {
                                        itemY = item.y
                                        itemH = item.height
                                    }

                                    const currentY = smoothScrollAnim.running ? smoothScrollAnim.to : contentY
                                    const viewTop = currentY
                                    const viewBottom = currentY + height
                                    const padding = 16

                                    let targetY = currentY
                                    if (itemY + itemH + padding > viewBottom) {
                                        targetY = clampScrollY(itemY + itemH + padding - height)
                                    } else if (itemY - padding < viewTop) {
                                        targetY = clampScrollY(itemY - padding)
                                    }

                                    if (Math.abs(targetY - currentY) > 0.5) {
                                        if (!win.reducedMotion) {
                                            smoothScrollAnim.stop()
                                            smoothScrollAnim.duration = tok.motion.emphasizedMedium
                                            smoothScrollAnim.to = targetY
                                            smoothScrollAnim.start()
                                        } else {
                                            contentY = targetY
                                        }
                                    }
                                }

                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle {
                                        implicitWidth: 3
                                        radius: 2
                                        color: tok.palette.primary
                                    }
                                }

                                WheelHandler {
                                    id: smoothScrollHandler
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    onWheel: function(event) {
                                        const dev = event.device
                                        const isTouchPad = dev
                                            && dev.type === PointerDevice.TouchPad

                                        // Touchpad pixel deltas — smooth glide, not instant jump
                                        if (isTouchPad && event.pixelDelta.y !== 0) {
                                            listView.applyScrollDelta(
                                                -event.pixelDelta.y, true,
                                                tok.motion.effectsExpressive.fast)
                                            event.accepted = true
                                            return
                                        }

                                        const angleY = event.angleDelta.y
                                        if (angleY === 0)
                                            return

                                        const notchPx = -(angleY / 120)
                                            * listView.scrollLineStep
                                            * listView.scrollLinesPerNotch

                                        if (isTouchPad) {
                                            listView.applyScrollDelta(
                                                -(angleY / 120) * listView.scrollLineStep * 1.25,
                                                true, tok.motion.effectsExpressive.fast)
                                        } else {
                                            // Mouse wheel — always animated notch scroll
                                            listView.applyScrollDelta(
                                                notchPx, true, tok.motion.emphasizedMedium)
                                        }
                                        event.accepted = true
                                    }
                                }

                                delegate: ClipListRow {
                                    isCurrent: index === win.selectedIndex

                                    onIsCurrentChanged: {
                                        if (isImage && isCurrent)
                                            win.requestDecodeClipImage(index)
                                    }

                                    onActivated: {
                                        win.selectClipAtIndex(index)
                                        copySelected()
                                    }
                                    onDeleteRequested: {
                                        win.selectClipAtIndex(index)
                                        deleteSelected()
                                    }
                                }
                            }

                            // Delete only above list — tracks marker (fill is under list text)
                            IconButton {
                                id: listFocusDelete
                                z: 2
                                x: listFocusMarker.x + listFocusMarker.width - width - 8
                                y: listFocusMarker.y + (listFocusMarker.height - height) / 2
                                opacity: listFocusMarker.active ? 1 : 0
                                visible: opacity > 0.01
                                enabled: listFocusMarker.active
                                glyph: "×"
                                tone: "error"
                                accessibleName: qsTr("Delete")
                                onTriggered: {
                                    win.selectClipAtIndex(win.selectedIndex)
                                    win.deleteSelected()
                                }

                                Behavior on opacity {
                                    enabled: !win.reducedMotion
                                    NumberAnimation {
                                        duration: tok.motion.effectsExpressive.defaultMs
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                            }
                        }
                    }
                }

                // ═══ RIGHT STAGE — preview canvas ═════════════════════════════
                Rectangle {
                    id: stage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: tok.palette.stageContent
                    radius: tok.shape.xl
                    clip: true
                    border.width: 1
                    border.color: tok.palette.outlineVariant

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        visible: win.hasClips

                        // Preview meta header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            opacity: activeClip !== null ? 1 : 0
                            scale: activeClip !== null ? 1 : 0.96
                            visible: opacity > 0

                            Behavior on opacity {
                                enabled: !win.reducedMotion
                                NumberAnimation {
                                    duration: tok.motion.effectsExpressive.fast
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on scale {
                                enabled: !win.reducedMotion
                                NumberAnimation {
                                    duration: tok.motion.effectsExpressive.defaultMs
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.08
                                }
                            }

                            Rectangle {
                                implicitWidth: metaId.implicitWidth + 16
                                implicitHeight: 24
                                radius: tok.shape.full
                                color: tok.palette.primaryContainer
                                scale: activeClip !== null ? 1 : 0.8

                                Behavior on scale {
                                    enabled: !win.reducedMotion
                                    NumberAnimation {
                                        duration: tok.motion.effectsExpressive.defaultMs
                                        easing.type: Easing.OutBack
                                        easing.overshoot: tok.motion.expressiveOvershoot
                                    }
                                }

                                Text {
                                    id: metaId
                                    anchors.centerIn: parent
                                    text: activeClip ? ("#" + activeClip.entryId) : ""
                                    font: tok.type.labelEmph
                                    color: tok.palette.fgPrimaryContainer
                                }
                            }

                            Rectangle {
                                opacity: activeClip && activeClip.isImage ? 1 : 0
                                scale: activeClip && activeClip.isImage ? 1 : 0.7
                                visible: opacity > 0
                                implicitWidth: metaType.implicitWidth + 14
                                implicitHeight: 24
                                radius: tok.shape.full
                                color: tok.palette.tertiaryContainer

                                Behavior on opacity {
                                    enabled: !win.reducedMotion
                                    NumberAnimation { duration: tok.motion.effectsExpressive.fast }
                                }
                                Behavior on scale {
                                    enabled: !win.reducedMotion
                                    NumberAnimation {
                                        duration: tok.motion.effectsExpressive.defaultMs
                                        easing.type: Easing.OutBack
                                        easing.overshoot: tok.motion.expressiveOvershoot
                                    }
                                }

                                Text {
                                    id: metaType
                                    anchors.centerIn: parent
                                    text: qsTr("Image")
                                    font: tok.type.label
                                    color: tok.palette.fgTertiaryContainer
                                }
                            }

                            Rectangle {
                                opacity: activeClip && !activeClip.isImage ? 1 : 0
                                scale: activeClip && !activeClip.isImage ? 1 : 0.7
                                visible: opacity > 0
                                implicitWidth: metaType2.implicitWidth + 14
                                implicitHeight: 24
                                radius: tok.shape.full
                                color: tok.palette.secondaryContainer

                                Behavior on opacity {
                                    enabled: !win.reducedMotion
                                    NumberAnimation { duration: tok.motion.effectsExpressive.fast }
                                }
                                Behavior on scale {
                                    enabled: !win.reducedMotion
                                    NumberAnimation {
                                        duration: tok.motion.effectsExpressive.defaultMs
                                        easing.type: Easing.OutBack
                                        easing.overshoot: tok.motion.expressiveOvershoot
                                    }
                                }

                                Text {
                                    id: metaType2
                                    anchors.centerIn: parent
                                    text: qsTr("Text")
                                    font: tok.type.label
                                    color: tok.palette.fgSecondaryContainer
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                opacity: activeClip && activeClip.edited ? 1 : 0
                                scale: activeClip && activeClip.edited ? 1 : 0.6
                                visible: opacity > 0
                                implicitWidth: editedLbl.implicitWidth + 14
                                implicitHeight: 24
                                radius: tok.shape.full
                                color: tok.palette.primaryContainer

                                Behavior on opacity {
                                    enabled: !win.reducedMotion
                                    NumberAnimation {
                                        duration: tok.motion.effectsExpressive.fast
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on scale {
                                    enabled: !win.reducedMotion
                                    SpringAnimation {
                                        spring: tok.motion.spatialExpressive.fastSpring
                                        damping: tok.motion.spatialExpressive.fastDamping
                                        mass: tok.motion.springMass
                                        epsilon: tok.motion.springEpsilon
                                    }
                                }

                                Text {
                                    id: editedLbl
                                    anchors.centerIn: parent
                                    text: qsTr("Edited")
                                    font: tok.type.labelEmph
                                    color: tok.palette.primary
                                }
                            }

                            Text {
                                text: activeClip
                                    ? qsTr("%1 chars").arg(activeClip.entryText.length)
                                    : ""
                                font: tok.type.label
                                color: tok.palette.fgMuted
                                opacity: activeClip && !activeClip.isImage ? 1 : 0
                                visible: opacity > 0

                                Behavior on opacity {
                                    enabled: !win.reducedMotion
                                    NumberAnimation { duration: tok.motion.effectsExpressive.fast }
                                }
                            }
                        }

                        // Preview content (empty text lives on stage overlay — fixed position)
                        Item {
                            id: stagePageHost
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: win.hasClips
                            clip: true

                            Item {
                                id: previewBody
                                anchors.fill: parent
                                opacity: win.previewOpacity
                                visible: activeClip !== null

                                Item {
                                    anchors.fill: parent
                                    visible: activeClip && !activeClip.isImage
                                    z: win.previewEditing ? 100 : 0

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 6

                                    Rectangle {
                                        id: previewEditFrame
                                        // Handle click-to-edit in view mode (disabled in edit mode so text selection works)
                                        MouseArea {
                                            anchors.fill: parent
                                            z: 10
                                            enabled: !win.previewEditing
                                            onClicked: win.beginPreviewEdit()
                                        }

                                        // Independent cursor overlay (z:10 to sit above TextEdit, independent of MouseArea)
                                        Item {
                                            anchors.fill: parent
                                            z: 10
                                            HoverHandler {
                                                cursorShape: win.previewEditing ? Qt.IBeamCursor : Qt.ArrowCursor
                                            }
                                        }



                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumHeight: 140
                                        radius: tok.shape.lg
                                        color: tok.palette.stageHigh
                                        clip: true

                                        // Arrow cursor overlay for view mode — sits on top of everything
                                        Behavior on radius {
                                            enabled: !win.reducedMotion
                                            NumberAnimation { duration: tok.motion.effectsExpressive.fast }
                                        }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 0
                                            spacing: 0

                                            RowLayout {
                                                id: previewEditBar
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: win.previewEditing ? 40 : 0
                                                Layout.leftMargin: 8
                                                Layout.rightMargin: 8
                                                Layout.topMargin: win.previewEditing ? 8 : 0
                                                spacing: 6
                                                opacity: win.previewEditing ? 1 : 0
                                                visible: opacity > 0

                                                Behavior on opacity {
                                                    enabled: !win.reducedMotion
                                                    NumberAnimation {
                                                        duration: tok.motion.effectsExpressive.fast
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }

                                                Item { Layout.fillWidth: true }

                                                TonalButton {
                                                    implicitHeight: 32
                                                    label: qsTr("Undo")
                                                    glyph: "↶"
                                                    enabled: win.canPreviewUndo
                                                    onTriggered: win.undoPreview()
                                                }

                                                TonalButton {
                                                    implicitHeight: 32
                                                    label: qsTr("Redo")
                                                    glyph: "↷"
                                                    enabled: win.canPreviewRedo
                                                    onTriggered: win.redoPreview()
                                                }

                                                PrimaryButton {
                                                    implicitHeight: 32
                                                    label: qsTr("Apply")
                                                    glyph: "✓"
                                                    enabled: win.previewDirty
                                                    onTriggered: win.applyPreviewEdit()
                                                }
                                            }

                                            // Flickable + TextEdit — reliable caret (ScrollView/TextArea often eats focus)
                                            Flickable {
                                                id: previewScroll
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                clip: true
                                                contentWidth: width
                                                contentHeight: Math.max(previewEditor.implicitHeight, height)
                                                boundsBehavior: Flickable.StopAtBounds
                                                flickableDirection: Flickable.VerticalFlick
                                                interactive: contentHeight > height + 1
                                                // Never take keyboard focus from the editor
                                                focus: false

                                                TextEdit {
                                                    id: previewEditor
                                                    width: previewScroll.width
                                                    // Fill viewport so empty area is still clickable for caret
                                                    height: Math.max(implicitHeight, previewScroll.height)
                                                    // Imperative text — binding would fight caret/selection
                                                    readOnly: !win.previewEditing
                                                    wrapMode: TextEdit.Wrap
                                                    textFormat: TextEdit.PlainText
                                                    font: tok.type.preview
                                                    color: tok.palette.fgSurface
                                                    selectedTextColor: tok.palette.fgPrimary
                                                    selectionColor: tok.palette.primary
                                                    leftPadding: 12
                                                    rightPadding: 12
                                                    topPadding: 12
                                                    bottomPadding: 12

                                                    selectByMouse: true
                                                    selectByKeyboard: true
                                                    persistentSelection: true
                                                    activeFocusOnPress: true
                                                    // Always allow caret paint when focused; hide when read-only
                                                    cursorVisible: !readOnly && activeFocus
                                                    // Ensure IME / input method enabled
                                                    inputMethodHints: Qt.ImhNone

                                                    // Material-style blinking caret (high contrast)
                                                    cursorDelegate: Rectangle {
                                                        id: caret
                                                        width: 2
                                                        height: previewEditor.cursorRectangle.height > 0
                                                            ? previewEditor.cursorRectangle.height
                                                            : Math.max(20, previewEditor.font.pixelSize * 1.2)
                                                        color: tok.palette.primary
                                                        visible: previewEditor.activeFocus
                                                            && !previewEditor.readOnly
                                                            && previewEditor.selectionStart === previewEditor.selectionEnd

                                                        Connections {
                                                            target: previewEditor
                                                            function onCursorPositionChanged() {
                                                                caret.opacity = 1
                                                                caretBlink.restart()
                                                            }
                                                            function onActiveFocusChanged() {
                                                                caret.opacity = 1
                                                                if (previewEditor.activeFocus)
                                                                    caretBlink.restart()
                                                            }
                                                        }

                                                        Timer {
                                                            id: caretBlink
                                                            interval: 500
                                                            running: caret.visible
                                                            repeat: true
                                                            onTriggered: caret.opacity = caret.opacity > 0.5 ? 0 : 1
                                                            onRunningChanged: if (running) caret.opacity = 1
                                                        }
                                                    }

                                                    Component.onCompleted: text = win.previewEditText

                                                    Connections {
                                                        target: win
                                                        function onPreviewRevChanged() {
                                                            if (win.previewEditing || win.previewUndoLock)
                                                                return
                                                            previewEditor.text = win.previewEditText
                                                        }
                                                        function onPreviewEditingChanged() {
                                                            if (win.previewEditing) {
                                                                previewEditor.readOnly = false
                                                                previewEditor.forceActiveFocus(Qt.OtherFocusReason)
                                                                previewEditor.cursorVisible = true
                                                            } else {
                                                                previewEditor.cursorVisible = false
                                                            }
                                                        }
                                                    }

                                                    onActiveFocusChanged: {
                                                        if (activeFocus && win.previewEditing)
                                                            cursorVisible = true
                                                    }

                                                    onTextChanged: {
                                                        if (win.previewUndoLock || !win.previewEditing)
                                                            return
                                                        if (text !== win.previewLastText)
                                                            win.pushPreviewUndo(win.previewLastText)
                                                        win.previewLastText = text
                                                        win.previewEditText = text
                                                    }

                                                    Keys.priority: Keys.BeforeItem
                                                    Keys.onPressed: function(event) {
                                                        if (win.handleFilterArrow(event))
                                                            return
                                                        if (!win.previewEditing)
                                                            win.handleKey(event)
                                                    }
                                                    Keys.onEscapePressed: function(event) {
                                                        win.handleEscape()
                                                        event.accepted = true
                                                    }

                                                    Shortcut {
                                                        sequence: "Ctrl+Z"
                                                        enabled: win.previewEditing && previewEditor.activeFocus
                                                        onActivated: win.undoPreview()
                                                    }

                                                    Shortcut {
                                                        sequences: [StandardKey.Redo]
                                                        enabled: win.previewEditing && previewEditor.activeFocus
                                                        onActivated: win.redoPreview()
                                                    }
                                                }

                                                ScrollBar.vertical: ScrollBar {
                                                    policy: ScrollBar.AsNeeded
                                                    contentItem: Rectangle {
                                                        implicitWidth: 3
                                                        radius: 2
                                                        color: tok.palette.primary
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        id: editHint
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: editHint.visible ? implicitHeight : 0
                                        horizontalAlignment: Text.AlignRight
                                        rightPadding: 4
                                        visible: !win.previewEditing
                                        text: qsTr("Click to edit")
                                        font: tok.type.label
                                        color: previewFrameHover.hovered
                                            ? tok.palette.primary
                                            : tok.palette.fgMuted
                                        opacity: visible ? (previewFrameHover.hovered ? 0.85 : 0.6) : 0

                                        Behavior on opacity {
                                            enabled: !win.reducedMotion
                                            NumberAnimation {
                                                duration: tok.motion.effectsExpressive.fast
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                        Behavior on color {
                                            enabled: !win.reducedMotion
                                            ColorAnimation { duration: tok.motion.effectsExpressive.fast }
                                        }
                                    }

                                    }
                                }

                                Item {
                                    anchors.fill: parent
                                    visible: activeClip && activeClip.isImage

                                    Rectangle {
                                        id: imageFrame
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height * 1.4)
                                        height: Math.min(parent.height, width * 0.72)
                                        radius: tok.shape.xl
                                        color: tok.palette.stageHigh
                                        clip: true
                                        border.width: 1
                                        border.color: tok.palette.outlineVariant
                                        scale: stageImage.status === Image.Ready ? 1 : 0.96
                                        opacity: stageImage.status === Image.Ready ? 1 : 0.85

                                        Behavior on scale {
                                            enabled: !win.reducedMotion
                                            NumberAnimation {
                                                duration: tok.motion.effectsExpressive.defaultMs
                                                easing.type: Easing.OutBack
                                                easing.overshoot: tok.motion.expressiveOvershoot
                                            }
                                        }
                                        Behavior on opacity {
                                            enabled: !win.reducedMotion
                                            NumberAnimation { duration: tok.motion.effectsExpressive.fast }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation { duration: tok.motion.effectsExpressive.defaultMs }
                                        }

                                        Image {
                                            id: stageImage
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            opacity: status === Image.Ready ? 1 : 0

                                            Behavior on opacity {
                                                enabled: !win.reducedMotion
                                                NumberAnimation {
                                                    duration: tok.motion.effectsExpressive.defaultMs
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                            source: {
                                                const _rev = win.imageRev
                                                const _id = win.selectedEntryId
                                                if (!_id.length) return ""
                                                for (let i = 0; i < clipListModel.count; i++) {
                                                    const item = clipListModel.get(i)
                                                    if (!item || item.entryId !== _id || !item.isImage)
                                                        continue
                                                    const p = item.imagePath
                                                    return (p && p.length > 0) ? ("file://" + p) : ""
                                                }
                                                return ""
                                            }
                                            sourceSize: Qt.size(1200, 900)
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: stageImage.status !== Image.Ready
                                            color: tok.palette.stageHigh
                                            Text {
                                                anchors.centerIn: parent
                                                text: {
                                                    const _id = win.selectedEntryId
                                                    for (let i = 0; i < clipListModel.count; i++) {
                                                        const item = clipListModel.get(i)
                                                        if (!item || item.entryId !== _id)
                                                            continue
                                                        if (item.imageDecodeFailed)
                                                            return qsTr("Image decode failed")
                                                        break
                                                    }
                                                    if (stageImage.status === Image.Error)
                                                        return qsTr("Image decode failed")
                                                    return qsTr("Decoding image…")
                                                }
                                                font: tok.type.label
                                                color: tok.palette.fgMuted
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                id: stagePickState
                                anchors.centerIn: parent
                                spacing: 8
                                visible: activeClip === null

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "◇"
                                    font.pixelSize: 32
                                    color: tok.palette.fgMuted
                                    opacity: 0.35
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: qsTr("Select a clip to preview")
                                    font: tok.type.title
                                    color: tok.palette.fgMuted
                                }
                            }
                        }

                        ColumnLayout {
                            id: actionFooter
                            Layout.fillWidth: true
                            Layout.preferredHeight: clipListModel.count > 0 ? 84 : 0
                            spacing: 10

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                Layout.alignment: Qt.AlignHCenter

                                Rectangle {
                                    id: actionPill
                                    readonly property int pillPad: 6

                                    anchors.centerIn: parent
                                    width: actionRow.width + pillPad * 2
                                    height: actionRow.height + pillPad * 2
                                    radius: height / 2
                                    color: tok.palette.stageHigh
                                    border.width: 1
                                    border.color: tok.palette.outlineVariant
                                    opacity: clipListModel.count > 0 ? 1 : 0
                                    scale: clipListModel.count > 0 ? 1 : 0.92
                                    visible: opacity > 0

                                    Behavior on width {
                                        enabled: !win.reducedMotion
                                        NumberAnimation {
                                            duration: tok.motion.effectsExpressive.fast
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Behavior on opacity {
                                        enabled: !win.reducedMotion
                                        NumberAnimation {
                                            duration: tok.motion.effectsExpressive.defaultMs
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Behavior on scale {
                                        enabled: !win.reducedMotion
                                        NumberAnimation {
                                            duration: tok.motion.effectsExpressive.defaultMs
                                            easing.type: Easing.OutBack
                                            easing.overshoot: tok.motion.expressiveOvershoot
                                        }
                                    }

                                    Row {
                                        id: actionRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        PrimaryButton {
                                            label: qsTr("Copy")
                                            glyph: "⏎"
                                            implicitHeight: 36
                                            onTriggered: win.copySelected()
                                        }

                                        TonalButton {
                                            label: qsTr("Delete")
                                            glyph: "⌫"
                                            tone: "error"
                                            implicitHeight: 36
                                            onTriggered: win.deleteSelected()
                                        }

                                        TonalButton {
                                            label: qsTr("Close")
                                            glyph: "Esc"
                                            implicitHeight: 36
                                            onTriggered: win.close()
                                        }
                                    }
                                }
                            }

                            Row {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 14
                                opacity: clipListModel.count > 0 ? 1 : 0
                                visible: opacity > 0.01

                                Behavior on opacity {
                                    enabled: !win.reducedMotion
                                    NumberAnimation {
                                        duration: tok.motion.effectsExpressive.defaultMs
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                KbdHint { keys: "←→"; caption: qsTr("filter") }
                                KbdHint { keys: "↑↓"; caption: qsTr("navigate") }
                                KbdHint { keys: "Enter"; caption: qsTr("copy") }
                                KbdHint { keys: "Del"; caption: qsTr("delete") }
                            }
                        }
                    }

                    // Empty stage — flat pane, centered copy (no card, no motion)
                    Item {
                        id: stageEmptyOverlay
                        anchors.fill: parent
                        z: 2
                        visible: !win.hasClips
                        enabled: false

                        Rectangle {
                            anchors.fill: parent
                            color: tok.palette.stageContent
                            radius: stage.radius
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            width: Math.min(360, parent.width - 48)

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: qsTr("Ready when you are")
                                font: tok.type.previewEmph
                                color: tok.palette.fgSurface
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: qsTr("Your clipboard history will appear in the rail on the left")
                                font: tok.type.body
                                color: tok.palette.fgMuted
                                opacity: 0.85
                            }
                        }
                    }
                }
            }

            // Dismiss edit when clicking outside the editor frame.
            // Uses hoverEnabled:false + accepted:false inside so TextEdit keeps focus/caret.
            MouseArea {
                anchors.fill: parent
                visible: win.previewEditing
                enabled: win.previewEditing
                z: 40
                propagateComposedEvents: true
                hoverEnabled: false
                preventStealing: false
                onPressed: function(mouse) {
                    const pt = mapToItem(previewEditFrame, mouse.x, mouse.y)
                    const inside = pt.x >= 0 && pt.y >= 0
                        && pt.x <= previewEditFrame.width && pt.y <= previewEditFrame.height
                    if (inside) {
                        mouse.accepted = false
                        // Re-assert editor focus if something stole it
                        Qt.callLater(function() {
                            if (win.previewEditing && previewEditor)
                                previewEditor.forceActiveFocus(Qt.MouseFocusReason)
                        })
                        return
                    }
                    win.exitPreviewEdit()
                    mouse.accepted = true
                }
            }
        }
    }
}