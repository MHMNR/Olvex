pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.containers

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
