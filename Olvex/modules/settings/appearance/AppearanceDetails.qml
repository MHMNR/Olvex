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
    property string activeSection: "theme"

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
                    case "theme": return "AppearanceTheme.qml";
                    case "transparency": return "AppearanceTransparency.qml";
                    case "fonts": return "AppearanceFonts.qml";
                    case "shape": return "AppearanceShape.qml";
                    case "motion": return "AppearanceMotion.qml";
                    case "wallpapers": return "AppearanceWallpapers.qml";
                    case "lockscreen": return "AppearanceLockscreen.qml";
                    default: return "AppearanceTheme.qml";
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
