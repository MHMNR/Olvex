
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
        spacing: 0

        SettingRow {
            title: qsTr("Visible toasts")
            description: qsTr("Maximum number of toasts shown at once")
            divider: true
            CustomSpinBox {
                value: Config.qspanel.maxToasts ?? 4
                min: 1
                max: 8
                step: 1
                onValueModified: v => {
                    GlobalConfig.qspanel.maxToasts = v;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Show in fullscreen")
            description: qsTr("When to allow toasts over fullscreen apps")
            divider: false
            Segmented {
                model: [{
                        label: qsTr("Off")
                    }, {
                        label: qsTr("Important")
                    }, {
                        label: qsTr("On")
                    }]
                currentIndex: {
                    const v = Config.qspanel.toasts.fullscreen || "off";
                    return v === "off" ? 0 : v === "important" ? 1 : 2;
                }
                onSelected: i => {
                    GlobalConfig.qspanel.toasts.fullscreen = ["off", "important", "on"][i];
                    GlobalConfig.save();
                }
            }
        }
    }
}
