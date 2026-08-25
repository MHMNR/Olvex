
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config

Item {
    id: root
    
    property Session session
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens?.anim?.durations?.slow ?? 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens?.anim?.durations?.slow ?? 400; easing.type: Easing.OutCubic }
    }

    implicitHeight: (col ? col.implicitHeight : 0) + Tokens.padding.large * 2
    
    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        spacing: Tokens.spacing.large

        Column {
            Layout.fillWidth: true
            spacing: 0
            
            SettingRow {
                title: qsTr("Workspaces shown")
                description: qsTr("Number of workspaces to show")
                divider: true
                CustomSpinBox {
                    value: Config.bar.workspaces.shown ?? 5
                    min: 1
                    max: 20
                    step: 1
                    onValueModified: v => {
                        GlobalConfig.bar.workspaces.shown = v;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Per monitor workspaces")
                description: qsTr("Only show workspaces on the active monitor")
                divider: true
                StyledSwitch {
                    checked: GlobalConfig.bar.workspaces.perMonitorWorkspaces ?? true
                    onToggled: {
                        GlobalConfig.bar.workspaces.perMonitorWorkspaces = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Active indicator")
                description: qsTr("Highlight the current workspace")
                divider: true
                StyledSwitch {
                    checked: Config.bar.workspaces.activeIndicator ?? true
                    onToggled: {
                        GlobalConfig.bar.workspaces.activeIndicator = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Active indicator icon")
                description: qsTr("Icon or number style for the active workspace")
                divider: true
                OptionPicker {
                    id: tbActiveLabelPicker
                    model: [
                        { label: qsTr("Filled Circle Number"), preview: "❶", isMaterial: false, value: "filled_number" },
                        { label: qsTr("Pacman"), preview: "󰮯", isMaterial: false, value: "󰮯" },
                        { label: qsTr("Star"), preview: "star", isMaterial: true, value: "star" },
                        { label: qsTr("Plain Number"), preview: "1", isMaterial: false, value: "number" },
                        { label: qsTr("Circled Number"), preview: "①", isMaterial: false, value: "circle_number" },
                        { label: qsTr("Arch Linux"), preview: "󰣇", isMaterial: false, value: "󰣇" },
                        { label: qsTr("Fire"), preview: "local_fire_department", isMaterial: true, value: "local_fire_department" },
                        { label: qsTr("Lightning"), preview: "bolt", isMaterial: true, value: "bolt" },
                        { label: qsTr("Sparkles"), preview: "auto_awesome", isMaterial: true, value: "auto_awesome" },
                        { label: qsTr("Rocket"), preview: "rocket_launch", isMaterial: true, value: "rocket_launch" },
                        { label: qsTr("Heart"), preview: "favorite", isMaterial: true, value: "favorite" },
                        { label: qsTr("Terminal"), preview: "terminal", isMaterial: true, value: "terminal" },
                        { label: qsTr("Code"), preview: "code", isMaterial: true, value: "code" },
                        { label: qsTr("Dot"), preview: "circle", isMaterial: true, value: "circle" }
                    ]
                    currentIndex: {
                        const cur = Config.bar.workspaces.activeLabel ?? "󰮯";
                        for (let i = 0; i < model.length; i++) {
                            const v = model[i].value;
                            if (v === cur) return i;
                            if (v === "star" && cur === "") return i;
                            if (v === "local_fire_department" && cur === "󰈸") return i;
                            if (v === "bolt" && (cur === "󱐋" || cur === "zap")) return i;
                            if (v === "auto_awesome" && cur === "󰫢") return i;
                            if (v === "rocket_launch" && cur === "󰄛") return i;
                            if (v === "favorite" && cur === "󰋑") return i;
                            if (v === "terminal" && cur === "󰞷") return i;
                            if (v === "code" && cur === "󰘐") return i;
                            if (v === "circle" && cur === "") return i;
                        }
                        return 0;
                    }
                    onSelected: i => {
                        const opt = model[i];
                        GlobalConfig.bar.workspaces.activeLabel = opt.value;
                        GlobalConfig.save();
                    }
                }
            }



            SettingRow {
                title: qsTr("Scroll to switch workspaces")
                description: qsTr("Adjust workspaces by scrolling over the bar")
                divider: true
                StyledSwitch {
                    checked: Config.bar.scrollActions.workspaces ?? true
                    onToggled: {
                        GlobalConfig.bar.scrollActions.workspaces = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Show windows")
                description: qsTr("Show small icons of open applications")
                divider: true
                StyledSwitch {
                    checked: Config.bar.workspaces.showWindows ?? false
                    onToggled: {
                        GlobalConfig.bar.workspaces.showWindows = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Max window icons")
                description: qsTr("Limit the number of icons shown")
                divider: false
                CustomSpinBox {
                    value: Config.bar.workspaces.maxWindowIcons ?? 0
                    min: 0
                    max: 20
                    step: 1
                    onValueModified: v => {
                        GlobalConfig.bar.workspaces.maxWindowIcons = v;
                        GlobalConfig.save();
                    }
                }
            }
        }
        
        Section {
            Layout.fillWidth: true
            title: qsTr("Active Window")
            description: qsTr("Show currently focused application title")
            icon: "window"
            
            SettingRow {
                title: qsTr("Compact mode")
                description: qsTr("Use a smaller layout for the title")
                divider: true
                StyledSwitch {
                    checked: Config.bar.activeWindow.compact ?? false
                    onToggled: { GlobalConfig.bar.activeWindow.compact = checked; GlobalConfig.save(); }
                }
            }

            SettingRow {
                title: qsTr("Inverted text alignment")
                description: qsTr("Invert the active window text alignment direction")
                divider: false
                StyledSwitch {
                    checked: Config.bar.activeWindow.inverted ?? false
                    onToggled: { GlobalConfig.bar.activeWindow.inverted = checked; GlobalConfig.save(); }
                }
            }
        }
    }
}
