import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services
import "../chrome"
import "../components"

Item {
    id: root

    property var session
    signal back
    property string activeSection: "hero"

    SettingsPage {
        anchors.fill: parent
        title: qsTr("About Olvex")
        subtitle: qsTr("System specs, version and information")
        icon: "deployed_code"
        accent: Colours.palette.m3primary
        onBack: root.back()
        hostMode: true

        hostComponent: Component {
            SplitPaneWithDetails {
                anchors.fill: parent
                activeItem: root.activeSection
                paneIdGenerator: function (item) { return String(item); }

                leftContent: Component {
                    AboutList {
                        activeSection: root.activeSection
                        onSectionSelected: (sec) => {
                            root.activeSection = sec;
                        }
                    }
                }
                rightDetailsComponent: Component {
                    AboutDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
                rightSettingsComponent: Component {
                    AboutDetails {
                        session: root.session
                        activeSection: root.activeSection
                    }
                }
            }
        }
    }
}
