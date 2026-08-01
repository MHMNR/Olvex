pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: showBackground ? Tokens.padding.normal : Tokens.padding.small

    // All config values are read manually (not bound) to avoid stale reads
    // during the race between QML init and GlobalConfig's shell.json load.
    property bool widgetEnabled: true
    property bool showIcons: true
    property bool showBackground: false
    property int fontSize: 11
    property int maxDigits: 0
    property bool combined: false

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
            Qt.callLater(root.refreshConfig);
        }
    }

    visible: root.widgetEnabled

    // Combined-mode helpers (re-evaluate each frame — cheap, NetworkUsage
    // caches internally).
    readonly property var upFmt: NetworkUsage.formatBytes(NetworkUsage.uploadSpeed)
    readonly property var downFmt: NetworkUsage.formatBytes(NetworkUsage.downloadSpeed)
    readonly property int combinedDecimals: upFmt.unit === downFmt.unit
        ? (upFmt.unit.startsWith("B") ? 0 : root.maxDigits)
        : 0

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
                readonly property var fmt: NetworkUsage.formatBytes(NetworkUsage.uploadSpeed)
                readonly property int decimals: fmt.unit.startsWith("B") ? 0 : root.maxDigits
                text: fmt.value.toFixed(decimals)
                textPointSize: root.fontSize + 1
                font.weight: Font.Bold
                font.family: GlobalConfig.appearance.font.family.sans
                color: root.colour
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                readonly property var fmt: NetworkUsage.formatBytes(NetworkUsage.uploadSpeed)
                text: fmt.unit
                textPointSize: root.fontSize - 1
                font.weight: Font.DemiBold
                font.family: GlobalConfig.appearance.font.family.sans
                color: Qt.alpha(root.colour, 0.78)
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Item {
            width: 1
            height: root.combined ? 0 : Tokens.spacing.small
            visible: !root.combined
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            height: root.combined ? 0 : 1
            width: parent.width * 0.6
            color: root.colour
            opacity: root.combined ? 0 : 0.2
            visible: !root.combined
        }

        Item {
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
                readonly property var fmt: NetworkUsage.formatBytes(NetworkUsage.downloadSpeed)
                readonly property int decimals: fmt.unit.startsWith("B") ? 0 : root.maxDigits
                text: fmt.value.toFixed(decimals)
                textPointSize: root.fontSize + 1
                font.weight: Font.Bold
                font.family: GlobalConfig.appearance.font.family.sans
                color: root.colour
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                readonly property var fmt: NetworkUsage.formatBytes(NetworkUsage.downloadSpeed)
                text: fmt.unit
                textPointSize: root.fontSize - 1
                font.weight: Font.DemiBold
                font.family: GlobalConfig.appearance.font.family.sans
                color: Qt.alpha(root.colour, 0.78)
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // ── COMBINED mode: icons side-by-side on top, speeds stacked below ──
        Item {
            visible: root.combined
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: childrenRect.height

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: -1

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
                    readonly property var totalSpeed: NetworkUsage.uploadSpeed + NetworkUsage.downloadSpeed
                    readonly property var fmt: NetworkUsage.formatBytes(totalSpeed)
                    readonly property int decimals: fmt.unit.startsWith("B") ? 0 : root.maxDigits
                    text: fmt.value.toFixed(decimals)
                    textPointSize: root.fontSize + 1
                    font.weight: Font.Bold
                    font.family: GlobalConfig.appearance.font.family.sans
                    color: root.colour
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    readonly property var totalSpeed: NetworkUsage.uploadSpeed + NetworkUsage.downloadSpeed
                    readonly property var fmt: NetworkUsage.formatBytes(totalSpeed)
                    text: fmt.unit
                    textPointSize: root.fontSize - 1
                    font.weight: Font.DemiBold
                    font.family: GlobalConfig.appearance.font.family.sans
                    color: Qt.alpha(root.colour, 0.78)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
