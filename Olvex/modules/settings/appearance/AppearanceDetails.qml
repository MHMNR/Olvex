import ".."
import "../ui"
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

    readonly property bool selfScrolled: activeSection === "icons" || activeSection === "cursor" || activeSection === "wallpapers"

    onActiveSectionChanged: {
        if (flick) flick.contentY = 0;
    }

    // Direct loader for pages with pinned headers and internal scrolling (AppearanceIcons, AppearanceCursor, AppearanceWallpapers)
    Loader {
        id: directLoader
        anchors.fill: parent
        anchors.topMargin: Tokens.padding.normal
        anchors.bottomMargin: Tokens.padding.normal
        active: root.selfScrolled
        visible: active
        source: {
            if (root.activeSection === "icons") return "AppearanceIcons.qml";
            if (root.activeSection === "cursor") return "AppearanceCursor.qml";
            if (root.activeSection === "wallpapers") return "AppearanceWallpapers.qml";
            return "";
        }

        Binding {
            target: directLoader.item
            property: "session"
            value: root.session
            restoreMode: Binding.RestoreBindingOrValue
        }
    }

    // Outer flickable for standard linear settings pages (Theme, Fonts, Transparency, etc.)
    StyledFlickable {
        id: flick
        anchors.fill: parent
        visible: !root.selfScrolled
        contentWidth: width
        flickableDirection: Flickable.VerticalFlick
        contentHeight: detailsLoader.height + (Tokens.padding.large * 2)
        clip: false

        Loader {
            id: detailsLoader
            active: !root.selfScrolled
            height: item ? (item.implicitHeight > 0 ? item.implicitHeight : item.height) : 0
            onLoaded: {
                if (item) {
                    item.width = Qt.binding(() => width);
                    height = Qt.binding(() => item ? (item["implicitHeight"] || item["height"] || 0) : 0);
                }
            }
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Tokens.padding.large
            
            source: {
                if (root.selfScrolled) return "";
                switch(root.activeSection) {
                    case "theme": return "AppearanceTheme.qml";
                    case "transparency": return "AppearanceTransparency.qml";
                    case "fonts": return "AppearanceFonts.qml";
                    case "shape": return "AppearanceShape.qml";
                    case "motion": return "AppearanceMotion.qml";
                    case "clock": return "AppearanceClock.qml";
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
