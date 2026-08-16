pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
    readonly property int padding: showBackground ? Tokens.padding.normal : Tokens.padding.small

    readonly property var netSpeedConfig: GlobalConfig.bar?.netSpeed
    property bool widgetEnabled: netSpeedConfig?.enabled ?? true
    property bool showIcons: netSpeedConfig?.showIcons ?? true
    property bool showBackground: netSpeedConfig?.background ?? false
    property int fontSize: netSpeedConfig?.fontSize ?? 11
    property int maxDigits: netSpeedConfig?.maxDigits ?? 0
    property bool combined: (netSpeedConfig?.mode ?? "separate") === "combined"

    function refreshConfig(): void {
        const ns = GlobalConfig.bar?.netSpeed;
        if (!ns)
            return;
        root.widgetEnabled = ns.enabled ?? true;
        root.showIcons = ns.showIcons ?? true;
        root.showBackground = ns.background ?? false;
        root.fontSize = ns.fontSize ?? 11;
        root.maxDigits = ns.maxDigits ?? 0;
        root.combined = ns.mode === "combined";
    }

    Connections {
        target: GlobalConfig
        function onLoaded() {
            root.refreshConfig();
        }
    }

    Connections {
        target: GlobalConfig.bar?.netSpeed
        function onModeChanged() {
            root.combined = (GlobalConfig.bar.netSpeed.mode ?? "separate") === "combined";
        }
        function onEnabledChanged() {
            root.widgetEnabled = GlobalConfig.bar.netSpeed.enabled ?? true;
        }
        function onShowIconsChanged() {
            root.showIcons = GlobalConfig.bar.netSpeed.showIcons ?? true;
        }
        function onBackgroundChanged() {
            root.showBackground = GlobalConfig.bar.netSpeed.background ?? false;
        }
        function onFontSizeChanged() {
            root.fontSize = GlobalConfig.bar.netSpeed.fontSize ?? 11;
        }
        function onMaxDigitsChanged() {
            root.maxDigits = GlobalConfig.bar.netSpeed.maxDigits ?? 0;
        }
    }

    visible: root.widgetEnabled

    // Combined-mode helpers
    readonly property var upFmt: NetworkUsage.formatBytes(NetworkUsage.uploadSpeed)
    readonly property var downFmt: NetworkUsage.formatBytes(NetworkUsage.downloadSpeed)
    readonly property var totalFmt: NetworkUsage.formatBytes(NetworkUsage.uploadSpeed + NetworkUsage.downloadSpeed)

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, showBackground ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    Component.onCompleted: {
        NetworkUsage.refCount++;
        Qt.callLater(root.refreshConfig);
    }
    Component.onDestruction: NetworkUsage.refCount--

    Column {
        id: layout

        anchors.centerIn: parent
        width: parent.width
        spacing: 0

        // ── SEPARATE mode (default): two distinct rows ──────────────────
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -2
            visible: !root.combined

            MaterialIcon {
                visible: root.showIcons
                text: "arrow_drop_up"
                iconPointSize: root.fontSize + 2
                color: root.colour
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                readonly property int decimals: root.upFmt.unit.startsWith("B") ? 0 : root.maxDigits
                text: root.upFmt.value.toFixed(decimals)
                textPointSize: root.fontSize + 1
                font.weight: Font.Bold
                font.family: GlobalConfig.appearance.font.family.sans
                color: root.colour
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.upFmt.unit
                textPointSize: root.fontSize - 1
                font.weight: Font.DemiBold
                font.family: GlobalConfig.appearance.font.family.sans
                color: Qt.alpha(root.colour, 0.78)
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 1
            height: root.combined ? 0 : Tokens.spacing.small
            visible: !root.combined
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            height: root.combined ? 0 : 1
            width: 24
            color: root.colour
            opacity: root.combined ? 0 : 0.2
            visible: !root.combined
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 1
            height: root.combined ? 0 : Tokens.spacing.small
            visible: !root.combined
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -2
            visible: !root.combined

            MaterialIcon {
                visible: root.showIcons
                text: "arrow_drop_down"
                iconPointSize: root.fontSize + 2
                color: root.colour
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                readonly property int decimals: root.downFmt.unit.startsWith("B") ? 0 : root.maxDigits
                text: root.downFmt.value.toFixed(decimals)
                textPointSize: root.fontSize + 1
                font.weight: Font.Bold
                font.family: GlobalConfig.appearance.font.family.sans
                color: root.colour
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.downFmt.unit
                textPointSize: root.fontSize - 1
                font.weight: Font.DemiBold
                font.family: GlobalConfig.appearance.font.family.sans
                color: Qt.alpha(root.colour, 0.78)
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // ── COMBINED mode: icons side-by-side on top, speeds stacked below ──
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -1
            visible: root.combined

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                MaterialIcon {
                    visible: root.showIcons
                    text: "arrow_drop_up"
                    iconPointSize: root.fontSize + 2
                    color: root.colour
                    opacity: NetworkUsage.uploadSpeed > NetworkUsage.downloadSpeed ? 1.0 : 0.4
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on opacity {
                        Anim { type: Anim.FastEffects }
                    }
                }

                MaterialIcon {
                    visible: root.showIcons
                    text: "arrow_drop_down"
                    iconPointSize: root.fontSize + 2
                    color: root.colour
                    opacity: NetworkUsage.downloadSpeed >= NetworkUsage.uploadSpeed ? 1.0 : 0.4
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on opacity {
                        Anim { type: Anim.FastEffects }
                    }
                }
            }

            StyledText {
                readonly property int decimals: root.totalFmt.unit.startsWith("B") ? 0 : root.maxDigits
                text: root.totalFmt.value.toFixed(decimals)
                textPointSize: root.fontSize + 1
                font.weight: Font.Bold
                font.family: GlobalConfig.appearance.font.family.sans
                color: root.colour
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.totalFmt.unit
                textPointSize: root.fontSize - 1
                font.weight: Font.DemiBold
                font.family: GlobalConfig.appearance.font.family.sans
                color: Qt.alpha(root.colour, 0.78)
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
