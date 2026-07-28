pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Olvex.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.launcher.items
import qs.modules.launcher.services

Item {
    id: root

    required property StyledTextField search
    required property DrawerVisibilities visibilities

    readonly property int appsRowHeight: 120
    readonly property int appsColumns: 5
    readonly property int appsVisibleRows: 4
    readonly property int appsPaneHeight: appsVisibleRows * appsRowHeight + 10

    readonly property string state: {
        const text = search.text;
        const prefix = GlobalConfig.launcher.actionPrefix;
        if (text.startsWith(prefix)) {
            for (const action of ["calc", "scheme", "variant"])
                if (text.startsWith(`${prefix}${action} `))
                    return action;

            return "actions";
        }

        return "apps";
    }

    onStateChanged: {
        if (state === "scheme" || state === "variant")
            Schemes.reload();
        syncModels();
    }

    Connections {
        target: search
        function onTextChanged(): void {
            searchDebounce.restart();
        }
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged(): void {
            Apps.invalidateCatalog();
            syncModels();
        }
    }

    Timer {
        id: searchDebounce
        interval: 32
        repeat: false
        onTriggered: syncModels()
    }

    ScriptModel {
        id: appScriptModel
    }

    ScriptModel {
        id: actionScriptModel
    }

    function syncModels(): void {
        const text = search.text;
        if (state === "apps")
            appScriptModel.values = Apps.search(text);
        else if (state === "actions")
            actionScriptModel.values = Actions.query(text);
        else if (state === "calc")
            actionScriptModel.values = [0];
        else if (state === "scheme")
            actionScriptModel.values = Schemes.query(text);
        else if (state === "variant")
            actionScriptModel.values = M3Variants.query(text);
        else
            actionScriptModel.values = [];
    }

    readonly property int count: state === "apps" ? appGrid.count : actionList.count
    readonly property int currentIndex: state === "apps" ? appGrid.currentIndex : actionList.currentIndex
    readonly property var currentItem: state === "apps" ? appGrid.currentItem : actionList.currentItem

    function decrementCurrentIndex() {
        if (state === "apps")
            appGrid.currentIndex = Math.max(0, appGrid.currentIndex - appsColumns);
        else
            actionList.decrementCurrentIndex();
    }

    function incrementCurrentIndex() {
        if (state === "apps")
            appGrid.currentIndex = Math.min(appGrid.count - 1, appGrid.currentIndex + appsColumns);
        else
            actionList.incrementCurrentIndex();
    }

    property int revealEpoch: 0

    readonly property var m3Emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]

    function playOpenReveal(): void {
        if (root.state !== "apps" || !root.visibilities.launcher)
            return;
        jellySpring.stop();
        scrollVelocity = 0;
        scrollJellyActive = false;
        revealEpoch++;
    }

    property bool scrollJellyActive: false
    property real scrollVelocity: 0
    property real lastContentY: 0

    function bumpScrollVelocity(impulse: real): void {
        if (!root.scrollJellyActive)
            return;
        scrollVelocity = Math.max(-72, Math.min(72, scrollVelocity + impulse));
        jellySpring.stop();
        jellySpring.from = scrollVelocity;
        jellySpring.to = 0;
        jellySpring.start();
    }

    function suspend(): void {
        smoothScrollAnim.stop();
        jellySpring.stop();
        scrollVelocity = 0;
        scrollJellyActive = false;
        lastContentY = 0;
        appGrid.contentY = 0;
        appGrid.currentIndex = 0;
        actionList.currentIndex = 0;
    }

    function resume(): void {
        if (appScriptModel.values.length === 0 && state === "apps")
            syncModels();
        playOpenReveal();
    }

    Connections {
        target: visibilities
        function onLauncherChanged(): void {
            if (visibilities.launcher)
                Qt.callLater(playOpenReveal);
            else
                suspend();
        }
    }

    NumberAnimation {
        id: smoothScrollAnim
        target: appGrid
        property: "contentY"
        duration: 260
        easing.type: Easing.OutCubic
    }

    SpringAnimation {
        id: jellySpring
        target: root
        property: "scrollVelocity"
        to: 0
        spring: 3.4
        damping: 0.72
        epsilon: 0.04

        onStopped: root.scrollJellyActive = false
    }

    Connections {
        target: appGrid
        enabled: appGrid.visible
        ignoreUnknownSignals: true

        function onContentYChanged(): void {
            if (!root.scrollJellyActive)
                return;
            const dy = appGrid.contentY - root.lastContentY;
            root.lastContentY = appGrid.contentY;
            if (Math.abs(dy) < 0.05)
                return;
            root.bumpScrollVelocity(Math.max(-72, Math.min(72, dy * 5.0)));
        }

        function onMovementStarted(): void {
            root.scrollJellyActive = true;
        }

        function onFlickStarted(): void {
            root.scrollJellyActive = true;
        }
    }

    Component.onCompleted: {
        Apps.warmCatalog();
        syncModels();
    }

    implicitWidth: state === "apps" ? 590 : Tokens.sizes.launcher.itemWidth
    implicitHeight: {
        if (state === "apps")
            return appsPaneHeight;
        const maxShown = Config.launcher.maxShown ?? 6;
        return (Tokens.sizes.launcher.itemHeight + 8) * Math.min(maxShown, count) - 8;
    }

    Item {
        id: appGridHost

        visible: root.state === "apps"
        width: 550
        height: root.appsPaneHeight - 8
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 4
        clip: true

        GridView {
            id: appGrid

            anchors.fill: parent

            cellWidth: 110
            cellHeight: root.appsRowHeight
            cacheBuffer: root.appsRowHeight * 2
            reuseItems: true
            boundsBehavior: Flickable.DragAndOvershootBounds
            flickDeceleration: 2200
            maximumFlickVelocity: 3200

            model: root.state === "apps" ? appScriptModel : null
            delegate: gridAppItemComponent

            add: Transition {
                enabled: root.search.text.length > 0
                NumberAnimation {
                    properties: "opacity,scale"
                    from: 0.65
                    to: 1
                    duration: 160
                    easing.type: Easing.OutQuad
                }
            }

            remove: Transition {
                NumberAnimation {
                    properties: "opacity,scale"
                    from: 1
                    to: 0
                    duration: 150
                    easing.type: Easing.InQuad
                }
            }

            displaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: 220
                    easing.type: Easing.OutBack
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                onWheel: event => {
                    const delta = event.angleDelta.y;
                    if (!delta)
                        return;

                    root.scrollJellyActive = true;
                    root.lastContentY = appGrid.contentY;

                    const maxScroll = Math.max(0, appGrid.contentHeight - appGrid.height);
                    const isDiscrete = Math.abs(delta) >= 120;
                    const direction = delta > 0 ? -1 : 1;
                    const step = isDiscrete ? root.appsRowHeight : Math.max(18, Math.abs(delta) * 0.65);
                    const currentY = smoothScrollAnim.running ? smoothScrollAnim.to : appGrid.contentY;
                    const rawTarget = currentY + direction * step;
                    const targetY = Math.max(0, Math.min(maxScroll, rawTarget));

                    if (isDiscrete) {
                        smoothScrollAnim.stop();
                        smoothScrollAnim.from = appGrid.contentY;
                        smoothScrollAnim.to = targetY;
                        smoothScrollAnim.start();
                    } else {
                        smoothScrollAnim.stop();
                        appGrid.contentY = targetY;
                    }

                    event.accepted = true;
                }
            }
        }
    }

    Component {
        id: gridAppItemComponent
        GridAppItem {
            visibilities: root.visibilities
            gridView: appGrid
            revealEpoch: root.revealEpoch
            scrollVelocity: root.scrollVelocity
        }
    }

    StyledScrollBar {
        id: gridScrollBar
        flickable: appGrid
        anchors.right: appGridHost.right
        anchors.top: appGridHost.top
        anchors.bottom: appGridHost.bottom
        visible: appGridHost.visible && appGrid.contentHeight > appGrid.height
    }

    StyledListView {
        id: actionList

        visible: root.state !== "apps"
        anchors.fill: parent
        clip: true
        spacing: 8

        model: root.state !== "apps" ? actionScriptModel : null

        delegate: {
            if (root.state === "actions") return actionItem;
            if (root.state === "calc") return calcItem;
            if (root.state === "scheme") return schemeItem;
            if (root.state === "variant") return variantItem;
            return null;
        }

        highlightFollowsCurrentItem: false
        highlight: StyledRect {
            radius: Tokens.rounding.normal
            color: Colours.palette.m3onSurface
            opacity: 0.08

            y: actionList.currentItem?.y ?? 0
            implicitWidth: actionList.width
            implicitHeight: actionList.currentItem?.implicitHeight ?? 0
        }

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: actionList
            visible: actionList.visible && actionList.contentHeight > actionList.height
        }
    }

    Component {
        id: actionItem
        ActionItem { list: actionList }
    }

    Component {
        id: calcItem
        CalcItem { list: actionList }
    }

    Component {
        id: schemeItem
        SchemeItem { list: actionList }
    }

    Component {
        id: variantItem
        VariantItem { list: actionList }
    }
}