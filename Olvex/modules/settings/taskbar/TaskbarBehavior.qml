
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
import qs.utils
import Quickshell

Item {
    id: root
    
    property Session session
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.slow; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.slow; easing.type: Easing.OutCubic }
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

        Section {
            Layout.fillWidth: true
            title: qsTr("Bar Visibility & Reveal")
            description: qsTr("Window overlap and edge gesture behavior")
            icon: "dock"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Persistent")
                description: qsTr("Keep the bar visible even when windows are maximized")
                StyledSwitch {
                    checked: (Config.bar.persistent !== undefined) ? Config.bar.persistent : true
                    onToggled: {
                        GlobalConfig.bar.persistent = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Show on hover")
                description: qsTr("Automatically reveal taskbar when mouse hovers over screen edge")
                StyledSwitch {
                    checked: (Config.bar.showOnHover !== undefined) ? Config.bar.showOnHover : true
                    onToggled: {
                        GlobalConfig.bar.showOnHover = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Drag threshold")
                description: qsTr("Edge distance required to reveal the bar (pixels)")
                CustomSpinBox {
                    value: Config.bar.dragThreshold || 20
                    min: 0
                    max: 100
                    step: 1
                    onValueModified: v => {
                        GlobalConfig.bar.dragThreshold = v;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            Layout.fillWidth: true
            title: qsTr("Display Assignment")
            description: qsTr("Choose which connected monitors display the taskbar")
            icon: "monitor"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                Layout.fillWidth: true
                title: qsTr("Monitors")
                description: qsTr("Toggle displays on which the bar should appear")

                Flow {
                    spacing: Tokens.spacing.small
                    Repeater {
                        model: Hypr.monitorNames()
                        delegate: StyledRect {
                            required property string modelData
                            implicitWidth: lbl.implicitWidth + Tokens.padding.large * 2
                            implicitHeight: 32
                            radius: Tokens.rounding.full

                            readonly property bool isIncluded: !(Config.bar.excludedScreens || []).includes(modelData)

                            color: isIncluded ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

                            Behavior on color { CAnim {} }

                            StyledText {
                                id: lbl
                                anchors.centerIn: parent
                                text: qsTr(modelData)
                                color: isIncluded ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                font.weight: Font.Medium
                                textPointSize: Tokens.font.size.small
                            }

                            StateLayer {
                                radius: parent.radius
                                onClicked: {
                                    let excl = [...(Config.bar.excludedScreens || [])];
                                    const idx = excl.indexOf(modelData);
                                    if (idx !== -1) {
                                        excl.splice(idx, 1);
                                    } else {
                                        excl.push(modelData);
                                    }
                                    GlobalConfig.bar.excludedScreens = excl;
                                    GlobalConfig.save();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}