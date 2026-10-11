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
    property string activeSection: "output"

    onActiveSectionChanged: flick.contentY = 0

    StyledFlickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        flickableDirection: Flickable.VerticalFlick
        contentHeight: detailsLoader.height + (Tokens.padding.large * 2)
        clip: true

        Loader {
            id: detailsLoader
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
                switch(root.activeSection) {
                    case "output": return "SoundOutput.qml";
                    case "input": return "SoundInput.qml";
                    case "apps": return "SoundApps.qml";
                    case "uisounds": return "SoundUiSounds.qml";
                    case "behavior": return "SoundBehavior.qml";
                    default: return "SoundOutput.qml";
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
