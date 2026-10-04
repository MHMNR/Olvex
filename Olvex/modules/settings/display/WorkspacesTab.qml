import "."
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

Item {
    id: root

    required property var monitors
    required property var workspaces
    required property var draftWorkspaces

    signal workspaceBound(string wsNumber, string monitorName, bool isDefault)
    signal workspaceUnbound(string wsNumber)

    implicitWidth: parent ? parent.width : 500
    implicitHeight: mainCol.implicitHeight

    Column {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing ? Tokens.spacing.large : 16

        Section {
            title: qsTr("Workspace Monitor Bindings")
            description: qsTr("Assign Hyprland workspaces (1–10) to specific physical displays")
            icon: "grid_view"
            accentColor: Colours.palette.m3primary

            Repeater {
                model: 10

                delegate: SettingRow {
                    id: wsRow
                    required property int index
                    readonly property string wsNum: String(index + 1)
                    readonly property var currentBinding: {
                        if (!root.draftWorkspaces) return null;
                        for (let i = 0; i < root.draftWorkspaces.length; i++) {
                            if (root.draftWorkspaces[i].workspace === wsNum) return root.draftWorkspaces[i];
                        }
                        return null;
                    }

                    title: `${qsTr("Workspace")} ${wsNum}`
                    description: currentBinding
                                 ? `${qsTr("Bound to")} ${currentBinding.monitor}${currentBinding.isDefault ? " (" + qsTr("Default") + ")" : ""}`
                                 : qsTr("Automatic (Follows focus)")

                    RowLayout {
                        spacing: 8

                        OptionPicker {
                            id: monPicker
                            model: {
                                const opts = [{ label: qsTr("Auto / Unbound"), val: "" }];
                                if (root.monitors) {
                                    for (let i = 0; i < root.monitors.length; i++) {
                                        opts.push({ label: root.monitors[i].name, val: root.monitors[i].name });
                                    }
                                }
                                return opts;
                            }
                            currentIndex: {
                                if (!wsRow.currentBinding || !wsRow.currentBinding.monitor) return 0;
                                if (!root.monitors) return 0;
                                const idx = root.monitors.findIndex(m => m.name === wsRow.currentBinding.monitor);
                                return idx >= 0 ? idx + 1 : 0;
                            }
                            onSelected: (idx) => {
                                if (idx === 0) {
                                    root.workspaceUnbound(wsRow.wsNum);
                                } else {
                                    const monName = root.monitors[idx - 1].name;
                                    const isDef = wsRow.currentBinding ? !!wsRow.currentBinding.isDefault : false;
                                    root.workspaceBound(wsRow.wsNum, monName, isDef);
                                }
                            }
                        }

                        // Default workspace chip toggle
                        StyledRect {
                            id: isDefaultChip
                            visible: !!wsRow.currentBinding && !!wsRow.currentBinding.monitor
                            implicitWidth: 64
                            implicitHeight: 32
                            radius: Tokens.rounding ? Tokens.rounding.small : 8
                            readonly property bool isDefault: wsRow.currentBinding ? !!wsRow.currentBinding.isDefault : false

                            color: isDefaultChip.isDefault ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh
                            border.width: 1
                            border.color: isDefaultChip.isDefault ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.4)

                            StyledText {
                                anchors.centerIn: parent
                                text: qsTr("Default")
                                textPointSize: (Tokens.font ? Tokens.font.size.smaller : 11) - 2
                                font.weight: isDefaultChip.isDefault ? Font.Bold : Font.Normal
                                color: isDefaultChip.isDefault ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            }

                            StateLayer {
                                radius: parent.radius
                                onClicked: {
                                    if (wsRow.currentBinding) {
                                        root.workspaceBound(wsRow.wsNum, wsRow.currentBinding.monitor, !isDefaultChip.isDefault);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
