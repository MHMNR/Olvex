pragma ComponentBehavior: Bound

import ".."
import "."
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

    property string activeSection: "dashboard"

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Panels & Drawers")
        subtitle: qsTr("Layout, drawers and flyouts controls")
        icon: "dashboard_customize"
        accent: Colours.palette.m3secondary
        onBack: root.back()
        hostMode: true

        hostComponent: Component {
            SplitPaneWithDetails {
                anchors.fill: parent
                
                activeItem: root.activeSection
                paneIdGenerator: function (item) { return String(item); }

                leftContent: Component {
                    PanelsList {
                        activeSection: root.activeSection
                        onSectionSelected: (sec) => {
                            root.activeSection = sec;
                        }
                    }
                }
                rightDetailsComponent: Component {
                    PanelsDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
                
                rightSettingsComponent: Component {
                    PanelsDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
            }
        }
    }
}
