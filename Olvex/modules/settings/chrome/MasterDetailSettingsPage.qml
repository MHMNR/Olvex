pragma ComponentBehavior: Bound


import ".."
import "."
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

SettingsPage {
    id: root
    
    property string activeSection: ""
    property Component listComponent: null
    property Component detailsComponent: null
    property Component settingsComponent: null
    property Session session
    
    hostMode: true

    hostComponent: Component {
        SplitPaneWithDetails {
            anchors.fill: parent
            
            // Dummy activeItem since our pane relies on activeSection string
            activeItem: root.activeSection
            paneIdGenerator: function (item) { return String(item); }

            leftContent: root.listComponent
            rightDetailsComponent: root.detailsComponent
            rightSettingsComponent: root.settingsComponent
        }
    }
}
