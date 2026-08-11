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

    property string activeSection: "theme"

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Appearance")
        subtitle: qsTr("Theme, colors, fonts and motion")
        icon: "palette"
        accent: Colours.palette.m3tertiary
        onBack: root.back()
        hostMode: true

    hostComponent: Component {
        SplitPaneWithDetails {
            anchors.fill: parent
            
            // Dummy activeItem since our pane relies on activeSection string
            activeItem: root.activeSection
            paneIdGenerator: function (item) { return String(item); }

            leftContent: Component {
                AppearanceList {
                    activeSection: root.activeSection
                    onSectionSelected: (sec) => {
                        root.activeSection = sec;
                    }
                }
            }
            rightDetailsComponent: Component {
                AppearanceDetails {
                    session: root.session
                    activeSection: root.activeSection
                }
            }
            
            rightSettingsComponent: Component {
                AppearanceDetails {
                    session: root.session
                    activeSection: root.activeSection
                }
            }
        }
    }
}
}
