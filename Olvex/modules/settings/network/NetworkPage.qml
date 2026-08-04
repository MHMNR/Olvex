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
    property string activeSection: "wifi"

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Network & Connectivity")
        subtitle: qsTr("Wi-Fi, Bluetooth and VPN controls")
        icon: "wifi"
        accent: Colours.palette.m3primary
        onBack: root.back()
        hostMode: true

        hostComponent: Component {
            SplitPaneWithDetails {
                anchors.fill: parent
                activeItem: root.activeSection
                paneIdGenerator: function (item) { return String(item); }

                leftContent: Component {
                    NetworkList {
                        activeSection: root.activeSection
                        onSectionSelected: (sec) => {
                            root.activeSection = sec;
                        }
                    }
                }
                rightDetailsComponent: Component {
                    NetworkDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
                rightSettingsComponent: Component {
                    NetworkDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
            }
        }
    }
}
