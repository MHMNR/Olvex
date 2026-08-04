
import ".."
import "../chrome"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls

Item {
    id: root
    
    property var session
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.long; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.long; easing.type: Easing.OutCubic }
    }

    implicitHeight: col.implicitHeight + Tokens.padding.large * 2
    
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
                title: qsTr("Occupied background")
                description: qsTr("Show background on workspaces with windows")
                divider: true
                StyledSwitch {
                    checked: Config.bar.workspaces.occupiedBg ?? false
                    onToggled: {
                        GlobalConfig.bar.workspaces.occupiedBg = checked;
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
                title: qsTr("Inverted colors")
                description: qsTr("Invert the active window text colors")
                divider: false
                StyledSwitch {
                    checked: Config.bar.activeWindow.inverted ?? false
                    onToggled: { GlobalConfig.bar.activeWindow.inverted = checked; GlobalConfig.save(); }
                }
            }
        }
    }
}
