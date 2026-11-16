import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.widgets.clocks
import qs.services

Item {
    id: root

    readonly property var _desktopClockCfg: (Config.background && Config.background.desktopClock)
        ? Config.background.desktopClock
        : (GlobalConfig.background && GlobalConfig.background.desktopClock ? GlobalConfig.background.desktopClock : null)

    // Extensible clock style identifier shared across Desktop, Card Lockscreen, and Minimal Lockscreen.
    property string clockStyle: (_desktopClockCfg && _desktopClockCfg.style)
        ? _desktopClockCfg.style
        : "classic"
    property int styleVariant: (_desktopClockCfg && _desktopClockCfg.styleVariant !== undefined)
        ? _desktopClockCfg.styleVariant
        : 0

    property real clockScale: (_desktopClockCfg && _desktopClockCfg.scale !== undefined)
        ? _desktopClockCfg.scale
        : 1.0
    readonly property bool invertColors: Boolean(_desktopClockCfg && _desktopClockCfg.invertColors)
    readonly property bool adaptiveColor: (_desktopClockCfg && _desktopClockCfg.adaptiveTextColor !== undefined)
        ? Boolean(_desktopClockCfg.adaptiveTextColor)
        : true
    readonly property bool dominantIsDark: (_desktopClockCfg && _desktopClockCfg.dominantIsDark !== undefined)
        ? Boolean(_desktopClockCfg.dominantIsDark)
        : !Colours.light
    readonly property bool useLightSet: adaptiveColor ? !dominantIsDark : (Colours.light ? !invertColors : invertColors)

    property bool syncFromLockState: false
    property string lockScreenName: ""
    readonly property var _lockedColors: syncFromLockState ? LockState.getDesktopClockColors(lockScreenName) : null

    property color primaryColor: _lockedColors ? _lockedColors.primaryColor : (useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary)
    property color secondaryColor: _lockedColors ? _lockedColors.secondaryColor : (useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary)
    property color tertiaryColor: _lockedColors ? _lockedColors.tertiaryColor : (useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary)
    property color onSurfaceColor: _lockedColors ? _lockedColors.onSurfaceColor : (useLightSet ? Colours.palette.m3surfaceContainerLowest : Colours.palette.m3onSurface)

    property bool showDatePill: true
    property string dateDetailFormat: "d MMMM yyyy"
    property bool shadowEnabled: true
    property real shadowOpacity: 0.35
    property real shadowBlur: 0.6

    readonly property real renderBase: 3.0

    function applyVectorText(item) {
        if (!item)
            return;
        if (item.hasOwnProperty("renderType"))
            item.renderType = Text.QtRendering;
        const kids = item.children;
        if (!kids)
            return;
        for (let i = 0; i < kids.length; i++)
            applyVectorText(kids[i]);
    }

    implicitWidth: styleLoader.item ? Math.round(styleLoader.item.implicitWidth * (root.clockScale / root.renderBase)) : 0
    implicitHeight: styleLoader.item ? Math.round(styleLoader.item.implicitHeight * (root.clockScale / root.renderBase)) : 0

    Loader {
        id: styleLoader
        anchors.centerIn: parent
        transformOrigin: Item.Center
        scale: root.clockScale / root.renderBase
        onLoaded: root.applyVectorText(item)
        sourceComponent: {
            switch (root.clockStyle) {
            case "scalloped": return scallopedComponent;
            case "chunky": return chunkyComponent;
            case "bold-analog": return boldAnalogComponent;
            case "stacked-2x2": return stacked2x2Component;
            case "wide-radial": return wideRadialComponent;
            case "chrono-digital": return chronoDigitalComponent;
            case "clustered-giant": return clusteredGiantComponent;
            case "square-swiss": return squareSwissComponent;
            case "tall-split": return tallSplitComponent;
            case "expressive-flower": return expressiveFlowerComponent;
            case "editorial-serif": return editorialSerifComponent;
            case "orbit-ring": return orbitRingComponent;
            case "bento-cards": return bentoCardsComponent;
            case "pill-morph": return pillMorphComponent;
            case "sunburst-analog": return sunburstAnalogComponent;
            case "dot-matrix": return dotMatrixComponent;
            case "typo-ribbon": return typoRibbonComponent;
            case "flip-tiles": return flipTilesComponent;
            case "arch-gauge": return archGaugeComponent;
            case "radar-minimal": return radarMinimalComponent;
            case "wave-progress": return waveProgressComponent;
            case "pixel-slanted": return pixelSlantedComponent;
            case "hexagon-analog": return hexagonAnalogComponent;
            case "vertical-bars": return verticalBarsComponent;
            case "dual-ring-analog": return dualRingAnalogComponent;
            case "wordmark-time": return wordmarkComponent;
            case "minimal-arc": return minimalArcComponent;
            case "corner-badge": return cornerBadgeComponent;
            case "segmented-pill": return segmentedPillComponent;
            case "floating-digits": return floatingDigitsComponent;
            case "compass-dial": return compassDialComponent;
            case "glass-stack": return glassStackComponent;
            case "binary-dots": return binaryDotsComponent;
            case "clover-analog": return cloverAnalogComponent;
            case "split-ticker": return splitTickerComponent;
            case "minimal-numeral": return minimalNumeralComponent;
            case "analog-digital": return analogDigitalComponent;
            case "olvex-signature": return olvexSignatureComponent;
            case "classic":
            default:
                return classicClockComponent;
            }
        }
    }

    Component {
        id: scallopedComponent
        Clock01Scalloped {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
            dateDetailFormat: root.dateDetailFormat
        }
    }

    Component {
        id: chunkyComponent
        Clock03ChunkyOverlap {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: boldAnalogComponent
        Clock04BoldZeroAnalog {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: stacked2x2Component
        Clock05Stacked2x2 {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: wideRadialComponent
        Clock06WidePerspective {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: chronoDigitalComponent
        Clock07ChronoDigital {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: clusteredGiantComponent
        Clock08ClusteredGiant {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: squareSwissComponent
        Clock09SquareSwiss {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: tallSplitComponent
        Clock10TallSplit {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: expressiveFlowerComponent
        Clock11ExpressiveFlower {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: editorialSerifComponent
        Clock12EditorialSerif {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
            dateDetailFormat: root.dateDetailFormat
        }
    }

    Component {
        id: orbitRingComponent
        Clock13OrbitRing {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: bentoCardsComponent
        Clock14BentoCards {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: pillMorphComponent
        Clock15PillMorph {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: sunburstAnalogComponent
        Clock16SunburstAnalog {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: dotMatrixComponent
        Clock17DotMatrix {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: typoRibbonComponent
        Clock18TypoRibbon {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: flipTilesComponent
        Clock19FlipTiles {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: archGaugeComponent
        Clock20ArchGauge {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: radarMinimalComponent
        Clock21RadarMinimal {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: waveProgressComponent
        Clock22WaveProgress {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: pixelSlantedComponent
        Clock23PixelSlanted {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: hexagonAnalogComponent
        Clock24HexagonAnalog {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: verticalBarsComponent
        Clock25VerticalBars {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: dualRingAnalogComponent
        Clock26DualRingAnalog {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: wordmarkComponent
        Clock27Wordmark {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: minimalArcComponent
        Clock28MinimalistArc {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: cornerBadgeComponent
        Clock29CornerBadge {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: segmentedPillComponent
        Clock30SegmentedPill {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: floatingDigitsComponent
        Clock31FloatingDigits {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: compassDialComponent
        Clock32CompassDial {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: glassStackComponent
        Clock33GlassStack {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: binaryDotsComponent
        Clock34BinaryDots {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: cloverAnalogComponent
        Clock35CloverAnalog {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: splitTickerComponent
        Clock36SplitTicker {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: minimalNumeralComponent
        Clock37MinimalOutline {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: analogDigitalComponent
        Clock38AnalogDigital {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
        }
    }

    Component {
        id: olvexSignatureComponent
        Clock39OlvexSignature {
            variant: root.styleVariant
            clockScale: root.renderBase
            primaryColor: root.primaryColor
            secondaryColor: root.secondaryColor
            tertiaryColor: root.tertiaryColor
            onSurfaceColor: root.onSurfaceColor
            showDatePill: root.showDatePill
        }
    }

    Component {
        id: classicClockComponent

        ColumnLayout {
            id: clockCol
            spacing: Math.round(8 * root.renderBase)

            Component.onCompleted: Time.secondsRefCount++
            Component.onDestruction: Time.secondsRefCount--

            layer.enabled: root.shadowEnabled
            layer.smooth: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Colours.palette.m3shadow
                shadowOpacity: root.shadowOpacity
                shadowBlur: root.shadowBlur
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 2
            }

            // ── Top M3 Date & Day Capsule (Variant 0) ────────────────────────
            StyledRect {
                visible: root.showDatePill && root.styleVariant === 0
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Math.round(dateRow.implicitWidth + (20 * root.renderBase))
                implicitHeight: Math.round(dateRow.implicitHeight + (8 * root.renderBase))
                radius: height / 2
                color: Colours.palette.m3secondaryContainer

                RowLayout {
                    id: dateRow
                    anchors.centerIn: parent
                    spacing: Math.round(7 * root.renderBase)

                    StyledRect {
                        width: Math.max(4, Math.round(5.5 * root.renderBase))
                        height: width
                        radius: width / 2
                        color: root.tertiaryColor
                        opacity: (Time.seconds % 2 === 0) ? 1.0 : 0.35
                        Behavior on opacity {
                            Anim { duration: Tokens.anim.durations.small }
                        }
                    }

                    StyledText {
                        text: (Time.format("dddd") + " • " + Time.format(root.dateDetailFormat)).toUpperCase()
                        textPointSize: Math.max(7, Math.round(Tokens.font.size.small * 0.88 * root.renderBase))
                        font.family: Tokens.font.family.sans
                        font.letterSpacing: 1.4 * 1.0
                        font.weight: Font.Bold
                        color: Colours.palette.m3onSecondaryContainer
                    }
                }
            }

            // ── Main Time Display ───────────────────────────────────────────
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Math.round(6 * root.renderBase)

                StyledText {
                    text: Time.hourStr
                    color: root.styleVariant === 0 ? root.onSurfaceColor : root.primaryColor
                    textPointSize: Math.max(22, Math.floor(Tokens.font.size.extraLarge * 2.45 * root.renderBase))
                    font.family: Tokens.font.family.sans
                    font.weight: Font.Black
                    font.letterSpacing: -1.8 * 1.0
                }

                // Stacked M3 Colon Dots
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Math.round(7 * root.renderBase)

                    Repeater {
                        model: 2
                        StyledRect {
                            width: Math.max(4, Math.round(6.5 * root.renderBase))
                            height: width
                            radius: width / 2
                            color: root.tertiaryColor
                            opacity: root.styleVariant === 0
                                ? ((Time.seconds % 2 === 0) ? 1.0 : 0.45)
                                : 0.85
                            Behavior on opacity {
                                Anim { duration: Tokens.anim.durations.small }
                            }
                        }
                    }
                }

                StyledText {
                    text: Time.minuteStr
                    color: root.styleVariant === 0 ? root.primaryColor : root.onSurfaceColor
                    textPointSize: Math.max(22, Math.floor(Tokens.font.size.extraLarge * 2.45 * root.renderBase))
                    font.family: Tokens.font.family.sans
                    font.weight: root.styleVariant === 0 ? Font.Black : Font.Light
                    font.letterSpacing: -1.8 * 1.0
                }

                Loader {
                    asynchronous: true
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Math.round(Tokens.padding.normal * 0.75 * root.renderBase)
                    Layout.leftMargin: Math.round(2 * root.renderBase)

                    active: GlobalConfig.services.useTwelveHourClock
                    visible: active

                    sourceComponent: StyledRect {
                        implicitWidth: Math.round(amPmText.implicitWidth + (12 * root.renderBase))
                        implicitHeight: Math.round(amPmText.implicitHeight + (6 * root.renderBase))
                        radius: height / 2
                        color: Colours.palette.m3primaryContainer

                        StyledText {
                            id: amPmText
                            anchors.centerIn: parent
                            text: Time.amPmStr
                            color: Colours.palette.m3onPrimaryContainer
                            textPointSize: Math.max(7, Math.round(Tokens.font.size.small * 0.8 * root.renderBase))
                            font.family: Tokens.font.family.sans
                            font.weight: Font.Black
                            font.letterSpacing: 0.9 * 1.0
                        }
                    }
                }
            }

            // ── Bottom Minimal Date (Variant 1) ─────────────────────────────
            StyledText {
                visible: root.showDatePill && root.styleVariant === 1
                Layout.alignment: Qt.AlignHCenter
                text: (Time.format("dddd") + " • " + Time.format(root.dateDetailFormat)).toUpperCase()
                textPointSize: Math.max(7, Math.round(Tokens.font.size.small * 0.9 * root.renderBase))
                font.family: Tokens.font.family.sans
                font.letterSpacing: 1.6 * 1.0
                font.weight: Font.DemiBold
                color: root.secondaryColor
            }
        }
    }
}

