import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.containers
import qs.services
import "../chrome"
import "../components"

Item {
    id: root

    property var session
    property string activeSection: "behavior"

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Taskbar")
        subtitle: qsTr("Dock position, behavior and widgets")
        icon: "dock"
        accent: Colours.palette.m3primary
        hostMode: true

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
