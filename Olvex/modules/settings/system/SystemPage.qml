

import "."
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

Item {
    id: root

    property string activeSection: (session && session.activeSection) ? session.activeSection : "display"
    property Session session
    signal back

    Connections {
        target: root.session ?? null
        function onActiveSectionChanged() {
            if (root.session && root.session.activeSection) {
                root.activeSection = root.session.activeSection;
            }
        }
    }

    SettingsPage {
        anchors.fill: parent
        title: qsTr("System Settings")
        subtitle: qsTr("Displays, clock, keybindings and system options")
        icon: "tune"
        accent: Colours.palette.m3primary
        onBack: root.back()
        hostMode: true

        hostComponent: Component {
            SplitPaneWithDetails {
                anchors.fill: parent
                session: root.session
                activeItem: root.activeSection
                paneIdGenerator: function (item) { return String(item); }

                leftContent: Component {
                    SystemList {
                        session: root.session
                        activeSection: root.activeSection
                        onSectionSelected: (sec) => {
                            root.activeSection = sec;
                        }
                    }
                }
                rightDetailsComponent: Component {
                    SystemDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
                rightSettingsComponent: Component {
                    SystemDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
            }
        }
    }
}
