
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
    readonly property int detailHeight: labelHeight + (hasWindows ? (windows.item?.implicitHeight ?? 0) + Tokens.padding.small : 0)
    readonly property int collapsedHeight: isOccupied ? dotDiameter : ringDiameter

    // Unanimated prop for others (ActiveIndicator) to use as reference
    readonly property int size: showDetail ? detailHeight : collapsedHeight

    Layout.alignment: Qt.AlignHCenter
    Layout.preferredHeight: size
    implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2

    Behavior on Layout.preferredHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    // ── Collapsed: occupied dot or empty ring ───────────────────────
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.collapsedHeight
        height: width
        radius: width / 2
        color: root.isOccupied ? Colours.palette.m3onSurfaceVariant : "transparent"
        border.width: root.isOccupied ? 0 : 2
        border.color: Colours.layer(Colours.palette.m3outlineVariant, 2)

        opacity: root.showDetail ? 0 : 1
        scale: root.showDetail ? 0.4 : 1
        visible: opacity > 0.01

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.FastEffects
            }
        }

        Behavior on color {
            CAnim {}
        }
    }

    // ── Detail: number + open-app glyphs (current, or any slot while expanded) ──
    ColumnLayout {
        id: detailCol

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: 0

        opacity: root.showDetail ? 1 : 0
        scale: root.showDetail ? 1 : 0.4
        visible: opacity > 0.01

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.FastEffects
            }
        }

        StyledText {
            id: labelText

            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredHeight: root.labelHeight

            animate: true
            text: {
                const ws = Hypr.workspaces.values.find(w => w.id === root.ws);
                const wsName = !ws || ws.name == root.ws ? root.ws : ws.name[0];
                let displayName = wsName.toString();
                if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper") {
                    displayName = displayName.toUpperCase();
                } else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower") {
                    displayName = displayName.toLowerCase();
                }
                const label = Config.bar.workspaces.label || displayName;
                const occupiedLabel = Config.bar.workspaces.occupiedLabel || label;
                const activeLabel = Config.bar.workspaces.activeLabel || (root.isOccupied ? occupiedLabel : label);
                return root.isCurrent ? activeLabel : root.isOccupied ? occupiedLabel : label;
            }
            color: root.isOccupied || root.isCurrent ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)
            verticalAlignment: Qt.AlignVCenter
        }

        Loader {
            id: windows

            asynchronous: true

            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -Tokens.sizes.bar.innerWidth / 10

            // Stays loaded whenever occupied (not gated on showDetail) so its
            // height is always known for detailHeight above — visibility is
            // handled by the parent detailCol's opacity/scale fade instead.
            visible: active
            active: root.hasWindows

            sourceComponent: Column {
                spacing: 0

                add: Transition {
                    Anim {
                        properties: "scale"
                        from: 0
                        to: 1
                        easing: Tokens.anim.standardDecel
                    }
                }

                move: Transition {
                    Anim {
                        properties: "scale"
                        to: 1
                        easing: Tokens.anim.standardDecel
                    }
                    Anim {
                        properties: "x,y"
                    }
                }

                Repeater {
                    model: ScriptModel {
                        values: {
                            const ws = root.ws;
                            const windows = Hypr.toplevels.values.filter(c => c.workspace?.id === ws);
                            const maxIcons = root.Config.bar.workspaces.maxWindowIcons;
                            return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                        }
                    }

                    MaterialIcon {
                        required property var modelData

                        grade: 0
                        text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
