import ".."
import "../chrome"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config

Item {
    id: root
    
    property Session session
    property string activeSection: "behavior"

    StyledFlickable {
        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick
        contentHeight: detailsLoader.height + (Tokens.padding.large * 2)
        clip: true

        Loader {
            id: detailsLoader
            onLoaded: if (item) height = Qt.binding(() => item ? (item["implicitHeight"] || 0) : 0);
                        anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Tokens.padding.large
                        
            source: {
                switch(root.activeSection) {
                    case "battery": return "PowerBattery.qml";
                    case "idle": return "PowerTimeouts.qml";
                    case "behavior": return "PowerBehavior.qml";
                    default: return "PowerBattery.qml";
                }
            }
            Binding {
                target: detailsLoader.item
                property: "session"
                value: root.session
                restoreMode: Binding.RestoreBindingOrValue
            }
        }
    }
}
