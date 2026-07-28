// Dashboard module imports – core components for the control center
import "./dash"
import Olvex.Config
import Olvex.Services
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.UPower
import qs.components
import qs.components.effects
import qs.components.filedialog
import qs.services

// Root layout container for the dashboard (horizontal row of columns)
// Root container for the dashboard – a horizontal row of three main columns
RowLayout {
    id: root

    required property DrawerVisibilities visibilities
    required property DashboardState dashState
    required property FileDialog facePicker

    readonly property color accentColor: Colours.palette.m3primary
    readonly property real layoutSpacing: 12

    readonly property real clockWidth: 150

    // Column-2 anchor — left: user + calendar; right: weather (full row height)
    readonly property real resourcesHeight: 204
    readonly property real userHeight: 68
    // Header + 6 week rows at ~23px cells — safe minimum without clipping last row
    readonly property real calendarHeight: 244

    readonly property real topRowHeight: userHeight + layoutSpacing + calendarHeight
    readonly property real weatherHeight: topRowHeight
    readonly property real column2Height: topRowHeight + layoutSpacing + resourcesHeight
    readonly property real clockHeight: column2Height

    readonly property real calendarWidth: 340
    readonly property real weatherWidth: 346
    readonly property real resourcesWidth: calendarWidth + layoutSpacing + weatherWidth

    property int batteryUiEpoch: 0

    Connections {
        target: UPower
        function onOnBatteryChanged(): void {
            root.batteryUiEpoch++
        }
    }

    Connections {
        target: UPower.displayDevice
        function onStateChanged(): void {
            root.batteryUiEpoch++
        }
        function onPowerSupplyChanged(): void {
            root.batteryUiEpoch++
        }
    }

    // ==== Independent alignment offsets (pixel values) ====
    // Adjust these to fine‑tune each card's X/Y position within its column.
    // Positive values move the card right / down.
    readonly property int userCardX: 0
    readonly property int userCardY: 0 // aligned with Calendar top margin
    readonly property int weatherCardX: 0
    readonly property int weatherCardY: 0 // aligned with Calendar top margin      

    spacing: root.layoutSpacing
    implicitWidth: root.clockWidth +
               root.calendarWidth + root.layoutSpacing + root.weatherWidth +
               root.layoutSpacing
    implicitHeight: root.column2Height

    // ── COLUMN 1: Vertical Clock (Tall) ──────────────────────────────────────
    GlassCard {
        staggerIndex: 0
        Layout.preferredWidth: root.clockWidth
        Layout.fillHeight: true
        Layout.preferredHeight: root.clockHeight // Force height
        borderless: true

        DateTime {
            anchors.fill: parent
        }
    }

    // ── COLUMN 2: (User + Calendar | Weather) then Resources below ──
    ColumnLayout {
        Layout.fillHeight: true
        spacing: root.layoutSpacing

        // Top row: User + Calendar left, Weather right (full height)
        RowLayout {
            spacing: root.layoutSpacing

            ColumnLayout {
                spacing: root.layoutSpacing
                Layout.alignment: Qt.AlignTop

                GlassCard {
                    staggerIndex: 1
                    Layout.preferredWidth: root.calendarWidth
                    Layout.preferredHeight: root.userHeight
                    User {
                        anchors.fill: parent
                        visibilities: root.visibilities
                        facePicker: root.facePicker
                    }
                }

                GlassCard {
                    staggerIndex: 2
                    Layout.preferredWidth: root.calendarWidth
                    Layout.preferredHeight: root.calendarHeight
                    Calendar {
                        anchors.fill: parent
                        dashState: root.dashState
                    }
                }
            }

            GlassCard {
                staggerIndex: 3
                Layout.preferredWidth: root.weatherWidth
                Layout.preferredHeight: root.weatherHeight
                Layout.alignment: Qt.AlignTop
                SmallWeather {
                    anchors.fill: parent
                }
            }
        }

        // Resources Card — full width below
        GlassCard {
            staggerIndex: 4
            Layout.fillWidth: true
            Layout.preferredWidth: root.resourcesWidth
            Layout.fillHeight: true
            Layout.preferredHeight: root.resourcesHeight
            Resources {
                anchors.fill: parent
                visibilities: root.visibilities
                batteryUiEpoch: root.batteryUiEpoch
            }
        }
    }

    readonly property bool isLowPower: PowerProfiles.profile === PowerProfile.PowerSaver

    // ----- Reusable GlassCard component definition (cards used above) -----
    component GlassCard: Item { // Base card with glassmorphic styling and entrance animation
        id: cardRoot
        default property alias content: innerContent.data
        property real radius: 24
        property int staggerIndex: 0
        property bool tonal: false
        property bool subtleBorder: false
        property bool innerStroke: true
        property bool borderless: false

        implicitHeight: Layout.preferredHeight
        
        // Android 16 Fluid Spring Animation (Opening Only - Bouncy)
        property bool _ready: false
        Component.onCompleted: Qt.callLater(() => _ready = true)

        state: (root.visibilities.dashboard && _ready) ? "visible" : "hidden"
        
        transform: [
            Scale {
                id: scale
                origin.x: cardRoot.width / 2
                origin.y: cardRoot.height / 2
                xScale: root.isLowPower ? 1.0 : 1.2
                yScale: root.isLowPower ? 1.0 : 1.2
            }
        ]

        states: [
            State {
                name: "hidden"
                PropertyChanges { target: cardRoot; opacity: 0 }
                PropertyChanges { target: scale; xScale: root.isLowPower ? 1.0 : 1.2; yScale: root.isLowPower ? 1.0 : 1.2 }
            },
            State {
                name: "visible"
                PropertyChanges { target: cardRoot; opacity: 1 }
                PropertyChanges { target: scale; xScale: 1.0; yScale: 1.0 }
            }
        ]

        transitions: Transition {
            from: "hidden"; to: "visible"
            SequentialAnimation {
                PauseAnimation { duration: root.isLowPower ? 0 : cardRoot.staggerIndex * 40 }
                ParallelAnimation {
                    NumberAnimation { target: cardRoot; property: "opacity"; duration: root.isLowPower ? 150 : 300 }
                    NumberAnimation { 
                        target: scale; properties: "xScale,yScale"; duration: root.isLowPower ? 200 : 400; 
                        easing.type: Easing.OutExpo; 
                    }
                }
            }
        }

        StyledRect {
            id: bg
            anchors.fill: parent
            radius: cardRoot.radius
            
            color: cardRoot.tonal ? Colours.tileFillTonal : Colours.tileSurface

            border.width: cardRoot.borderless ? 0 : 1
            border.color: cardRoot.subtleBorder || cardRoot.tonal
                ? Colours.tileStrokeSubtle
                : Colours.tileStroke

            // Second border line as a single internal item
            StyledRect {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: "transparent"
                visible: cardRoot.innerStroke && !cardRoot.borderless
                border.color: Colours.tileInnerLine
                border.width: 1
            }

            StyledClippingRect {
                id: innerContent
                anchors.fill: parent
                anchors.margins: 4
                radius: bg.radius - 4
                color: "transparent"
                clip: true
            }
        }
    }
}
