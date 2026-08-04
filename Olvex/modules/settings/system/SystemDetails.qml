
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.containers

Item {
    id: root
    
    property var session
    property string activeSection: "apps"

    // Helper functions moved from SystemPage.qml
    function appJoin(list): string {
        if (!list || !list.length)
            return "";
        const parts = [];
        for (let i = 0; i < list.length; i++)
            parts.push(String(list[i]));
        return parts.join(" ");
    }

    function appSplit(text: string): var {
        const t = (text || "").trim();
        if (!t)
            return [];
        return t.split(/\s+/);
    }

    function idxOf(list, val) {
        const v = (val || "").toLowerCase();
        for (let i = 0; i < list.length; i++) {
            if (String(list[i]).toLowerCase() === v)
                return i;
        }
        return 0;
    }

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
                    case "apps": return "SystemApps.qml";
                    case "clock": return "SystemClock.qml";
                    case "media": return "SystemMedia.qml";
                    case "advanced": return "SystemAdvanced.qml";
                    default: return "SystemApps.qml";
                }
            }
            onLoaded: {
                if (item) {
                    item.session = root.session;
                }
            }
            Binding {
                target: detailsLoader.item
                property: "appJoin"
                value: root.appJoin
                restoreMode: Binding.RestoreBindingOrValue
            }
            Binding {
                target: detailsLoader.item
                property: "appSplit"
                value: root.appSplit
                restoreMode: Binding.RestoreBindingOrValue
            }
            Binding {
                target: detailsLoader.item
                property: "idxOf"
                value: root.idxOf
                restoreMode: Binding.RestoreBindingOrValue
            }
        }
    }
}
