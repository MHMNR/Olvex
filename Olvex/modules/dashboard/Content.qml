
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
        clip: true

        Flickable {
            id: view

            readonly property int currentIndex: root.dashState.currentTab
            readonly property Item currentItem: {
                repeater.count; // Trigger update on count change
                return repeater.itemAt(currentIndex);
            }

            anchors.fill: parent
            clip: true

            flickableDirection: Flickable.HorizontalFlick

            implicitWidth: (currentItem?.implicitWidth ?? (currentItem?.item?.implicitWidth ?? 0)) > 0
                ? (currentItem?.implicitWidth ?? currentItem?.item?.implicitWidth)
                : (root.dashState.currentTab === 1 ? 980 : 860)
            implicitHeight: (currentItem?.implicitHeight ?? (currentItem?.item?.implicitHeight ?? 0)) > 0
                ? (currentItem?.implicitHeight ?? currentItem?.item?.implicitHeight)
                : (root.dashState.currentTab === 1 ? 460 : 540)

            contentX: currentItem?.x ?? 0
            contentWidth: row.implicitWidth
            contentHeight: row.implicitHeight

            Connections {
                target: root.dashState
                function onCurrentTabChanged() {
                    const item = repeater.itemAt(root.dashState.currentTab);
                    if (item)
                        view.contentX = item.x;
                }
            }

            onContentXChanged: {
                if (!moving)
                    return;

                const cur = repeater.itemAt(currentIndex);
                if (!cur)
                    return;

                const x = contentX - cur.x;
                if (x > cur.implicitWidth / 2)
                    root.dashState.currentTab = Math.min(root.dashState.currentTab + 1, tabs.count - 1);
                else if (x < -cur.implicitWidth / 2)
                    root.dashState.currentTab = Math.max(root.dashState.currentTab - 1, 0);
            }

            onDragEnded: {
                const cur = repeater.itemAt(currentIndex);
                if (!cur)
                    return;

                const x = contentX - cur.x;
                if (x > cur.implicitWidth / 10)
                    root.dashState.currentTab = Math.min(root.dashState.currentTab + 1, tabs.count - 1);
                else if (x < -cur.implicitWidth / 10)
                    root.dashState.currentTab = Math.max(root.dashState.currentTab - 1, 0);
                else
                    contentX = cur.x;
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
                        width: Layout.preferredWidth
                        height: Layout.preferredHeight

                        sourceComponent: modelData.component
                        active: true

                        onXChanged: {
                            if (index === view.currentIndex)
                                view.contentX = x;
                        }

                        Component.onCompleted: {
                            if (index === view.currentIndex)
                                Qt.callLater(() => { view.contentX = x; });
                        }
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
                Calculator {
                    visibilities: root.visibilities
                }
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
