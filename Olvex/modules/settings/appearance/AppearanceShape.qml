pragma ComponentBehavior: Bound


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

ColumnLayout {
    id: root
    
    property Session session
    spacing: Tokens.spacing.large
    opacity: 0.0
    transform: Translate { y: 20; id: yTrans }

    Component.onCompleted: {
        revealAnim.start();
    }

    ParallelAnimation {
        id: revealAnim
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: yTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutCubic }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Shape & spacing")
        description: qsTr("Corner rounding, density, and drawer Hugging / Floating mode")
        icon: "aspect_ratio"

        SettingRow {
            title: qsTr("Rounding scale")
            description: qsTr("Multiplier for all corner radii")
            StyledSlider {
                width: 220
                from: 0.5
                to: 1.5
                value: GlobalConfig.appearance.rounding.scale
                onMoved: {
                    GlobalConfig.appearance.rounding.scale = value;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Spacing scale")
            description: qsTr("Multiplier for gaps between elements")
            StyledSlider {
                width: 220
                from: 0.5
                to: 1.5
                value: GlobalConfig.appearance.spacing.scale
                onMoved: {
                    GlobalConfig.appearance.spacing.scale = value;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Padding scale")
            description: qsTr("Multiplier for padding inside elements")
            StyledSlider {
                width: 220
                from: 0.5
                to: 1.5
                value: GlobalConfig.appearance.padding.scale
                onMoved: {
                    GlobalConfig.appearance.padding.scale = value;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Drawer mode")
            description: qsTr("Hugging sticks panels to screen edges; Floating leaves a gap")
            Segmented {
                minSegmentWidth: 100
                implicitHeight: 42
                model: [{
                        label: qsTr("Hugging"),
                        icon: "align_horizontal_left"
                    }, {
                        label: qsTr("Floating"),
                        icon: "picture_in_picture_center"
                    }]
                currentIndex: GlobalConfig.border.floating ? 1 : 0
                onSelected: i => {
                    GlobalConfig.border.floating = (i === 1);
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Border rounding")
            description: qsTr("Corner radius of the screen border")
            divider: false
            CustomSpinBox {
                value: GlobalConfig.border.rounding
                min: 0
                max: 40
                step: 2
                onValueModified: v => {
                    GlobalConfig.border.rounding = v;
                    GlobalConfig.save();
                }
            }
        }
    }
}
