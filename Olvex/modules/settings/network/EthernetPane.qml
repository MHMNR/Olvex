pragma ComponentBehavior: Bound


import ".."
import "../chrome"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import Quickshell.Widgets
import Olvex.Config

SplitPaneWithDetails {
    id: root

    required property Session session

    anchors.fill: parent

    activeItem: session.ethernet.active
    paneIdGenerator: function (item) {
        return item ? (item.interface || "") : "";
    }

    leftContent: Component {
        EthernetList {
            session: root.session
        }
    }

    rightDetailsComponent: Component {
        EthernetDetails {
            session: root.session
        }
    }

    rightSettingsComponent: Component {
        StyledFlickable {
            flickableDirection: Flickable.VerticalFlick
            contentHeight: settingsInner.height
            clip: true

            EthernetSettings {
                id: settingsInner

                anchors.left: parent.left
                anchors.right: parent.right
                session: root.session
            }
        }
    }
}
