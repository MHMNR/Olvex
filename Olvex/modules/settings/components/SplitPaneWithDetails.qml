import ".."
import "../ui"
import "."
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Olvex.Config

Item {
    id: root

    required property Component leftContent
    required property Component rightDetailsComponent
    required property Component rightSettingsComponent

    property var session: null
    property var activeItem: null
    property var paneIdGenerator: function (item) {
        return item ? String(item) : "";
    }

    property Component overlayComponent: null
    property alias collapsed: splitLayout.collapsed
    property alias splitLayout: splitLayout

    SplitPaneLayout {
        id: splitLayout

        anchors.fill: parent

        leftContent: root.leftContent

        rightContent: Component {
            Item {
                id: rightPaneItem

                property var pane: root.activeItem
                property string paneId: root.paneIdGenerator(pane)
                property Component targetComponent: root.rightSettingsComponent
                property Component nextComponent: root.rightSettingsComponent

                function getComponentForPane() {
                    return pane ? root.rightDetailsComponent : root.rightSettingsComponent;
                }

                Component.onCompleted: {
                    targetComponent = getComponentForPane();
                    nextComponent = targetComponent;
                    if (root.session && root.session.flashCount > 0) {
                        detailsFlashAnim.restart();
                    }
                }

                onPaneChanged: {
                    nextComponent = getComponentForPane();
                    paneId = root.paneIdGenerator(pane);
                }

                Loader {
                    id: rightLoader

                    anchors.fill: parent

                    asynchronous: true
                    opacity: 1
                    scale: 1
                    transformOrigin: Item.Center

                    clip: false
                    sourceComponent: rightPaneItem.targetComponent
                }

                // ── Android-style Flash Highlight on Target Content ──
                StyledRect {
                    id: detailsFlashOverlay
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    radius: Tokens.rounding.large
                    color: Qt.alpha(Colours.palette.m3primary, 0.14)
                    border.color: Qt.alpha(Colours.palette.m3primary, 0.55)
                    border.width: 2
                    opacity: 0
                    z: 50
                    visible: opacity > 0.001

                    SequentialAnimation {
                        id: detailsFlashAnim
                        PauseAnimation { duration: 160 }
                        NumberAnimation { target: detailsFlashOverlay; property: "opacity"; to: 1.0; duration: 160; easing.type: Easing.OutQuad }
                        NumberAnimation { target: detailsFlashOverlay; property: "opacity"; to: 0.25; duration: 240; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: detailsFlashOverlay; property: "opacity"; to: 0.90; duration: 180; easing.type: Easing.OutQuad }
                        NumberAnimation { target: detailsFlashOverlay; property: "opacity"; to: 0.0; duration: 900; easing.type: Easing.OutCubic }
                    }
                }

                Connections {
                    target: root.session ?? null
                    function onFlashRequested() {
                        detailsFlashAnim.restart();
                    }
                }

                Behavior on paneId {
                    PaneTransition {
                        target: rightLoader
                        propertyActions: [
                            PropertyAction {
                                target: rightPaneItem
                                property: "targetComponent"
                                value: rightPaneItem.nextComponent
                            }
                        ]
                    }
                }
            }
        }
    }

    Loader {
        id: overlayLoader

        anchors.fill: parent
        asynchronous: true
        z: 1000
        sourceComponent: root.overlayComponent
        active: root.overlayComponent !== null
    }
}
