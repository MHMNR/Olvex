
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.containers

Item {
    id: root
    
    property var session
    property string activeSection: "behavior"

    StyledFlickable {
        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick
        contentHeight: (detailsLoader.item ? detailsLoader.item.implicitHeight : 600) + (Tokens.padding.large * 2)
        clip: true

        Loader {
            id: detailsLoader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Tokens.padding.large
            height: item ? item.implicitHeight : 0
            
            source: {
                switch(root.activeSection) {
                    case "battery": return "PowerBattery.qml";
                    case "idle": return "PowerTimeouts.qml";
                    case "behavior": return "PowerBehavior.qml";
                    default: return "PowerBattery.qml";
                }
            }
            onLoaded: {
                if (item) {
                    item.session = root.session;
                }
            }
        }
    }
}
