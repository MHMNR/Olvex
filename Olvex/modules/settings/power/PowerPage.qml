pragma ComponentBehavior: Bound


import "."
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Olvex.Config
import qs.services

Item {
    id: root

    property Session session
    signal back
    property string activeSection: "battery"
    readonly property bool hasBattery: UPower.displayDevice && UPower.displayDevice.isPresent

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Power & Idle")
        subtitle: root.hasBattery ? qsTr("Sleep, idle actions and battery") : qsTr("Sleep, idle actions and performance")
        icon: root.hasBattery ? "battery_charging_full" : "bolt"
        accent: Colours.palette.m3secondary
        onBack: root.back()
        hostMode: true

        hostComponent: Component {
            SplitPaneWithDetails {
                anchors.fill: parent
                activeItem: root.activeSection
                paneIdGenerator: function (item) { return String(item); }

                leftContent: Component {
                    PowerList {
                        activeSection: root.activeSection
                        onSectionSelected: (sec) => {
                            root.activeSection = sec;
                        }
                    }
                }
                rightDetailsComponent: Component {
                    PowerDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
                rightSettingsComponent: Component {
                    PowerDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
            }
        }
    }
}
