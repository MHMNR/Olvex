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

    property Session session
    signal back
    property string activeSection: (session && session.activeSection) ? session.activeSection : "wifi"

    Connections {
        target: root.session ?? null
        function onActiveSectionChanged() {
            if (root.session && root.session.activeSection) {
                root.activeSection = root.session.activeSection;
            }
        }
    }

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
