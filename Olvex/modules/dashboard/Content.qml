
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Olvex.Config
import qs.components
import qs.components.filedialog

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property bool dashboardActive
    readonly property bool needsKeyboard: false
    required property DashboardState dashState
    required property FileDialog facePicker

    readonly property var dashboardTabs: {
        const allTabs = [
            {
                component: dashComponent,
                iconName: "dashboard",
                text: qsTr("Dashboard"),
                enabled: Config.dashboard.showDashboard
            },
            {
                component: calcComponent,
                iconName: "calculate",
                text: qsTr("Calculator"),
                enabled: true
            }
        ];
        return allTabs.filter(tab => tab.enabled);
    }

    readonly property real nonAnimWidth: Math.max(854, (view.implicitWidth > 0 ? view.implicitWidth : 860) + viewWrapper.anchors.margins * 2)
    readonly property real nonAnimHeight: tabs.implicitHeight + tabs.anchors.topMargin + (view.implicitHeight > 0 ? view.implicitHeight : 540) + viewWrapper.anchors.margins * 2

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight

    Tabs {
        id: tabs

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Tokens.padding.normal
        anchors.margins: Tokens.padding.large

        nonAnimWidth: root.nonAnimWidth - anchors.margins * 2
        dashState: root.dashState
        tabs: root.dashboardTabs
    }

    StyledClippingRect {
        id: viewWrapper

        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.large

        radius: Tokens.rounding.normal
        color: "transparent"

        Flickable {
            id: view

            readonly property int currentIndex: root.dashState.currentTab
            readonly property Item currentItem: {
                repeater.count; // Trigger update on count change
                return repeater.itemAt(currentIndex);
            }

            anchors.fill: parent

            flickableDirection: Flickable.HorizontalFlick

            implicitWidth: (currentItem?.item?.implicitWidth ?? currentItem?.implicitWidth) > 0 ? (currentItem?.item?.implicitWidth ?? currentItem?.implicitWidth) : 860
            implicitHeight: (currentItem?.item?.implicitHeight ?? currentItem?.implicitHeight) > 0 ? (currentItem?.item?.implicitHeight ?? currentItem?.implicitHeight) : 540

            contentX: currentItem?.x ?? 0
            contentWidth: row.implicitWidth
            contentHeight: row.implicitHeight

            onContentXChanged: {
                if (!moving || !currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 2)
                    root.dashState.currentTab = Math.min(root.dashState.currentTab + 1, tabs.count - 1);
                else if (x < -currentItem.implicitWidth / 2)
                    root.dashState.currentTab = Math.max(root.dashState.currentTab - 1, 0);
            }

            onDragEnded: {
                if (!currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 10)
                    root.dashState.currentTab = Math.min(root.dashState.currentTab + 1, tabs.count - 1);
                else if (x < -currentItem.implicitWidth / 10)
                    root.dashState.currentTab = Math.max(root.dashState.currentTab - 1, 0);
                else
                    contentX = Qt.binding(() => currentItem?.x ?? 0);
            }

            RowLayout {
                id: row

                Repeater {
                    id: repeater

                    model: ScriptModel {
                        values: root.dashboardTabs
                    }

                    delegate: Loader {
                        id: paneLoader

                        required property int index
                        required property var modelData

                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: (item?.implicitWidth ?? 0) > 0 ? item.implicitWidth : (modelData.component === dashComponent ? 860 : 980)
                        Layout.preferredHeight: (item?.implicitHeight ?? 0) > 0 ? item.implicitHeight : (modelData.component === dashComponent ? 540 : 460)

                        sourceComponent: modelData.component
                        active: true
                    }
                }
            }

            Component {
                id: dashComponent

                Dash {
                    dashboardActive: root.dashboardActive
                    visibilities: root.visibilities
                    dashState: root.dashState
                    facePicker: root.facePicker
                }
            }

            Component {
                id: calcComponent
                Calculator {}
            }

            Behavior on contentX {
                Anim {}
            }
        }
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.EmphasizedLarge
        }
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.EmphasizedLarge
        }
    }
}
