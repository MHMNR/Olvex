
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.containers
import qs.services
import ".."
import "../components"

SettingsPage {
    id: root
    
    property string activeSection: ""
    property Component listComponent: null
    property Component detailsComponent: null
    property Component settingsComponent: null
    property var session
    
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
