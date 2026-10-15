import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.settings
import qs.modules.launcher.services

Item {
    id: root

    required property var modelData
    required property var list
    required property DrawerVisibilities visibilities
    required property int index

    readonly property bool isCurrent: list.currentIndex === index
    readonly property color itemAccent: {
        if (!modelData) return Colours.palette.m3primary;
        const role = modelData.accentRole;
        return (role && Colours.palette[role]) ? Colours.palette[role] : Colours.palette.m3primary;
    }

    implicitHeight: Tokens.sizes.launcher.itemHeight || 56

    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined

    function cleanBreadcrumb(raw) {
        if (!raw) return "";
        const parts = raw.split("›").map(s => s.trim()).filter(s => s.length > 0);
        const filtered = parts.filter(p => p.toLowerCase() !== "settings");
        return filtered.length > 0 ? filtered.join(" › ") : raw;
    }

    function select() {
        if (!root.modelData) return;

        if (root.modelData.type === "toggle") {
            if (root.modelData.toggle)
                root.modelData.toggle();
            return;
        }

        if (root.modelData.type === "setting") {
            root.openSettings();
            return;
        }

        if (root.modelData.type === "app") {
            Apps.launch(root.modelData.entry || root.modelData);
            root.visibilities.launcher = false;
            Visibilities.launcherInterrupted = true;
            return;
        }

        if (root.modelData.onClicked) {
            root.modelData.onClicked(root.list);
            return;
        }
    }

    function openSettings() {
        if (!root.modelData) return;
        root.visibilities.launcher = false;
        Visibilities.launcherInterrupted = true;

        const pageId = root.modelData.pageId || "";
        const sectionId = root.modelData.sectionId || "";
        const id = root.modelData.id || root.modelData.settingId || "";
        const title = root.modelData.title || root.modelData.name || "";
        const query = root.modelData.searchQuery || "";

        WindowFactory.create(null, {
            currentId: pageId,
            activeSection: sectionId
        });

        PaneRegistry.flashHighlight(id, sectionId, pageId, query, title, id);
    }

    // Material 3 StateLayer for tactile click response
    StateLayer {
        radius: Tokens.rounding.normal
        showHoverBackground: false
        onClicked: root.select()
    }

    // Hover handler to move the focus marker to this item on mouse move
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered && root.list)
                root.list.currentIndex = root.index;
        }
    }

    // Row layout contents
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.larger
        anchors.rightMargin: Tokens.padding.larger
        spacing: Tokens.spacing.normal

        // ── 1. Left Squircle Icon Badge ──
        StyledRect {
            id: iconBadge
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 10
            color: root.isCurrent 
                ? Qt.alpha(root.itemAccent, 0.26) 
                : Qt.alpha(root.itemAccent, 0.14)
            Layout.alignment: Qt.AlignVCenter

            Behavior on color { CAnim {} }

            // App Icon Image (for application results)
            IconImage {
                id: appIconImage
                visible: root.modelData && root.modelData.type === "app"
                asynchronous: true
                smooth: true
                mipmap: true
                source: {
                    if (!visible || !root.modelData) return "";
                    if (root.modelData.entry)
                        return Icons.resolveApp(root.modelData.entry);
                    return root.modelData.icon || "";
                }
                anchors.fill: parent
                anchors.margins: 6
            }

            // Material Icon (for toggle, setting, and command results)
            MaterialIcon {
                id: materialIcon
                visible: !appIconImage.visible || appIconImage.status === Image.Error || appIconImage.status === Image.Null
                anchors.centerIn: parent
                text: {
                    if (!root.modelData) return "circle";
                    if (root.modelData.type === "app") {
                        return root.modelData.name ? root.modelData.name.charAt(0).toUpperCase() : "rocket";
                    }
                    if (typeof root.modelData.icon === "function")
                        return root.modelData.icon();
                    return root.modelData.icon || "settings";
                }
                fill: (root.modelData && root.modelData.type === "toggle" && root.modelData.getter && root.modelData.getter()) ? 1 : 0
                iconPointSize: 19
                color: root.itemAccent

                Behavior on color { CAnim {} }
            }
        }

        // ── 2. Center Text Column (Title & Subtitle / Breadcrumb) ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                id: titleText
                Layout.fillWidth: true
                text: {
                    if (!root.modelData) return "";
                    if (root.modelData.type === "setting")
                        return root.modelData.title || "";
                    return root.modelData.name || "";
                }
                textPointSize: Tokens.font.size.normal
                font.weight: root.isCurrent ? Font.DemiBold : Font.Normal
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight

                Behavior on color { CAnim {} }
            }

            StyledText {
                id: subText
                Layout.fillWidth: true
                text: {
                    if (!root.modelData) return "";
                    if (root.modelData.type === "toggle")
                        return root.modelData.statusText ? root.modelData.statusText() : "";
                    if (root.modelData.type === "setting")
                        return root.cleanBreadcrumb(root.modelData.breadcrumb || root.modelData.sub || "");
                    if (root.modelData.type === "app")
                        return root.modelData.desc || (root.modelData.entry ? (root.modelData.entry.comment || root.modelData.entry.genericName) : "") || qsTr("Application");
                    return root.modelData.desc || "";
                }
                textPointSize: Tokens.font.size.small
                color: root.isCurrent ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight

                Behavior on color { CAnim {} }
            }
        }

        // ── 3. Right Interactive Slot (Switch / Chevron / Badge) ──
        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 38
            Layout.preferredWidth: {
                if (!root.modelData) return 0;
                if (root.modelData.type === "toggle")
                    return toggleSlotRow.implicitWidth;
                if (root.modelData.type === "setting")
                    return 24;
                if (root.modelData.type === "app")
                    return 48;
                return 24;
            }

            // TOGGLE SLOT: StyledSwitch + Quick Deep-Link Button
            RowLayout {
                id: toggleSlotRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: root.modelData && root.modelData.type === "toggle"

                StyledSwitch {
                    id: inlineSwitch
                    checked: (root.modelData && root.modelData.getter) ? root.modelData.getter() : false
                    cLayer: root.isCurrent ? 2 : 1
                    onToggled: {
                        if (root.modelData && root.modelData.setter)
                            root.modelData.setter(checked);
                    }
                }

                // Deep-link jump to full settings page
                StyledRect {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 8
                    color: openHover.hovered 
                        ? (root.isCurrent ? Qt.alpha(Colours.palette.m3primary, 0.20) : Qt.alpha(Colours.palette.m3onSurface, 0.12))
                        : "transparent"

                    Behavior on color { CAnim {} }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "open_in_new"
                        iconPointSize: 16
                        color: openHover.hovered ? Colours.palette.m3primary : (root.isCurrent ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant)
                    }

                    HoverHandler {
                        id: openHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.openSettings()
                    }
                }
            }

            // SETTING SLOT: Chevron Right Indicator
            MaterialIcon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.modelData && root.modelData.type === "setting"
                text: "chevron_right"
                iconPointSize: 20
                color: root.isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant

                Behavior on color { CAnim {} }
            }

            // APP SLOT: App Category Chip
            StyledRect {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.modelData && root.modelData.type === "app"
                implicitWidth: 44
                implicitHeight: 22
                radius: Tokens.rounding.full
                color: root.isCurrent 
                    ? Colours.palette.m3secondaryContainer 
                    : Qt.alpha(Colours.palette.m3secondaryContainer, 0.7)

                Behavior on color { CAnim {} }

                StyledText {
                    anchors.centerIn: parent
                    text: qsTr("App")
                    color: Colours.palette.m3onSecondaryContainer
                    textPointSize: Tokens.font.size.smaller
                    font.weight: Font.DemiBold
                }
            }

            // COMMAND SLOT: Terminal Action Indicator
            MaterialIcon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.modelData && (root.modelData.type === "command" || (!root.modelData.type && root.modelData.onClicked))
                text: "arrow_forward"
                iconPointSize: 18
                color: root.isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant

                Behavior on color { CAnim {} }
            }
        }
    }
}
