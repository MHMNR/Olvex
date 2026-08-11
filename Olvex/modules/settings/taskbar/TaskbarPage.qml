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

Item {
    id: root

    property Session session
    property string activeSection: "behavior"
    signal back

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Taskbar")
        subtitle: qsTr("Dock position, behavior and widgets")
        icon: "dock"
        accent: Colours.palette.m3primary
        hostMode: true
        onBack: root.back()

        hostComponent: Component {
            SplitPaneWithDetails {
                anchors.fill: parent
                activeItem: root.activeSection
                paneIdGenerator: function (item) { return String(item); }

                leftContent: Component {
                    TaskbarList {
                        activeSection: root.activeSection
                        onSectionSelected: (sec) => {
                            root.activeSection = sec;
                        }
                    }
                }
                rightDetailsComponent: Component {
                    TaskbarDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
                rightSettingsComponent: Component {
                    TaskbarDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
            }
        }
    }
}
