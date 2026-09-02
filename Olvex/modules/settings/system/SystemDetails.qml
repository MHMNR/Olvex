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
    property string activeSection: "keybinds"

    // Helper functions moved from SystemPage.qml
    readonly property var appJoin: function(list) {
        if (!list || !list.length)
            return "";
        const parts = [];
        for (let i = 0; i < list.length; i++)
            parts.push(String(list[i]));
        return parts.join(" ");
    }

    readonly property var appSplit: function(text) {
        const t = (text || "").trim();
        if (!t)
            return [];
        return t.split(/\s+/);
    }

    readonly property var idxOf: function(list, val) {
        const v = (val || "").toLowerCase();
        for (let i = 0; i < list.length; i++) {
            if (String(list[i]).toLowerCase() === v)
                return i;
        }
        return 0;
    }

    Loader {
        id: detailsLoader
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        
        onLoaded: {
            if (item) {
                if ("session" in item) item.session = root.session;
                if ("appJoin" in item) item.appJoin = root.appJoin;
                if ("appSplit" in item) item.appSplit = root.appSplit;
                if ("idxOf" in item) item.idxOf = root.idxOf;
            }
        }
                    
        source: {
            switch(root.activeSection) {
                case "keybinds": return "SystemKeybinds.qml";
                case "apps": return "SystemKeybinds.qml";
                case "clock": return "SystemClock.qml";
                case "media": return "SystemMedia.qml";
                case "advanced": return "SystemAdvanced.qml";
                default: return "SystemKeybinds.qml";
            }
        }
    }
}
