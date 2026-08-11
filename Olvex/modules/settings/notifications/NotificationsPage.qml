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
    signal back
    property string activeSection: "behavior"

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Notifications")
        subtitle: qsTr("Do not disturb, position and app notifications")
        icon: "notifications"
        accent: Colours.palette.m3primary
        onBack: root.back()
        hostMode: true

        hostComponent: Component {
            SplitPaneWithDetails {
                anchors.fill: parent
                activeItem: root.activeSection
                paneIdGenerator: function (item) { return String(item); }

                leftContent: Component {
                    NotificationsList {
                        activeSection: root.activeSection
                        onSectionSelected: (sec) => {
                            root.activeSection = sec;
                        }
                    }
                }
                rightDetailsComponent: Component {
                    NotificationsDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
                rightSettingsComponent: Component {
                    NotificationsDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
            }
        }
    }
}
