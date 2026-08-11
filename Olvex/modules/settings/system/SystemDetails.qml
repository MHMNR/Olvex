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
                    case "apps": return "SystemApps.qml";
                    case "clock": return "SystemClock.qml";
                    case "media": return "SystemMedia.qml";
                    case "advanced": return "SystemAdvanced.qml";
                    default: return "SystemApps.qml";
                }
            }
            Binding {
                target: detailsLoader.item
                property: "session"
                value: root.session
                restoreMode: Binding.RestoreBindingOrValue
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
