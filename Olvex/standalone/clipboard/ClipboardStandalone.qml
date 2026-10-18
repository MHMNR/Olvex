import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes

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
    color: "transparent"

    // ── App state ─────────────────────────────────────────────────────────────
    ListModel { id: clipListModel }
    property var decodedTextCache: ({})
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
    property real shellOpacity: 0
    property real shellScale: 0.94
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
            readonly property bool isLight: Boolean(SystemAccent && SystemAccent.isLight)
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
            readonly property int xxl: 28
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
            // M3 Expressive Default Spatial — spatial container expansion & tab sliding (m3.material.io)
            readonly property var expressiveDefaultSpatial: [0.38, 1.20, 0.22, 1.0, 1, 1]
            readonly property int expressiveDefaultSpatialMs: 500
        }
        readonly property QtObject type: QtObject {
            readonly property string uiFamily: "Inter, Roboto, Noto Sans, Adwaita Sans, Sans Serif"
            readonly property string monoFamily: "JetBrains Mono, Geist Mono, SF Mono, Monospace, monospace"
            readonly property font title: Qt.font({ family: uiFamily, pixelSize: 15, weight: Font.DemiBold })
            readonly property font titleEmph: Qt.font({ family: uiFamily, pixelSize: 18, weight: Font.Bold })
            readonly property font body: Qt.font({ family: uiFamily, pixelSize: 13, weight: Font.Normal })
            readonly property font bodyEmph: Qt.font({ family: uiFamily, pixelSize: 13, weight: Font.DemiBold })
            readonly property font label: Qt.font({ family: uiFamily, pixelSize: 12, weight: Font.Normal })
            readonly property font labelEmph: Qt.font({ family: uiFamily, pixelSize: 12, weight: Font.Medium })
            readonly property font mono: Qt.font({ family: monoFamily, pixelSize: 11, weight: Font.Normal })
            readonly property font preview: Qt.font({ family: monoFamily, pixelSize: 13, weight: Font.Normal })
            readonly property font previewEmph: Qt.font({ family: uiFamily, pixelSize: 22, weight: Font.DemiBold })
        }
    }

    // ── Components ──────────────────────────────────────────────────────────

    // Authentic Material Symbols Rounded ligature icon
    component MIcon: Text {
        id: mi
        property string name: ""
        property int size: 18
        property color iconColor: tok.palette.fgSurface
        property real fill: 0
        property int weight: 400

        text: name
        textFormat: Text.PlainText
        font.family: "Material Symbols Rounded"
        font.pixelSize: size
        font.features: ({ "liga": 1 })
        font.hintingPreference: Font.PreferFullHinting
        font.variableAxes: ({
            FILL: mi.fill,
            GRAD: 0,
            opsz: Math.max(20, Math.min(48, size)),
            wght: mi.weight
        })
        font.weight: Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: iconColor
        antialiasing: true
        renderType: Text.NativeRendering
    }

    // Keycap badge for shortcuts
    component KbdKey: Rectangle {
        id: kk
        property string key: ""
        property color textColor: tok.palette.fgMuted
        property color bg: "transparent"
        property color borderColor: "transparent"

        readonly property bool isBackspace: kk.key === "⌫" || kk.key === "backspace"
        readonly property bool isReturn: kk.key === "⏎" || kk.key === "return" || kk.key === "enter"

        implicitWidth: isBackspace ? 18 : (isReturn ? 16 : keyText.implicitWidth)
        implicitHeight: 20
        radius: 0
        color: bg
        border.width: 0
        border.color: "transparent"

        MIcon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 2
            visible: kk.isBackspace
            name: "backspace"
            size: 16
            iconColor: kk.textColor
        }

        MIcon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 2
            visible: kk.isReturn
            name: "keyboard_return"
            size: 15
            iconColor: kk.textColor
        }

        Text {
            id: keyText
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            visible: !kk.isBackspace && !kk.isReturn
            text: kk.key
            textFormat: Text.PlainText
            font.pixelSize: 11
            font.weight: Font.Bold
            font.family: tok.type.monoFamily
            font.hintingPreference: Font.PreferFullHinting
            renderType: Text.NativeRendering
            color: kk.textColor
        }
    }

    // M3 Expressive ButtonGroup — fixed pill indicator, smooth slide, stable layout
    component FilterButtonGroup: Item {
        id: fbg
        property int current: 0
        property var options: []
        signal picked(int index, string value)

        implicitHeight: 36
        readonly property int segmentCount: Math.max(1, options.length)
        readonly property real segmentWidth: width > 0 ? width / segmentCount : 0
        readonly property real inset: 3
        readonly property real indicatorW: Math.max(0, segmentWidth - inset * 2)

        Rectangle {
            anchors.fill: parent
            radius: tok.shape.full
            color: tok.palette.isLight ? "#DFE4E3" : Qt.alpha(tok.palette.fgSurface, 0.13)
            border.width: 0
            border.color: "transparent"
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
                    duration: tok.motion.expressiveDefaultSpatialMs
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: tok.motion.expressiveDefaultSpatial
                }
            }

            Behavior on width {
                enabled: !win.reducedMotion
                NumberAnimation {
                    duration: tok.motion.expressiveDefaultSpatialMs
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: tok.motion.expressiveDefaultSpatial
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
                    property int tabCount: { const _ = win.searchQuery; const __ = win.previewRev; return win.filterCount(modelData.value); }

                    width: fbg.segmentWidth
                    height: fbgRow.height

                    Rectangle {
                        anchors.fill: parent
                        radius: tok.shape.full
                        color: tok.palette.fgSurface
                        opacity: segMa.pressed ? 0.08 : 0
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

                        MIcon {
                            visible: (fbgSeg.modelData.icon || "").length > 0
                            Layout.alignment: Qt.AlignVCenter
                            name: fbgSeg.modelData.icon || ""
                            size: 16
                            iconColor: fbgSeg.active
                                ? tok.palette.fgPrimary
                                : (tok.palette.isLight ? tok.palette.fgSurface : tok.palette.fgMuted)

                            Behavior on iconColor {
                                enabled: !win.reducedMotion
                                ColorAnimation { duration: tok.motion.effectsExpressive.fast }
                            }
                        }

                        Text {
                            id: segLabel
                            Layout.alignment: Qt.AlignVCenter
                            text: fbgSeg.modelData.label || ""
                            font: tok.type.labelEmph
                            color: fbgSeg.active
                                ? tok.palette.fgPrimary
                                : (tok.palette.isLight ? tok.palette.fgSurface : tok.palette.fgMuted)

                            Behavior on color {
                                enabled: !win.reducedMotion
                                ColorAnimation { duration: tok.motion.effectsExpressive.fast }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Math.max(16, countText.implicitWidth + 8)
                            implicitHeight: 16
                            radius: tok.shape.full
                            color: fbgSeg.active
                                ? Qt.rgba(255, 255, 255, 0.22)
                                : (tok.palette.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(255, 255, 255, 0.08))

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: fbgSeg.tabCount
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                font.family: tok.type.monoFamily
                                color: fbgSeg.active
                                    ? tok.palette.fgPrimary
                                    : tok.palette.fgMuted
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

    component IconButton: Item {
        id: ib
        property string icon: ""
        property string glyph: ""
        property string accessibleName: ""
        property string tone: "neutral"
        signal triggered()

        implicitWidth: 32
        implicitHeight: 32

        // Silky smooth background fade layer
        Rectangle {
            id: ibHoverBg
            anchors.fill: parent
            radius: tok.shape.full
            color: ib.tone === "error"
                ? (ibMa.pressed
                    ? Qt.darker(tok.palette.errorContainer, tok.palette.isLight ? 1.15 : 0.85)
                    : tok.palette.errorContainer)
                : (ibMa.pressed
                    ? Qt.alpha(tok.palette.fgSurface, 0.14)
                    : Qt.alpha(tok.palette.fgSurface, 0.08))
            opacity: ibMa.containsMouse || ibMa.pressed ? 1.0 : 0.0

            Behavior on opacity {
                enabled: !win.reducedMotion
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                enabled: !win.reducedMotion
                ColorAnimation { duration: 120 }
            }
        }

        MIcon {
            id: ibIcon
            anchors.centerIn: parent
            visible: ib.icon.length > 0
            name: ib.icon
            size: 18
            iconColor: ib.tone === "error"
                ? (ibMa.containsMouse || ibMa.pressed ? tok.palette.fgErrorContainer : tok.palette.error)
                : (ibMa.containsMouse ? tok.palette.fgSurface : tok.palette.fgMuted)
            scale: ibMa.pressed ? 0.90 : 1.0

            Behavior on iconColor {
                enabled: !win.reducedMotion
                ColorAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                enabled: !win.reducedMotion
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        Shape {
            id: ibIconShape
            visible: ib.icon.length === 0 && (ib.glyph === "delete" || ib.glyph === "trash")
            anchors.centerIn: parent
            width: 16
            height: 16
            layer.enabled: true
            layer.samples: 4
            scale: ibMa.pressed ? 0.90 : 1.0

            Behavior on scale {
                enabled: !win.reducedMotion
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            ShapePath {
                fillColor: ib.tone === "error"
                    ? (ibMa.containsMouse || ibMa.pressed ? tok.palette.fgErrorContainer : tok.palette.error)
                    : (ibMa.containsMouse ? tok.palette.fgSurface : tok.palette.fgMuted)
                strokeColor: "transparent"
                strokeWidth: 0
                scale: Qt.size(16 / 24, 16 / 24)
                PathSvg {
                    path: "M16 9v10H8V9h8m-1.5-6h-5l-1 1H5v2h14V4h-3.5l-1-1zM18 7H6v12c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7z"
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: ib.icon.length === 0 && !ibIconShape.visible && ib.glyph.length > 0
            text: ib.glyph
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: ib.tone === "error"
                ? (ibMa.containsMouse || ibMa.pressed ? tok.palette.fgErrorContainer : tok.palette.error)
                : (ibMa.containsMouse ? tok.palette.fgSurface : tok.palette.fgMuted)
            scale: ibMa.pressed ? 0.90 : 1.0

            Behavior on scale {
                enabled: !win.reducedMotion
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                enabled: !win.reducedMotion
                ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
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
        Accessible.name: ib.accessibleName.length > 0 ? ib.accessibleName : (ib.icon.length > 0 ? ib.icon : ib.glyph)
    }

    component PrimaryButton: Rectangle {
        id: pbtn
        property string label: ""
        property string icon: ""
        property string glyph: ""
        property string kbd: ""
        signal triggered()

        implicitHeight: 32
        implicitWidth: Math.max(76, pbtnRow.implicitWidth + 20)
        radius: tok.shape.full
        color: pMa.pressed
            ? Qt.darker(tok.palette.primary, tok.palette.isLight ? 1.15 : 1.1)
            : (pMa.containsMouse ? Qt.darker(tok.palette.primary, tok.palette.isLight ? 1.06 : 1.04) : tok.palette.primary)
        opacity: enabled ? 1 : 0.38
        scale: enabled && pMa.pressed ? 0.94 : (enabled && pMa.containsMouse ? 1.03 : 1.0)

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

            MIcon {
                visible: pbtn.icon.length > 0
                Layout.alignment: Qt.AlignVCenter
                name: pbtn.icon
                size: 16
                iconColor: tok.palette.fgPrimary
            }

            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                visible: pbtn.icon.length === 0 && pbtn.glyph.length > 0

                Text {
                    anchors.centerIn: parent
                    text: pbtn.glyph
                    font.pixelSize: 12
                    font.weight: Font.Bold
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

            KbdKey {
                visible: pbtn.kbd.length > 0
                Layout.alignment: Qt.AlignVCenter
                key: pbtn.kbd
                textColor: tok.palette.fgPrimary
                bg: "transparent"
                borderColor: "transparent"
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

        function simulateClick() {
            if (!enabled) return
            clickAnim.restart()
            triggered()
        }

        SequentialAnimation {
            id: clickAnim
            NumberAnimation { target: pbtn; property: "scale"; to: 0.90; duration: 80; easing.type: Easing.OutCubic }
            NumberAnimation { target: pbtn; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
        }
    }

    component TonalButton: Rectangle {
        id: tbtn
        property string label: ""
        property string icon: ""
        property string glyph: ""
        property string kbd: ""
        property string tone: "neutral" // neutral | error
        signal triggered()

        readonly property color _fg: {
            if (tbtn.tone === "error")
                return tok.palette.fgErrorContainer
            return tok.palette.fgSecondaryContainer
        }
        readonly property color _bg: {
            if (tbtn.tone === "error") {
                if (tMa.pressed)
                    return Qt.darker(tok.palette.errorContainer, tok.palette.isLight ? 1.15 : 0.85)
                if (tMa.containsMouse)
                    return Qt.darker(tok.palette.errorContainer, tok.palette.isLight ? 1.07 : 0.92)
                return tok.palette.errorContainer
            }
            if (tMa.pressed)
                return Qt.darker(tok.palette.secondaryContainer, tok.palette.isLight ? 1.10 : 0.88)
            if (tMa.containsMouse)
                return Qt.darker(tok.palette.secondaryContainer, tok.palette.isLight ? 1.05 : 0.94)
            return tok.palette.secondaryContainer
        }

        implicitHeight: 32
        implicitWidth: Math.max(tbtn.label.length > 0 ? 76 : 32, tbtnRow.implicitWidth + 20)
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

            MIcon {
                visible: tbtn.icon.length > 0
                Layout.alignment: Qt.AlignVCenter
                name: tbtn.icon
                size: 16
                iconColor: tbtn._fg
            }

            Item {
                Layout.preferredWidth: tbtn.glyph.length > 0 ? 20 : 0
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                visible: tbtn.icon.length === 0 && tbtn.glyph.length > 0

                Text {
                    anchors.centerIn: parent
                    text: tbtn.glyph
                    font.pixelSize: tbtn.glyph.length > 1 ? 11 : 13
                    font.weight: Font.DemiBold
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

            KbdKey {
                visible: tbtn.kbd.length > 0
                Layout.alignment: Qt.AlignVCenter
                key: tbtn.kbd
                textColor: tbtn._fg
                bg: "transparent"
                borderColor: "transparent"
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

        function simulateClick() {
            if (!enabled) return
            clickAnim.restart()
            triggered()
        }

        SequentialAnimation {
            id: clickAnim
            NumberAnimation { target: tbtn; property: "scale"; to: 0.90; duration: 80; easing.type: Easing.OutCubic }
            NumberAnimation { target: tbtn; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
        }
    }

    // Compact kbd hint chip for footer shortcuts — solid M3 surface
    component KbdHint: Item {
        id: kh
        property string keys: ""
        property string caption: ""

        readonly property bool isLeftRight: kh.keys === "←→"
        readonly property bool isUpDown: kh.keys === "↑↓"

        implicitHeight: 22
        implicitWidth: khRow.implicitWidth

        RowLayout {
            id: khRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            // Arrow keycaps or single keycap
            Row {
                spacing: 3
                Layout.alignment: Qt.AlignVCenter

                // First keycap
                Rectangle {
                    width: (kh.isLeftRight || kh.isUpDown) ? 22 : Math.max(22, keyLbl.implicitWidth + 8)
                    height: 22
                    radius: 5
                    color: tok.palette.isLight ? tok.palette.stageContent : tok.palette.stageHigh
                    border.width: 0

                    MIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 1
                        visible: kh.isLeftRight
                        name: "arrow_back"
                        size: 15
                        weight: 600
                        iconColor: tok.palette.fgSurface
                    }

                    MIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 1
                        visible: kh.isUpDown
                        name: "arrow_upward"
                        size: 15
                        weight: 600
                        iconColor: tok.palette.fgSurface
                    }

                    Text {
                        id: keyLbl
                        anchors.centerIn: parent
                        visible: !kh.isLeftRight && !kh.isUpDown
                        text: kh.keys
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.family: tok.type.monoFamily
                        font.hintingPreference: Font.PreferFullHinting
                        renderType: Text.NativeRendering
                        color: tok.palette.fgSurface
                    }
                }

                // Second keycap (for arrow pairs)
                Rectangle {
                    visible: kh.isLeftRight || kh.isUpDown
                    width: 22
                    height: 22
                    radius: 5
                    color: tok.palette.isLight ? tok.palette.stageContent : tok.palette.stageHigh
                    border.width: 0

                    MIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 1
                        visible: kh.isLeftRight
                        name: "arrow_forward"
                        size: 15
                        weight: 600
                        iconColor: tok.palette.fgSurface
                    }

                    MIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 1
                        visible: kh.isUpDown
                        name: "arrow_downward"
                        size: 15
                        weight: 600
                        iconColor: tok.palette.fgSurface
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: kh.caption
                font: tok.type.label
                color: tok.palette.fgSurface
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

        property real rowRevealOpacity: win.reducedMotion ? 1.0 : 0.0
        property real rowRevealScale: win.reducedMotion ? 1.0 : 0.94
        property real rowRevealY: win.reducedMotion ? 0.0 : 12.0

        opacity: rowRevealOpacity
        scale: rowRevealScale
        transform: Translate { y: row.rowRevealY }

        Timer {
            id: rowStaggerTimer
            interval: Math.min(row.index * 26, 220)
            running: false
            repeat: false
            onTriggered: rowRevealAnim.start()
        }

        ParallelAnimation {
            id: rowRevealAnim
            NumberAnimation {
                target: row
                property: "rowRevealOpacity"
                to: 1.0
                duration: 200
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: row
                property: "rowRevealY"
                to: 0.0
                duration: 240
                easing.type: Easing.OutBack
                easing.overshoot: 1.35
            }
            NumberAnimation {
                target: row
                property: "rowRevealScale"
                to: 1.0
                duration: 240
                easing.type: Easing.OutBack
                easing.overshoot: 1.35
            }
        }

        Component.onCompleted: {
            if (row.isImage && (!row.imagePath || row.imagePath.length === 0))
                win.requestDecodeClipImageById(row.entryId)
            if (!win.reducedMotion && row.index < 12)
                rowStaggerTimer.start()
            else {
                rowRevealOpacity = 1.0
                rowRevealScale = 1.0
                rowRevealY = 0.0
            }
        }

        onEntryIdChanged: {
            if (row.isImage && (!row.imagePath || row.imagePath.length === 0))
                win.requestDecodeClipImageById(row.entryId)
        }

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
            scale: rowMa.pressed ? 0.94 : 1.0
            transformOrigin: Item.Center

            Behavior on scale {
                enabled: !win.reducedMotion
                SpringAnimation {
                    spring: rowMa.pressed ? 5.5 : 4.4
                    damping: rowMa.pressed ? 0.60 : 0.68
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
                radius: tok.shape.md
                color: {
                    if (row.isCurrent)
                        return "transparent"
                    if (rowHover.hovered)
                        return Qt.alpha(tok.palette.fgSurface, tok.palette.isLight ? 0.07 : 0.09)
                    return "transparent"
                }
                border.width: 0
                border.color: "transparent"

                Behavior on color {
                    enabled: !win.reducedMotion
                    ColorAnimation {
                        duration: tok.motion.effectsExpressive.fast
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 44
                spacing: 10
                z: 1

                // Leading text icon container — perfectly matches 38x38 image thumbnail
                Rectangle {
                    visible: !row.isImage
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    Layout.alignment: Qt.AlignVCenter
                    radius: tok.shape.md
                    color: row.isCurrent
                        ? tok.palette.primaryContainer
                        : (tok.palette.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.06))

                    MIcon {
                        anchors.centerIn: parent
                        name: "notes"
                        size: 18
                        iconColor: row.isCurrent
                            ? tok.palette.fgPrimaryContainer
                            : tok.palette.fgMuted
                    }
                }

                // Image thumb — masked rounded rectangle, filled with cropped aspect
                Item {
                    id: thumbWrap
                    visible: row.isImage
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    Layout.alignment: Qt.AlignVCenter

                    // Mask shape with layer.enabled
                    Item {
                        id: thumbMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        Rectangle {
                            anchors.fill: parent
                            radius: tok.shape.md
                            color: "white"
                            antialiasing: true
                            smooth: true
                        }
                    }

                    // Placeholder background with icon
                    Rectangle {
                        anchors.fill: parent
                        radius: tok.shape.md
                        color: tok.palette.primaryContainer
                        border.width: 0

                        MIcon {
                            anchors.centerIn: parent
                            visible: thumbImg.status !== Image.Ready
                            name: "image"
                            size: 18
                            iconColor: tok.palette.fgPrimaryContainer
                        }
                    }

                    // Source image with layer.effect MultiEffect
                    Image {
                        id: thumbImg
                        anchors.fill: parent
                        source: {
                            const _rev = win.imageRev
                            return (row.imagePath && row.imagePath.length > 0)
                                ? ("file://" + row.imagePath) : ""
                        }
                        sourceSize: Qt.size(76, 76)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        opacity: status === Image.Ready ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            enabled: !win.reducedMotion
                            NumberAnimation { duration: tok.motion.effectsExpressive.fast }
                        }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: thumbMask
                            maskSpreadAtMin: 1
                            maskThresholdMin: 0.5
                        }
                    }
                }

                // Image two-line metadata hierarchy
                ColumnLayout {
                    id: imageMetaCol
                    visible: row.isImage
                    Layout.fillWidth: true
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    readonly property var meta: win.parseImageMetadata(row.entryPreview)

                    Text {
                        Layout.fillWidth: true
                        text: (imageMetaCol.meta && imageMetaCol.meta.title) ? imageMetaCol.meta.title : qsTr("Image")
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: row.isCurrent
                            ? tok.palette.fgSecondaryContainer
                            : (tok.palette.isLight ? tok.palette.fgSurface : tok.palette.fgMuted)
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: (imageMetaCol.meta && imageMetaCol.meta.subtitle) ? imageMetaCol.meta.subtitle : ""
                            font.pixelSize: 11
                            font.family: tok.type.monoFamily
                            color: tok.palette.fgMuted
                            opacity: 0.65
                            elide: Text.ElideRight
                        }

                        Text {
                            text: "•"
                            font.pixelSize: 9
                            color: tok.palette.fgMuted
                            opacity: 0.4
                        }

                        Text {
                            text: "#" + row.entryId
                            font.pixelSize: 11
                            font.family: tok.type.monoFamily
                            color: tok.palette.fgMuted
                            opacity: 0.65
                        }
                    }
                }

                // Text two-line hierarchy (Line 1: snippet; Line 2: #ID • count)
                ColumnLayout {
                    visible: !row.isImage
                    Layout.fillWidth: true
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        Layout.fillWidth: true
                        textFormat: win.searchQuery.trim().length > 0 ? Text.RichText : Text.PlainText
                        text: {
                            if (!win.searchQuery || win.searchQuery.trim().length === 0)
                                return row.entryPreview
                            return win.highlightQuery(row.entryPreview, win.searchQuery, tok.palette.primary)
                        }
                        font: row.isCurrent ? tok.type.bodyEmph : tok.type.body
                        color: row.isCurrent
                            ? tok.palette.fgSecondaryContainer
                            : (tok.palette.isLight ? tok.palette.fgSurface : tok.palette.fgMuted)
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "#" + row.entryId
                            font.pixelSize: 11
                            font.family: tok.type.monoFamily
                            color: tok.palette.fgMuted
                            opacity: 0.65
                        }

                        Text {
                            text: "•"
                            font.pixelSize: 9
                            color: tok.palette.fgMuted
                            opacity: 0.4
                        }

                        Text {
                            text: qsTr("%1 chars").arg(row.entryText ? row.entryText.length : (row.entryPreview ? row.entryPreview.length : 0))
                            font.pixelSize: 11
                            font.family: tok.type.monoFamily
                            color: tok.palette.fgMuted
                            opacity: 0.65
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Accessible.role: Accessible.ListItem
        Accessible.name: row.entryPreview
    }

    // ── Logic (search & formatting) ───────────────────────────────────────────

    function escapeHtml(str) {
        if (!str) return ""
        return String(str)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;")
    }

    function highlightQuery(text, q, accentColor) {
        if (!text) return ""
        if (!q || !q.trim())
            return escapeHtml(text)

        const accentHex = accentColor ? (accentColor.toString ? accentColor.toString() : String(accentColor)) : (tok.palette.isLight ? tok.palette.primary.toString() : "#a8c7fa")
        const rawTerms = q.trim().split(/\s+/).filter(t => t.length > 0)
        if (rawTerms.length === 0)
            return escapeHtml(text)

        const sortedTerms = rawTerms.slice().sort((a, b) => b.length - a.length)
        const escapedTerms = sortedTerms.map(t => t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
        const regex = new RegExp("(" + escapedTerms.join("|") + ")", "gi")

        let result = ""
        let lastIndex = 0
        let m
        while ((m = regex.exec(text)) !== null) {
            if (m.index > lastIndex) {
                result += escapeHtml(text.slice(lastIndex, m.index))
            }
            result += '<font color="' + accentHex + '"><b>' + escapeHtml(m[0]) + '</b></font>'
            lastIndex = m.index + m[0].length
            if (regex.lastIndex === m.index)
                regex.lastIndex++
        }
        if (lastIndex < text.length) {
            result += escapeHtml(text.slice(lastIndex))
        }
        return result
    }

    function cleanImagePreview(raw) {
        if (!raw || raw.length === 0) return qsTr("Image clip")
        const m = raw.match(/\[\[\s*binary data\s*(.*?)\s*\]\]/)
        if (m && m[1]) {
            const info = m[1].trim()
            return info.length > 0 ? (info + " • Image") : qsTr("Image clip")
        }
        return raw
    }

    function parseImageMetadata(raw) {
        if (!raw || raw.length === 0)
            return { title: qsTr("Image"), subtitle: "" }
        let inner = raw
        const mBin = raw.match(/\[\[\s*binary data\s*(.*?)\s*\]\]/)
        if (mBin && mBin[1]) inner = mBin[1].trim()

        const match = inner.match(/([\d.]+\s*(?:[KkMmGg]i?[Bb]|bytes))\s+([a-zA-Z0-9]+)\s+(\d+)\s*[xX×]\s*(\d+)/)
        if (match) {
            const size = match[1].replace(/KiB/i, "KB").replace(/MiB/i, "MB")
            const ext = match[2].toUpperCase()
            const dim = match[3] + " × " + match[4]
            return {
                title: qsTr("Image (%1)").arg(dim),
                subtitle: ext + " • " + size
            }
        }
        const matchNoDim = inner.match(/([\d.]+\s*(?:[KkMmGg]i?[Bb]|bytes))\s+([a-zA-Z0-9]+)/)
        if (matchNoDim) {
            const size = matchNoDim[1].replace(/KiB/i, "KB").replace(/MiB/i, "MB")
            const ext = matchNoDim[2].toUpperCase()
            return {
                title: qsTr("Image"),
                subtitle: ext + " • " + size
            }
        }
        return { title: qsTr("Image"), subtitle: inner }
    }

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
        if (parsed && parsed.length > 0) {
            for (let i = 0; i < parsed.length; i++) {
                const id = parsed[i].entryId
                if (id && decodedTextCache[id]) {
                    parsed[i].entryText = decodedTextCache[id]
                    parsed[i].decoded = true
                }
            }
            return parsed
        }

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
            const cachedText = decodedTextCache[entryId]
            built.push({
                entryId: entryId,
                entryPreview: entryPreview,
                entryRaw: entry,
                entryText: cachedText ? cachedText : entryPreview,
                isImage: Cliphist.entryIsImage(entry),
                imagePath: "",
                decoded: !!cachedText,
                edited: false
            })
        }
        return built
    }

    function searchScore(it, q, terms) {
        const preview = (it.entryPreview || "").toLowerCase()
        const raw = (it.entryRaw || "").toLowerCase()
        const id = (it.entryId || "").toLowerCase()
        const full = (it.entryText || "").toLowerCase()
        const blob = id + " #" + id + " " + preview + " " + raw + " " + full

        for (let i = 0; i < terms.length; i++) {
            if (blob.indexOf(terms[i]) === -1)
                return -1
        }

        let score = 0
        if (preview === q || full === q)
            score += 1000
        else if (preview.startsWith(q) || full.startsWith(q))
            score += 500
        else if (preview.indexOf(q) !== -1)
            score += 200 - Math.min(100, preview.indexOf(q))

        if (id === q)
            score += 800
        else if (id.indexOf(q) === 0)
            score += 400

        for (let i = 0; i < terms.length; i++) {
            const t = terms[i]
            const pos = preview.indexOf(t)
            if (pos === 0)
                score += 60
            else if (pos > 0) {
                const prevChar = preview[pos - 1]
                if (prevChar === " " || prevChar === "/" || prevChar === "." || prevChar === "-" || prevChar === "_")
                    score += 40
            }
        }

        return score
    }

    function filteredCliphistItems() {
        const items = cliphistItems()
        const q = searchQuery.trim().toLowerCase()
        const terms = q.length > 0 ? q.split(/\s+/).filter(t => t.length > 0) : []
        const out = []

        for (let i = 0; i < items.length; i++) {
            const it = items[i]
            if (filterMode === "text" && it.isImage) continue
            if (filterMode === "image" && !it.isImage) continue

            if (terms.length === 0) {
                out.push(it)
                continue
            }

            const score = searchScore(it, q, terms)
            if (score >= 0) {
                out.push({ item: it, score: score, origIndex: i })
            }
        }

        if (terms.length > 0) {
            out.sort((a, b) => {
                if (b.score !== a.score)
                    return b.score - a.score
                return a.origIndex - b.origIndex
            })
            return out.map(o => o.item)
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
        selectedIndex = 0
        rebuildClipList()
        previewRev++
        filteredHistoryChanged()
        syncPreviewText()
        if (listView) {
            Qt.callLater(function() {
                listView.positionViewAtBeginning()
                syncListSelection()
            })
        }
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

    function requestDecodeClipImageById(entryId) {
        if (!entryId || entryId.length === 0)
            return
        if (typeof Cliphist === "undefined" || !Cliphist)
            return
        if (typeof Cliphist.requestDecodeImageById !== "function")
            return
        Cliphist.requestDecodeImageById(entryId, clipImagePath(entryId))
    }

    function requestDecodeClipImage(listIndex) {
        if (listIndex < 0 || listIndex >= clipListModel.count)
            return
        const item = clipListModel.get(listIndex)
        if (!item || !item.isImage)
            return
        if (item.imagePath && item.imagePath.length > 0)
            return
        requestDecodeClipImageById(item.entryId)
    }

    function applyDecodedText(entryId, fullText) {
        if (!entryId || !fullText)
            return
        decodedTextCache[entryId] = fullText
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
            if (clip && clip.isImage && (!clip.imagePath || clip.imagePath.length === 0)) {
                requestDecodeClipImageById(clip.entryId)
            }
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
        decodedTextCache[activeClip.entryId] = previewEditText
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
        } else if (win.previewEditText && win.previewEditText.length > 0) {
            Cliphist.copyText(win.previewEditText)
        } else {
            Cliphist.copy(item.entryRaw)
        }
        win.close()
    }

    function deleteSelected() {
        if (!clipListModel.count) return
        const idx = selectedIndex
        const item = clipListModel.get(idx)
        if (!item) return
        busy = true
        clipListModel.remove(idx)
        if (clipListModel.count > 0)
            selectedIndex = Math.min(idx, clipListModel.count - 1)
        else
            selectedIndex = 0
        bumpPreview()
        syncListSelection()
        Cliphist.deleteEntry(item.entryRaw)
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
            close()
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

        if (!clipListModel.count && (!event.text || event.text.length === 0))
            return

        if (event.key === Qt.Key_E && (event.modifiers & Qt.ControlModifier) && activeClip && !activeClip.isImage && !previewEditing) {
            beginPreviewEdit()
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Up) { moveSelection(-1); event.accepted = true; return }
        else if (event.key === Qt.Key_Down) { moveSelection(1); event.accepted = true; return }
        else if (event.key === Qt.Key_Home) {
            if (!searchField.activeFocus) { jumpSelection(0); event.accepted = true; return }
        }
        else if (event.key === Qt.Key_End) {
            if (!searchField.activeFocus) { jumpSelection(clipListModel.count - 1); event.accepted = true; return }
        }
        else if (event.key === Qt.Key_PageUp) {
            moveSelection(-Math.max(1, Math.floor(listView.height / 48))); event.accepted = true; return
        } else if (event.key === Qt.Key_PageDown) {
            moveSelection(Math.max(1, Math.floor(listView.height / 48))); event.accepted = true; return
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            win.copySelected(); event.accepted = true; return
        }
        else if (event.key === Qt.Key_Delete) {
            if (!searchField.activeFocus) { deleteSelected(); event.accepted = true; return }
        }
        else if (event.key === Qt.Key_Backspace) {
            if (!searchField.activeFocus || searchField.text.length === 0) {
                deleteSelected()
                event.accepted = true
                return
            }
        }

        // If user is typing normal printable text and searchField isn't focused, forward to searchField
        if (!searchField.activeFocus && event.text && event.text.length > 0 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            searchField.forceActiveFocus()
            searchField.text += event.text
            searchField.cursorPosition = searchField.text.length
            event.accepted = true
            return
        }
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
        const q = searchQuery.trim().toLowerCase()
        const terms = q.length > 0 ? q.split(/\s+/).filter(t => t.length > 0) : []
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (mode === "text" && item.isImage) continue
            if (mode === "image" && !item.isImage) continue
            if (terms.length > 0 && searchScore(item, q, terms) < 0) continue
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
        enabled: !previewEditing && clipListModel.count > 0 && !searchField.activeFocus
        onActivated: moveSelection(-1)
    }
    Shortcut {
        sequence: "Down"
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0 && !searchField.activeFocus
        onActivated: moveSelection(1)
    }
    Shortcut {
        sequences: ["Home", StandardKey.MoveToStartOfDocument]
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0 && !searchField.activeFocus
        onActivated: jumpSelection(0)
    }
    Shortcut {
        sequences: ["End", StandardKey.MoveToEndOfDocument]
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0 && !searchField.activeFocus
        onActivated: jumpSelection(clipListModel.count - 1)
    }
    Shortcut {
        sequences: ["PgUp", StandardKey.MoveToPreviousPage]
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0 && !searchField.activeFocus
        onActivated: moveSelection(-Math.max(1, Math.floor(listView.height / 48)))
    }
    Shortcut {
        sequences: ["PgDown", StandardKey.MoveToNextPage]
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0 && !searchField.activeFocus
        onActivated: moveSelection(Math.max(1, Math.floor(listView.height / 48)))
    }
    Shortcut {
        sequence: "Delete"
        context: Qt.WindowShortcut
        enabled: !previewEditing && clipListModel.count > 0 && !searchField.activeFocus
        onActivated: deleteSelected()
    }

    Component.onCompleted: {
        if (!reducedMotion) {
            shellEntrance.start()
        } else {
            shellOpacity = 1
            shellScale = 1
        }
        searchField.forceActiveFocus(Qt.ShortcutFocusReason)
        if (typeof Cliphist !== "undefined" && Cliphist)
            refreshHistory()
    }

    ParallelAnimation {
        id: shellEntrance
        running: false
        NumberAnimation {
            target: win
            property: "shellScale"
            from: 0.94
            to: 1.0
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }
        NumberAnimation {
            target: win
            property: "shellOpacity"
            from: 0.0
            to: 1.0
            duration: 180
            easing.type: Easing.OutCubic
        }
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
                    color: "#FFFFFF"
                    text: (SystemAccent.wallpaperSource || "no wallpaper")
                        + " | mode: " + (SystemAccent.schemeMode || "auto")
                        + " | primary: " + SystemAccent.primary
                        + " | " + (SystemAccent.schemeName || "extracting…")
                }
            }

            Behavior on opacity {
                enabled: !win.reducedMotion
                NumberAnimation { duration: tok.motion.effectsExpressive.defaultMs; easing.type: Easing.OutCubic }
            }



            // Unified main card — clean surface, corner roundness handled by Hyprland
            Rectangle {
                id: mainCard
                anchors.fill: parent
                radius: 0
                color: tok.palette.isLight
                    ? (tok.palette.stageContent.isValid ? Qt.darker(tok.palette.stageContent, 1.02) : "#D6E0DE")
                    : Qt.rgba(0.05, 0.05, 0.08, 0.94)
                border.width: 0
                border.color: "transparent"
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    // ═══ LEFT RAIL — command + timeline ═══════════════════════════
                    Rectangle {
                        id: rail
                        Layout.preferredWidth: 380
                        Layout.fillHeight: true
                        radius: tok.shape.lg
                        color: tok.palette.isLight
                            ? "#FFFFFF"
                            : Qt.rgba(0.12, 0.12, 0.16, 0.96)
                        clip: true
                        border.width: 0

                        ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Layout.bottomMargin: 2

                            // Leading icon badge
                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: tok.shape.md
                                color: tok.palette.primaryContainer

                                MIcon {
                                    anchors.centerIn: parent
                                    name: "content_paste"
                                    size: 20
                                    iconColor: tok.palette.fgPrimaryContainer
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: qsTr("Clipboard")
                                    font: tok.type.titleEmph
                                    color: tok.palette.fgSurface
                                }

                                Text {
                                    id: statusLbl
                                    text: {
                                        if (statusMessage.length > 0)
                                            return statusMessage
                                        const c = clipListModel.count
                                        return c === 0 ? qsTr("No items") : (c === 1 ? qsTr("1 item") : qsTr("%1 items").arg(c))
                                    }
                                    font: tok.type.label
                                    color: tok.palette.fgMuted
                                    opacity: 0.75

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
                                            to: 0.35
                                            duration: win.reducedMotion ? 1 : 80
                                        }
                                        NumberAnimation {
                                            target: statusLbl
                                            property: "opacity"
                                            to: 0.75
                                            duration: win.reducedMotion ? 1 : 160
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }

                            // Clear history
                            TonalButton {
                                Layout.alignment: Qt.AlignVCenter
                                label: qsTr("Clear")
                                icon: ""
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

                        // Command search — illuminated M3 glassmorphic field
                        Rectangle {
                            id: searchBox
                            Layout.fillWidth: true
                            property int boxHeight: 44
                            Layout.preferredHeight: boxHeight
                            radius: tok.shape.full
                            color: searchField.activeFocus
                                ? (tok.palette.isLight ? "#E2ECE9" : Qt.alpha(tok.palette.fgSurface, 0.12))
                                : (tok.palette.isLight ? "#EDF3F1" : Qt.alpha(tok.palette.fgSurface, 0.065))
                            border.width: 0
                            border.color: "transparent"

                            HoverHandler {
                                cursorShape: Qt.IBeamCursor
                            }

                            TapHandler {
                                onTapped: searchField.forceActiveFocus(Qt.MouseFocusReason)
                            }

                            Behavior on color {
                                ColorAnimation { duration: tok.motion.effectsExpressive.fast }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 8

                                MIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    name: "search"
                                    size: 18
                                    iconColor: searchField.activeFocus
                                        ? tok.palette.primary
                                        : tok.palette.fgMuted

                                    Behavior on iconColor {
                                        enabled: !win.reducedMotion
                                        ColorAnimation { duration: tok.motion.effectsExpressive.fast }
                                    }
                                }

                                TextField {
                                    id: searchField
                                    Layout.fillWidth: true
                                    placeholderText: qsTr("Search or jump…")
                                    text: searchQuery
                                    font: tok.type.body
                                    color: tok.palette.fgSurface
                                    placeholderTextColor: tok.palette.fgMuted
                                    selectByMouse: true
                                    background: Item {}

                                    HoverHandler {
                                        cursorShape: Qt.IBeamCursor
                                    }
                                    onTextChanged: {
                                        if (searchQuery !== text) {
                                            searchQuery = text
                                            applyFilter()
                                        }
                                    }
                                    Keys.priority: Keys.BeforeItem
                                    Keys.onPressed: function(event) {
                                        if (win.handleFilterArrow(event))
                                            return
                                        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            win.handleKey(event)
                                            return
                                        }
                                        if (event.key === Qt.Key_Escape) {
                                            win.handleEscape()
                                            event.accepted = true
                                            return
                                        }
                                    }
                                }

                                Row {
                                    visible: searchField.text.length === 0
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 3

                                    KbdKey { key: "Ctrl" }
                                    KbdKey { key: "K" }
                                }

                                IconButton {
                                    opacity: searchField.text.length > 0 ? 1 : 0
                                    visible: opacity > 0
                                    icon: "close"
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
                            Layout.preferredHeight: 36
                            z: 2
                            clip: true

                            FilterButtonGroup {
                                id: filterSeg
                                anchors.fill: parent
                                current: win.filterIndexForMode(filterMode)
                                options: [
                                    { label: qsTr("All"), value: "all", icon: "view_list" },
                                    { label: qsTr("Text"), value: "text", icon: "notes" },
                                    { label: qsTr("Images"), value: "image", icon: "image" }
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
                                spacing: 8
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

                                MIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    name: "search_off"
                                    size: 36
                                    iconColor: tok.palette.fgMuted
                                    opacity: 0.45
                                }

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
                                    color: "transparent"
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
                                    radius: tok.shape.md
                                    color: tok.palette.secondaryContainer
                                    border.width: 0

                                    // Left 3px accent indicator bar
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 5
                                        anchors.top: parent.top
                                        anchors.topMargin: 8
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 8
                                        width: 3
                                        radius: 1.5
                                        color: tok.palette.primary
                                    }
                                }
                            }

                            ListView {
                                id: listView
                                z: 1
                                anchors.fill: parent
                                topMargin: 2
                                bottomMargin: 16
                                clip: true
                                model: clipListModel
                                spacing: 8
                                boundsBehavior: Flickable.DragAndOvershootBounds
                                flickDeceleration: 2200
                                maximumFlickVelocity: 3200
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

                                // Fluid Momentum Wheel Physics (StyledListView / AppList architecture — DESIGN.md Pillar A)
                                readonly property real scrollLineStep: 48
                                readonly property real scrollLinesPerNotch: 3
                                readonly property real scrollStep: scrollLineStep * scrollLinesPerNotch
                                readonly property int wheelAnimMs: 280
                                property real touchpadVelocity: 0

                                NumberAnimation {
                                    id: smoothScrollAnim
                                    target: listView
                                    property: "contentY"
                                    duration: listView.wheelAnimMs
                                    easing.type: Easing.OutCubic
                                    onStopped: listView.checkOverscrollBounds()
                                }

                                SpringAnimation {
                                    id: bounceBackSpring
                                    target: listView
                                    property: "contentY"
                                    spring: 4.8
                                    damping: 0.70
                                    epsilon: 0.15
                                }

                                Timer {
                                    id: touchpadReleaseTimer
                                    interval: 85
                                    repeat: false
                                    onTriggered: listView.checkOverscrollBounds()
                                }

                                onDraggingChanged: {
                                    if (dragging) {
                                        smoothScrollAnim.stop()
                                        bounceBackSpring.stop()
                                        touchpadReleaseTimer.stop()
                                        touchpadVelocity = 0
                                    }
                                }
                                onFlickEnded: checkOverscrollBounds()
                                onMovementEnded: checkOverscrollBounds()

                                function checkOverscrollBounds() {
                                    const maxScroll = Math.max(0, contentHeight - height)
                                    if (contentY < 0) {
                                        smoothScrollAnim.stop()
                                        bounceBackSpring.stop()
                                        bounceBackSpring.from = contentY
                                        bounceBackSpring.to = 0
                                        bounceBackSpring.start()
                                    } else if (contentY > maxScroll) {
                                        smoothScrollAnim.stop()
                                        bounceBackSpring.stop()
                                        bounceBackSpring.from = contentY
                                        bounceBackSpring.to = maxScroll
                                        bounceBackSpring.start()
                                    }
                                }

                                function clampScrollY(y) {
                                    const maxScroll = Math.max(0, contentHeight - height)
                                    return Math.max(0, Math.min(maxScroll, y))
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
                                        bounceBackSpring.stop()
                                        if (!win.reducedMotion) {
                                            smoothScrollAnim.stop()
                                            smoothScrollAnim.duration = listView.wheelAnimMs
                                            smoothScrollAnim.from = contentY
                                            smoothScrollAnim.to = targetY
                                            smoothScrollAnim.start()
                                        } else {
                                            contentY = targetY
                                        }
                                    }
                                }

                                ScrollBar.vertical: ScrollBar {
                                    id: listScrollBar
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle {
                                        implicitWidth: 4
                                        radius: 2
                                        color: tok.palette.isLight ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(255, 255, 255, 0.28)
                                        opacity: (listScrollBar.hovered || listScrollBar.pressed || listView.moving) ? 1 : 0
                                        Behavior on opacity {
                                            NumberAnimation { duration: 150 }
                                        }
                                    }
                                }

                                WheelHandler {
                                    id: smoothScrollHandler
                                    target: null
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    onWheel: event => {
                                        const delta = event.angleDelta.y
                                        const pDelta = event.pixelDelta ? event.pixelDelta.y : 0
                                        if (!delta && !pDelta)
                                            return

                                        const effectiveDelta = delta !== 0 ? delta : (pDelta * 4)
                                        const maxScroll = Math.max(0, listView.contentHeight - listView.height)
                                        const isDiscrete = Math.abs(effectiveDelta) >= 120
                                        const direction = effectiveDelta > 0 ? -1 : 1

                                        if (isDiscrete) {
                                            // Discrete mouse wheel notch: fluid momentum step (AppList physics)
                                            bounceBackSpring.stop()
                                            touchpadReleaseTimer.stop()
                                            listView.touchpadVelocity = 0

                                            const step = listView.scrollStep
                                            const base = smoothScrollAnim.running ? smoothScrollAnim.to : listView.contentY
                                            let nextTarget = base + direction * step

                                            // Allow elastic overscroll bounce up to 36px past edge limits
                                            const maxOvershoot = 36
                                            if (nextTarget < -maxOvershoot) {
                                                nextTarget = -maxOvershoot
                                            } else if (nextTarget > maxScroll + maxOvershoot) {
                                                nextTarget = maxScroll + maxOvershoot
                                            }

                                            smoothScrollAnim.stop()
                                            smoothScrollAnim.duration = listView.wheelAnimMs
                                            smoothScrollAnim.from = listView.contentY
                                            smoothScrollAnim.to = nextTarget
                                            smoothScrollAnim.start()
                                        } else {
                                            // Smooth pixel touchpad scrolling with elastic edge resistance
                                            smoothScrollAnim.stop()
                                            bounceBackSpring.stop()

                                            let dy = pDelta !== 0 ? -pDelta : -effectiveDelta * 0.65
                                            listView.touchpadVelocity = dy

                                            let newY = listView.contentY + dy
                                            if (newY < 0) {
                                                newY = listView.contentY + dy * 0.35
                                            } else if (newY > maxScroll) {
                                                newY = listView.contentY + dy * 0.35
                                            }

                                            listView.contentY = newY
                                            touchpadReleaseTimer.restart()
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
                                x: Math.round(listFocusMarker.x + listFocusMarker.width - width - 8)
                                y: Math.round(listFocusMarker.y + (listFocusMarker.height - height) / 2)
                                opacity: listFocusMarker.active ? 1 : 0
                                visible: opacity > 0.01
                                enabled: listFocusMarker.active
                                icon: "delete"
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
                        radius: tok.shape.lg
                        color: tok.palette.isLight
                            ? "#FFFFFF"
                            : Qt.rgba(0.12, 0.12, 0.16, 0.96)
                        clip: true
                        border.width: 0

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            // Top preview canvas area
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.margins: 16
                                spacing: 12
                                visible: win.hasClips

                                // Preview meta header
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
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

                                    // ID tag badge
                                    Rectangle {
                                        implicitWidth: metaIdRow.implicitWidth + 14
                                        implicitHeight: 22
                                        radius: tok.shape.full
                                        color: tok.palette.primaryContainer
                                        border.width: 0

                                        Row {
                                            id: metaIdRow
                                            anchors.centerIn: parent
                                            spacing: 3

                                            MIcon {
                                                anchors.verticalCenter: parent.verticalCenter
                                                name: "tag"
                                                size: 12
                                                iconColor: tok.palette.fgPrimaryContainer
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: activeClip ? activeClip.entryId : ""
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                font.family: tok.type.monoFamily
                                                color: tok.palette.fgPrimaryContainer
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }

                                    // Image type badge
                                    Rectangle {
                                        opacity: activeClip && activeClip.isImage ? 1 : 0
                                        visible: opacity > 0
                                        implicitWidth: metaTypeImgRow.implicitWidth + 14
                                        implicitHeight: 22
                                        radius: tok.shape.full
                                        color: tok.palette.tertiaryContainer
                                        border.width: 0

                                        RowLayout {
                                            id: metaTypeImgRow
                                            anchors.centerIn: parent
                                            spacing: 4

                                            MIcon {
                                                name: "image"
                                                size: 13
                                                iconColor: tok.palette.fgTertiaryContainer
                                            }

                                            Text {
                                                text: qsTr("Image")
                                                font: tok.type.label
                                                color: tok.palette.fgTertiaryContainer
                                            }
                                        }
                                    }

                                    // Text type badge
                                    Rectangle {
                                        opacity: activeClip && !activeClip.isImage ? 1 : 0
                                        visible: opacity > 0
                                        implicitWidth: metaTypeTextRow.implicitWidth + 14
                                        implicitHeight: 22
                                        radius: tok.shape.full
                                        color: tok.palette.secondaryContainer
                                        border.width: 0

                                        RowLayout {
                                            id: metaTypeTextRow
                                            anchors.centerIn: parent
                                            spacing: 4

                                            MIcon {
                                                name: "notes"
                                                size: 13
                                                iconColor: tok.palette.fgSecondaryContainer
                                            }

                                            Text {
                                                text: qsTr("Text")
                                                font: tok.type.label
                                                color: tok.palette.fgSecondaryContainer
                                            }
                                        }
                                    }

                                    // Edited status badge
                                    Rectangle {
                                        opacity: activeClip && activeClip.edited ? 1 : 0
                                        visible: opacity > 0
                                        implicitWidth: editedRow.implicitWidth + 14
                                        implicitHeight: 22
                                        radius: tok.shape.full
                                        color: tok.palette.primaryContainer
                                        border.width: 0

                                        RowLayout {
                                            id: editedRow
                                            anchors.centerIn: parent
                                            spacing: 4

                                            MIcon {
                                                name: "edit"
                                                size: 12
                                                iconColor: tok.palette.fgPrimaryContainer
                                            }

                                            Text {
                                                text: qsTr("Edited")
                                                font: tok.type.labelEmph
                                                color: tok.palette.fgPrimaryContainer
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: {
                                            if (!activeClip || activeClip.isImage || !activeClip.entryText) return ""
                                            const lines = activeClip.entryText.split("\n").length
                                            return qsTr("%1 lines • %2 chars").arg(lines).arg(activeClip.entryText.length)
                                        }
                                        font: tok.type.mono
                                        color: tok.palette.fgMuted
                                        opacity: activeClip && !activeClip.isImage ? 0.75 : 0
                                        visible: opacity > 0
                                    }
                                }

                                // Preview content
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
                                                spacing: 0

                                                Rectangle {
                                                    id: previewEditFrame
                                                    property bool isHovered: false

                                                    // Handle click-to-edit in view mode (disabled in edit mode so text selection works)
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        z: 10
                                                        visible: !win.previewEditing
                                                        enabled: !win.previewEditing
                                                        hoverEnabled: true
                                                        cursorShape: Qt.IBeamCursor
                                                        onClicked: win.beginPreviewEdit()
                                                    }

                                                    HoverHandler {
                                                        id: previewFrameHover
                                                        cursorShape: Qt.IBeamCursor
                                                        onHoveredChanged: previewEditFrame.isHovered = hovered
                                                    }

                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    Layout.minimumHeight: 140
                                                    radius: tok.shape.md
                                                    color: tok.palette.isLight
                                                        ? (tok.palette.stage.isValid ? tok.palette.stage : "#E7F0EE")
                                                        : Qt.alpha(tok.palette.fgSurface, 0.055)
                                                    border.width: 0
                                                    border.color: "transparent"
                                                    clip: true

                                                    ColumnLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 0
                                                        spacing: 0

                                                        RowLayout {
                                                            id: previewEditBar
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: win.previewEditing ? 36 : 0
                                                            Layout.leftMargin: 8
                                                            Layout.rightMargin: 8
                                                            Layout.topMargin: win.previewEditing ? 6 : 0
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
                                                                implicitHeight: 28
                                                                label: qsTr("Undo")
                                                                icon: ""
                                                                enabled: win.canPreviewUndo
                                                                onTriggered: win.undoPreview()
                                                            }

                                                            TonalButton {
                                                                implicitHeight: 28
                                                                label: qsTr("Redo")
                                                                icon: ""
                                                                enabled: win.canPreviewRedo
                                                                onTriggered: win.redoPreview()
                                                            }

                                                            PrimaryButton {
                                                                implicitHeight: 28
                                                                label: qsTr("Apply")
                                                                icon: ""
                                                                enabled: win.previewDirty
                                                                onTriggered: win.applyPreviewEdit()
                                                            }
                                                        }

                                                        // Flickable + TextEdit with clean monospace typography
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
                                                            focus: false

                                                            HoverHandler {
                                                                cursorShape: Qt.IBeamCursor
                                                            }

                                                            TextEdit {
                                                                id: previewEditor
                                                                width: previewScroll.width
                                                                height: Math.max(implicitHeight, previewScroll.height)
                                                                readOnly: !win.previewEditing
                                                                wrapMode: TextEdit.Wrap
                                                                textFormat: TextEdit.PlainText
                                                                font.family: "JetBrains Mono, Geist Mono, SF Mono, Monospace, monospace"
                                                                font.pixelSize: 13
                                                                color: tok.palette.fgSurface
                                                                selectedTextColor: tok.palette.fgPrimary
                                                                selectionColor: tok.palette.primary
                                                                leftPadding: 14
                                                                rightPadding: 14
                                                                topPadding: 12
                                                                bottomPadding: 12

                                                                selectByMouse: true
                                                                selectByKeyboard: true
                                                                persistentSelection: true
                                                                activeFocusOnPress: true
                                                                cursorVisible: !readOnly && activeFocus
                                                                inputMethodHints: Qt.ImhNone

                                                                HoverHandler {
                                                                    cursorShape: Qt.IBeamCursor
                                                                }

                                                                onActiveFocusChanged: {
                                                                    if (activeFocus && win.previewEditing) {
                                                                        cursorVisible = true
                                                                    } else if (!activeFocus && win.previewEditing) {
                                                                        Qt.callLater(function() {
                                                                            if (win.previewEditing && !previewEditFrame.isHovered && (!previewEditor || !previewEditor.activeFocus)) {
                                                                                win.exitPreviewEdit()
                                                                            }
                                                                        })
                                                                    }
                                                                }

                                                                cursorDelegate: Rectangle {
                                                                    id: caret
                                                                    width: 2
                                                                    height: previewEditor.cursorRectangle.height > 0
                                                                        ? previewEditor.cursorRectangle.height
                                                                        : Math.max(18, previewEditor.font.pixelSize * 1.2)
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
                                                                    if (win.previewEditing && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                                                                        win.applyPreviewEdit()
                                                                        event.accepted = true
                                                                        return
                                                                    }
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

                                                            // Refined inset muted scrollbar
                                                            ScrollBar.vertical: ScrollBar {
                                                                id: pScrollBar
                                                                policy: ScrollBar.AsNeeded
                                                                contentItem: Rectangle {
                                                                    implicitWidth: 4
                                                                    radius: 2
                                                                    color: tok.palette.isLight ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(255, 255, 255, 0.28)
                                                                    opacity: (pScrollBar.hovered || pScrollBar.pressed || previewScroll.moving) ? 1 : 0
                                                                    Behavior on opacity {
                                                                        NumberAnimation { duration: 150 }
                                                                    }
                                                                }
                                                            }
                                                        }
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
                                                radius: tok.shape.md
                                                color: tok.palette.isLight
                                                    ? (tok.palette.stage.isValid ? tok.palette.stage : "#E7F0EE")
                                                    : Qt.alpha(tok.palette.fgSurface, 0.055)
                                                border.width: 0
                                                border.color: "transparent"
                                                clip: true
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
                                        spacing: 12
                                        visible: activeClip === null

                                        MIcon {
                                            Layout.alignment: Qt.AlignHCenter
                                            name: "content_paste_off"
                                            size: 44
                                            iconColor: tok.palette.fgMuted
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
                            }

                            // Full-width anchored footer bar with 1px top divider
                            Rectangle {
                                id: stageFooter
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                color: tok.palette.isLight ? Qt.rgba(0, 0, 0, 0.02) : Qt.rgba(255, 255, 255, 0.02)
                                border.width: 0
                                visible: win.hasClips

                                // 1px top border (Olvex surface physics)
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: tok.palette.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.07)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    // Bottom-left: Click to edit interactive button chip
                                    Rectangle {
                                        id: editChip
                                        visible: activeClip && !activeClip.isImage && !win.previewEditing
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitHeight: 28
                                        implicitWidth: editChipRow.implicitWidth + 16
                                        radius: tok.shape.full
                                        color: editChipMa.containsMouse
                                            ? (tok.palette.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.08))
                                            : "transparent"

                                        RowLayout {
                                            id: editChipRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            MIcon {
                                                name: "edit"
                                                size: 14
                                                iconColor: editChipMa.containsMouse ? tok.palette.primary : tok.palette.fgMuted
                                            }

                                            Text {
                                                text: qsTr("Click to edit")
                                                font: tok.type.label
                                                color: editChipMa.containsMouse ? tok.palette.primary : tok.palette.fgMuted
                                            }

                                            KbdKey {
                                                key: "E"
                                                textColor: editChipMa.containsMouse ? tok.palette.primary : tok.palette.fgMuted
                                            }
                                        }

                                        MouseArea {
                                            id: editChipMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.beginPreviewEdit()
                                        }
                                    }

                                    // Shortcuts when editing
                                    RowLayout {
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 10
                                        visible: win.previewEditing

                                        Row {
                                            spacing: 5
                                            KbdKey { key: "Esc" }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: qsTr("Cancel")
                                                font: tok.type.label
                                                color: tok.palette.fgMuted
                                            }
                                        }

                                        Row {
                                            spacing: 5
                                            KbdKey { key: "Ctrl" }
                                            KbdKey { key: "⏎" }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: qsTr("Apply")
                                                font: tok.type.label
                                                color: tok.palette.fgMuted
                                            }
                                        }
                                    }

                                    // Shortcuts when in image view
                                    RowLayout {
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 12
                                        visible: !activeClip || activeClip.isImage

                                        KbdHint { keys: "←→"; caption: qsTr("Filter") }
                                        KbdHint { keys: "↑↓"; caption: qsTr("Navigate") }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Bottom-right: Action buttons
                                    RowLayout {
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 8
                                        visible: clipListModel.count > 0

                                        PrimaryButton {
                                            id: copyBtn
                                            label: qsTr("Copy")
                                            icon: ""
                                            kbd: "⏎"
                                            implicitHeight: 32
                                            onTriggered: win.copySelected()
                                        }

                                        TonalButton {
                                            label: qsTr("Delete")
                                            icon: ""
                                            kbd: "⌫"
                                            tone: "error"
                                            implicitHeight: 32
                                            onTriggered: win.deleteSelected()
                                        }

                                        TonalButton {
                                            label: qsTr("Close")
                                            icon: ""
                                            kbd: "Esc"
                                            implicitHeight: 32
                                            onTriggered: win.close()
                                        }
                                    }
                                }
                            }
                        }

                        // Empty stage — flat pane, centered copy
                        Item {
                            id: stageEmptyOverlay
                            anchors.fill: parent
                            z: 2
                            visible: !win.hasClips
                            enabled: false

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: 0
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 10
                                width: Math.min(360, parent.width - 48)

                                MIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: "inbox"
                                    size: 48
                                    iconColor: tok.palette.fgMuted
                                    opacity: 0.3
                                }

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
            }

        }
    }
}