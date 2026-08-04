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
    property string activeSection: "clock"

    SettingsPage {
        anchors.fill: parent
        title: qsTr("System Settings")
        subtitle: qsTr("Clock, default apps and system options")
        icon: "tune"
        accent: Colours.palette.m3primary
        onBack: root.back()
        hostMode: true

        hostComponent: Component {
            SplitPaneWithDetails {
                anchors.fill: parent
                activeItem: root.activeSection
                paneIdGenerator: function (item) { return String(item); }

                leftContent: Component {
                    SystemList {
                        activeSection: root.activeSection
                        onSectionSelected: (sec) => {
                            root.activeSection = sec;
                        }
                    }
                }
                rightDetailsComponent: Component {
                    SystemDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
                rightSettingsComponent: Component {
                    SystemDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
            }
        }
    }
}
