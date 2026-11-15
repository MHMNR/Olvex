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

    readonly property bool selfScrolled: activeSection === "display" || activeSection === "keybinds" || activeSection === "apps"

    onActiveSectionChanged: {
        if (flick) flick.contentY = 0;
    }

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

    // Self-scrolled pages (DisplayPage, SystemKeybinds)
    Loader {
        id: directLoader
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        asynchronous: true
        active: root.selfScrolled
        visible: active

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
                case "display": return "../display/DisplayPage.qml";
                case "keybinds": return "SystemKeybinds.qml";
                case "apps": return "SystemKeybinds.qml";
                default: return "";
            }
        }
    }

    // Outer flickable for linear system settings pages (Input, Clock, Default Apps, Startup, Privacy, Media, Advanced)
    StyledFlickable {
        id: flick
        anchors.fill: parent
        visible: !root.selfScrolled
        contentWidth: width
        flickableDirection: Flickable.VerticalFlick
        contentHeight: detailsLoader.height + (Tokens.padding.large * 2)
        clip: true

        Loader {
            id: detailsLoader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Tokens.padding.large
            asynchronous: true
            active: !root.selfScrolled
            height: item ? (item.implicitHeight > 0 ? item.implicitHeight : item.height) : 0

            onLoaded: {
                if (item) {
                    item.width = Qt.binding(() => width);
                    height = Qt.binding(() => item ? (item["implicitHeight"] || item["height"] || 0) : 0);
                    if ("session" in item) item.session = root.session;
                    if ("appJoin" in item) item.appJoin = root.appJoin;
                    if ("appSplit" in item) item.appSplit = root.appSplit;
                    if ("idxOf" in item) item.idxOf = root.idxOf;
                }
            }

            source: {
                switch(root.activeSection) {
                    case "input": return "SystemInput.qml";
                    case "clock": return "SystemClock.qml";
                    case "defaults": return "SystemDefaultApps.qml";
                    case "startup": return "SystemStartup.qml";
                    case "privacy": return "SystemPrivacy.qml";
                    case "media": return "SystemMedia.qml";
                    case "advanced": return "SystemAdvanced.qml";
                    default: return "";
                }
            }
        }
    }
}
