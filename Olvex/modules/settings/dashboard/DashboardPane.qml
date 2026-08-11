pragma ComponentBehavior: Bound


import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Olvex.Config
import qs.services
import qs.utils

Item {
    id: root

    required property Session session

    // General Settings
    property bool enabled: Config.dashboard.enabled ?? true
    property bool showOnHover: Config.dashboard.showOnHover ?? true
    property int resourceUpdateInterval: GlobalConfig.dashboard.resourceUpdateInterval ?? 1000
    property int dragThreshold: Config.dashboard.dragThreshold ?? 50
    property int colUnit: Config.dashboard.colUnit ?? 250
    property int rowTopHeight: Config.dashboard.rowTopHeight ?? 310
    property int rowBotHeight: Config.dashboard.rowBotHeight ?? 185

    // Dashboard Tabs
    property bool showDashboard: Config.dashboard.showDashboard ?? true
    property bool showPerformance: Config.dashboard.showPerformance ?? true
    property bool showWeather: Config.dashboard.showWeather ?? true
    property bool useFahrenheit: GlobalConfig.services.useFahrenheit ?? false
    property string weatherLocation: GlobalConfig.services.weatherLocation ?? ""

    // Performance Resources
    property bool showBattery: Config.dashboard.performance.showBattery ?? false
    property bool showGpu: Config.dashboard.performance.showGpu ?? true
    property bool showCpu: Config.dashboard.performance.showCpu ?? true
    property bool showMemory: Config.dashboard.performance.showMemory ?? true
    property bool showStorage: Config.dashboard.performance.showStorage ?? true
    property bool showNetwork: Config.dashboard.performance.showNetwork ?? true

    function saveConfig() {
        GlobalConfig.dashboard.enabled = root.enabled;
        GlobalConfig.dashboard.showOnHover = root.showOnHover;
        GlobalConfig.dashboard.resourceUpdateInterval = root.resourceUpdateInterval;
        GlobalConfig.dashboard.dragThreshold = root.dragThreshold;
        GlobalConfig.dashboard.showDashboard = root.showDashboard;
        GlobalConfig.dashboard.showPerformance = root.showPerformance;
        GlobalConfig.dashboard.showWeather = root.showWeather;
        GlobalConfig.services.useFahrenheit = root.useFahrenheit;
        GlobalConfig.services.weatherLocation = root.weatherLocation;
        GlobalConfig.dashboard.performance.showBattery = root.showBattery;
        GlobalConfig.dashboard.performance.showGpu = root.showGpu;
        GlobalConfig.dashboard.performance.showCpu = root.showCpu;
        GlobalConfig.dashboard.performance.showMemory = root.showMemory;
        GlobalConfig.dashboard.performance.showStorage = root.showStorage;
        GlobalConfig.dashboard.performance.showNetwork = root.showNetwork;
        GlobalConfig.dashboard.colUnit = root.colUnit;
        GlobalConfig.dashboard.rowTopHeight = root.rowTopHeight;
        GlobalConfig.dashboard.rowBotHeight = root.rowBotHeight;
        // Note: sizes properties are readonly and cannot be modified
    }

    anchors.fill: parent

    StyledClippingRect {
        id: dashboardClippingRect

        anchors.fill: parent
        anchors.margins: Tokens.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Tokens.padding.normal

        radius: dashboardBorder.innerRadius
        color: "transparent"

        Loader {
            id: dashboardLoader

            anchors.fill: parent
            anchors.margins: Tokens.padding.large + Tokens.padding.normal
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.large

            asynchronous: true
            sourceComponent: dashboardContentComponent
        }
    }

    InnerBorder {
        id: dashboardBorder

        leftThickness: 0
        rightThickness: Tokens.padding.normal
    }

    Component {
        id: dashboardContentComponent

        StyledFlickable {
            id: dashboardFlickable

            flickableDirection: Flickable.VerticalFlick
            contentHeight: dashboardLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: dashboardFlickable
            }

            ColumnLayout {
                id: dashboardLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                spacing: Tokens.spacing.normal

                RowLayout {
                    spacing: Tokens.spacing.smaller

                    StyledText {
                        text: qsTr("Dashboard")
                        textPointSize: Tokens.font.size.large
                        font.weight: 400
                    }
                }

                // General Settings Section
                GeneralSection {
                    rootItem: root
                }

                // Performance Resources Section
                PerformanceSection {
                    rootItem: root
                }

                WeatherSection {
                    rootItem: root
                }
            }
        }
    }
}
