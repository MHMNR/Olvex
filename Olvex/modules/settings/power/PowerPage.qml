import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services
import "../chrome"
import "../components"

Item {
    id: root

    property var session
    signal back
    property string activeSection: "battery"

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Power & Idle")
        subtitle: qsTr("Sleep, idle actions and battery")
        icon: "battery_charging_full"
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
