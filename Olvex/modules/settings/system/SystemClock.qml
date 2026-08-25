
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
    property var appJoin
    property var appSplit
    property var idxOf
    
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
        spacing: 0

        SettingRow {
            title: qsTr("Clock format")
            description: qsTr("12-hour or 24-hour time")
            divider: true
            Segmented {
                minSegmentWidth: 96
                model: [{
                        label: qsTr("24-hour")
                    }, {
                        label: qsTr("12-hour")
                    }]
                currentIndex: GlobalConfig.services.useTwelveHourClock ? 1 : 0
                onSelected: i => {
                    GlobalConfig.services.useTwelveHourClock = i === 1;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Temperature unit")
            description: qsTr("Units used for weather readouts")
            divider: true
            Segmented {
                model: [{
                        label: "°C"
                    }, {
                        label: "°F"
                    }]
                currentIndex: GlobalConfig.services.useFahrenheit ? 1 : 0
                onSelected: i => {
                    GlobalConfig.services.useFahrenheit = i === 1;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Weather location")
            description: qsTr("City used for the weather widget")
            divider: false
            StyledTextField {
                width: 240
                text: GlobalConfig.services.weatherLocation || ""
                onEditingFinished: {
                    GlobalConfig.services.weatherLocation = text;
                    GlobalConfig.save();
                }
            }
        }
    }
}
