
import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property int index
    required property int activeWsId
    required property var occupied
    required property int groupOffset
    required property bool expanded

    readonly property bool isWorkspace: true // Flag for finding workspace children

    readonly property int ws: groupOffset + index + 1
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool isCurrent: activeWsId === ws
    // Current workspace always shows detail; others reveal on hover-expand.
    readonly property bool showDetail: isCurrent || expanded
    readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindows

    readonly property int dotDiameter: Tokens.padding.large
    readonly property int ringDiameter: Tokens.rounding.small
    readonly property int labelHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2
    // Always reflects the "if fully expanded" height, regardless of current
    // showDetail state — Workspaces.qml sums these for the hover hit-region,
    // which must not lag behind the (springy, animated) visual size.
    readonly property int detailHeight: (isCurrent || hasWindows) ? (labelHeight + (hasWindows ? (windows.item ? windows.item.implicitHeight : 0) + Tokens.padding.small : 0)) : Math.max(detailCol.implicitHeight, collapsedHeight)
    readonly property int collapsedHeight: isOccupied ? dotDiameter : ringDiameter

    // Unanimated prop for others (ActiveIndicator) to use as reference
    readonly property int size: (showDetail && (isCurrent || hasWindows)) ? detailHeight : collapsedHeight
    readonly property real currentHeight: Layout.preferredHeight

    Layout.alignment: Qt.AlignHCenter
    Layout.preferredHeight: size
    Layout.topMargin: index === 0 ? Math.max(0, (Tokens.sizes.bar.innerWidth / 2) - (Layout.preferredHeight / 2) - Tokens.padding.small) : 0
    Layout.bottomMargin: index === Config.bar.workspaces.shown - 1 ? Math.max(0, (Tokens.sizes.bar.innerWidth / 2) - (Layout.preferredHeight / 2) - Tokens.padding.small) : 0
    implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2
    Layout.preferredWidth: implicitWidth
    width: implicitWidth

    Behavior on Layout.preferredHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    // ── Collapsed: occupied dot or empty ring ───────────────────────
    Rectangle {
        anchors.centerIn: parent
        width: root.collapsedHeight
        height: width
        radius: width / 2
        color: root.isOccupied ? (Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface) : "transparent"
        border.width: root.isOccupied ? 0 : 2
        border.color: Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant

        opacity: root.showDetail ? 0 : 1
        visible: opacity > 0.01

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on color {
            CAnim {}
        }
    }

    function isMaterialSymbol(str: string): bool {
        if (!str || str.length === 0) return false;
        const knownMaterial = [
            "star", "local_fire_department", "bolt", "auto_awesome", "rocket_launch",
            "favorite", "terminal", "code", "circle", "videogame_asset", "pacman",
            "sports_esports", "diamond", "brightness_5", "bedtime", "visibility"
        ];
        if (knownMaterial.includes(str.trim())) return true;
        return /^[a-z][a-z0-9_]{2,}$/.test(str.trim());
    }

    function formatWsLabel(pattern: string, wsId: int): string {
        if (!pattern || pattern.length === 0)
            return wsId.toString();

        const filledNumbers = [
            "❶", "❷", "❸", "❹", "❺", "❻", "❼", "❽", "❾", "❿",
            "⓫", "⓬", "⓭", "⓮", "⓯", "⓰", "⓱", "⓲", "⓳", "⓴"
        ];
        const circledNumbers = [
            "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩",
            "⑪", "⑫", "⑬", "⑭", "⑮", "⑯", "⑰", "⑱", "⑲", "⑳"
        ];

        const trimmed = pattern.trim();
        const lower = trimmed.toLowerCase();

        if (lower === "filled_number" || lower === "filled_circle" || lower === "circled_number" || lower === "badge_number" || lower === "filled") {
            const idx = wsId - 1;
            if (idx >= 0 && idx < filledNumbers.length)
                return filledNumbers[idx];
            return wsId.toString();
        }
        if (lower === "circle_number" || lower === "circled" || lower === "circle_num") {
            const idx = wsId - 1;
            if (idx >= 0 && idx < circledNumbers.length)
                return circledNumbers[idx];
            return wsId.toString();
        }
        if (lower === "number" || lower === "index" || lower === "plain_number" || lower === "digit") {
            return wsId.toString();
        }

        // Aliases to material symbols or nerd glyphs
        if (lower === "star" || pattern === "") return "star";
        if (lower === "fire" || pattern === "󰈸") return "local_fire_department";
        if (lower === "bolt" || lower === "zap" || lower === "lightning" || pattern === "󱐋") return "bolt";
        if (lower === "sparkles" || pattern === "󰫢") return "auto_awesome";
        if (lower === "rocket" || pattern === "󰄛") return "rocket_launch";
        if (lower === "heart" || pattern === "󰋑") return "favorite";
        if (lower === "terminal" || pattern === "󰞷") return "terminal";
        if (lower === "code" || pattern === "󰘐") return "code";
        if (lower === "circle" || lower === "dot" || trimmed === "" || trimmed === "\uf444" || trimmed === "•") return "circle";
        if (lower === "pacman") return "󰮯";
        if (lower === "arch") return "󰣇";

        if (pattern.includes("{number}"))
            return pattern.replace(/{number}/g, wsId.toString());
        if (pattern.includes("{index}"))
            return pattern.replace(/{index}/g, wsId.toString());
        if (pattern.includes("{filled}")) {
            const idx = wsId - 1;
            const filled = (idx >= 0 && idx < filledNumbers.length) ? filledNumbers[idx] : wsId.toString();
            return pattern.replace(/{filled}/g, filled);
        }
        if (pattern.includes("{circle}")) {
            const idx = wsId - 1;
            const circle = (idx >= 0 && idx < circledNumbers.length) ? circledNumbers[idx] : wsId.toString();
            return pattern.replace(/{circle}/g, circle);
        }

        return trimmed;
    }

    // ── Detail: number + open-app glyphs (current, or any slot while expanded) ──
    ColumnLayout {
        id: detailCol

        anchors.centerIn: parent
        width: root.width
        spacing: 0

        opacity: root.showDetail ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Item {
            id: labelContainer

            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredWidth: root.width
            Layout.preferredHeight: root.labelHeight
            implicitWidth: root.width
            implicitHeight: root.labelHeight
            width: root.width
            height: root.labelHeight

            readonly property string currentText: {
                const ws = Hypr.workspaces.values.find(w => w.id === root.ws);
                const wsName = !ws || ws.name == root.ws ? root.ws : ws.name[0];
                let displayName = wsName.toString();
                if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper") {
                    displayName = displayName.toUpperCase();
                } else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower") {
                    displayName = displayName.toLowerCase();
                }

                const activePattern = Config.bar.workspaces.activeLabel || "󰮯";
                if (root.isCurrent || root.isOccupied) {
                    return root.formatWsLabel(activePattern, root.ws);
                }

                const label = (Config.bar.workspaces.label || displayName).trim();
                return root.formatWsLabel(label, root.ws);
            }

            readonly property bool isCircleDot: {
                const t = (currentText || "").trim().toLowerCase();
                return t === "" || t === "\uf444" || t === "circle" || t === "dot" || t === "•";
            }
            readonly property bool isMaterial: !isCircleDot && root.isMaterialSymbol(currentText)
            readonly property bool isCircledNumber: {
                const t = currentText;
                if (!t || t.length === 0) return false;
                const code = t.charCodeAt(0);
                return (code >= 0x2776 && code <= 0x277F)
                    || (code >= 0x2460 && code <= 0x2473)
                    || (code >= 0x24EB && code <= 0x24F4)
                    || (code >= 0x2780 && code <= 0x2789);
            }

            Rectangle {
                id: dotIcon

                anchors.centerIn: parent
                width: root.collapsedHeight
                height: width
                radius: width / 2

                visible: labelContainer.isCircleDot
                color: root.isOccupied || root.isCurrent 
                    ? (Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface) 
                    : (Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant)

                Behavior on color {
                    CAnim {}
                }
            }

            StyledText {
                id: labelText

                anchors.centerIn: parent
                width: parent.width

                textPointSize: labelContainer.isCircledNumber ? ((Tokens ? Tokens.font.size.larger : 18) + 1) : (Tokens ? Tokens.font.size.normal : 13)

                visible: !labelContainer.isMaterial && !labelContainer.isCircleDot
                animate: false
                text: labelContainer.currentText
                color: root.isOccupied || root.isCurrent 
                    ? (Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface) 
                    : (Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant)
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }

            MaterialIcon {
                id: labelIcon

                anchors.centerIn: parent
                width: parent.width

                iconPointSize: Tokens ? Tokens.font.size.larger : 18

                visible: labelContainer.isMaterial && !labelContainer.isCircleDot
                animate: false
                text: labelContainer.currentText
                color: root.isOccupied || root.isCurrent 
                    ? (Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface) 
                    : (Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant)
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Loader {
            id: windows

            asynchronous: false

            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true

            // Stays loaded whenever occupied (not gated on showDetail) so its
            // height is always known for detailHeight above — visibility is
            // handled by the parent detailCol's opacity/scale fade instead.
            visible: active
            active: root.hasWindows

            sourceComponent: Column {
                spacing: 0
                width: root.width

                Repeater {
                    model: ScriptModel {
                        values: {
                            const ws = root.ws;
                            const windows = Hypr.toplevels.values.filter(c => (c.workspace ? c.workspace.id === ws : false));
                            const maxIcons = root.Config.bar.workspaces.maxWindowIcons;
                            return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                        }
                    }

                    MaterialIcon {
                        required property var modelData

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        grade: 0
                        text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                        color: Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
