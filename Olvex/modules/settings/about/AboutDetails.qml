
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.containers

Item {
    id: root
    
    property var session
    property string activeSection: "hero"

    StyledFlickable {
        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick
        contentHeight: detailsLoader.height + (Tokens.padding.large * 2)
        clip: true

        Loader {
            id: detailsLoader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Tokens.padding.large
            
            source: {
                switch(root.activeSection) {
                    case "hero": return "AboutHero.qml";
                    case "system": return "AboutSystem.qml";
                    case "resources": return "AboutResources.qml";
                    default: return "AboutHero.qml";
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
