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

    property Session session
    property var appJoin: null
    property var appSplit: null
    property var idxOf: null

    property var editingBind: null
    property bool isAddMode: false
    property bool showEditDialog: false

    property real originX: 0
    property real originY: 0
    property real originW: 140
    property real originH: 40
    property real originRadius: 20

    opacity: 0
    y: 10
    Component.onCompleted: {
        cascadeIn.start();
        Keybinds.reload();
    }
    Component.onDestruction: {
        Keybinds.stopKeyRecording();
    }

    Binding {
        target: root.session
        property: "modalActive"
        value: root.showEditDialog || modalLayer.morphAnimating
        when: !!root.session
    }

    Connections {
        target: root.session
        function onRequestCloseModal() {
            if (dialogComponent.isRecording) {
                dialogComponent.isRecording = false;
            } else if (root.showEditDialog && !collapseTransition.running) {
                modalLayer.closeModal();
            }
        }
    }

    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.normal || 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.normal || 300; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: Tokens.spacing.normal
        enabled: !root.showEditDialog

        // ── Top Header Controls ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            // Search Bar
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: Tokens.rounding.full
                color: searchInput.activeFocus 
                    ? Qt.alpha(Colours.palette.m3onSurface, 0.18)
                    : (searchHover.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.15) : Qt.alpha(Colours.palette.m3onSurface, 0.12))

                Behavior on color { CAnim {} }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.normal
                    anchors.rightMargin: Tokens.padding.normal
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "search"
                        color: Colours.palette.m3outline
                        iconPointSize: Tokens.font.size.normal
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: Colours.palette.m3onSurface
                        font.family: Tokens.font.family.sans
                        font.pointSize: Tokens.font.size.small
                        selectByMouse: true
                        selectionColor: Colours.palette.m3primary
                        selectedTextColor: Colours.palette.m3onPrimary
                        clip: true

                        onTextChanged: Keybinds.query = text

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Search shortcuts, commands, keys...")
                            color: Colours.palette.m3outline
                            font.family: Tokens.font.family.sans
                            textPointSize: Tokens.font.size.small
                            visible: !searchInput.text && !searchInput.activeFocus
                        }
                    }

                    IconButton {
                        icon: "close"
                        type: IconButton.Text
                        visible: searchInput.text.length > 0
                        onClicked: {
                            searchInput.text = "";
                            Keybinds.query = "";
                        }
                    }
                }

                HoverHandler { id: searchHover }
            }

            // Refresh live binds button
            IconButton {
                icon: "refresh"
                type: IconButton.Tonal
                onClicked: Keybinds.reload()
            }

            // Add Shortcut button
            ButtonBase {
                id: addBtn
                implicitHeight: 40
                implicitWidth: 140
                type: ButtonBase.Filled
                activeColour: Colours.palette.m3primary
                inactiveColour: Colours.palette.m3primary
                activeOnColour: Colours.palette.m3onPrimary
                inactiveOnColour: Colours.palette.m3onPrimary
                radius: Tokens.rounding.full
                opacity: (root.showEditDialog || modalLayer.morphAnimating) && root.isAddMode ? 0.0 : 1.0

                onClicked: {
                    const pt = addBtn.mapToItem(modalLayer, 0, 0);
                    root.originX = pt.x;
                    root.originY = pt.y;
                    root.originW = addBtn.width;
                    root.originH = addBtn.height;
                    root.originRadius = addBtn.height / 2;
                    root.isAddMode = true;
                    root.editingBind = null;
                    dialogComponent.initNew();
                    modalLayer.openModal();
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        text: "add"
                        color: Colours.palette.m3onPrimary
                        iconPointSize: Tokens.font.size.normal
                    }

                    StyledText {
                        text: qsTr("Add Bind")
                        color: Colours.palette.m3onPrimary
                        font.weight: Font.DemiBold
                        textPointSize: Tokens.font.size.small
                    }
                }
            }
        }

        // ── Category Filter Pills (Smooth Physics & Horizontal Scroll) ──
        ListView {
            id: catListView
            Layout.fillWidth: true
            implicitHeight: 36
            orientation: ListView.Horizontal
            spacing: Tokens.spacing.small
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 2500
            maximumFlickVelocity: 2500
            model: Keybinds.categories

            NumberAnimation {
                id: smoothScrollAnimX
                target: catListView
                property: "contentX"
                duration: 260
                easing.type: Easing.OutCubic
            }

            onMovementStarted: smoothScrollAnimX.stop()
            onFlickStarted: smoothScrollAnimX.stop()

            function clampScrollX(x) {
                const maxScroll = Math.max(0, catListView.contentWidth - catListView.width);
                return Math.max(0, Math.min(maxScroll, x));
            }

            function applyScrollDeltaX(deltaPx, animMs) {
                const base = smoothScrollAnimX.running ? smoothScrollAnimX.to : catListView.contentX;
                const targetX = clampScrollX(base + deltaPx);
                if (Math.abs(targetX - catListView.contentX) < 0.5 && !smoothScrollAnimX.running)
                    return;
                smoothScrollAnimX.stop();
                smoothScrollAnimX.duration = animMs || 260;
                smoothScrollAnimX.from = catListView.contentX;
                smoothScrollAnimX.to = targetX;
                smoothScrollAnimX.start();
            }

            function scrollToPill(pillX, pillWidth) {
                const targetCenter = pillX + pillWidth / 2 - catListView.width / 2;
                const targetX = clampScrollX(targetCenter);
                smoothScrollAnimX.stop();
                smoothScrollAnimX.duration = 320;
                smoothScrollAnimX.from = catListView.contentX;
                smoothScrollAnimX.to = targetX;
                smoothScrollAnimX.start();
            }

            delegate: StyledRect {
                id: catDelegate
                required property var modelData
                required property int index

                readonly property bool isSelected: Keybinds.selectedCategory === catDelegate.modelData.id
                implicitWidth: catContent.implicitWidth + 24
                height: 34
                radius: Tokens.rounding.full
                scale: catHover.containsPress ? 0.96 : (catHover.containsMouse ? 1.02 : 1.0)
                color: catDelegate.isSelected 
                    ? Colours.palette.m3primary 
                    : (catHover.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.16) : Qt.alpha(Colours.palette.m3onSurface, 0.08))

                Behavior on color { CAnim {} }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                RowLayout {
                    id: catContent
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        text: catDelegate.modelData.icon
                        color: catDelegate.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        iconPointSize: 14
                        Behavior on color { CAnim {} }
                    }

                    StyledText {
                        text: catDelegate.modelData.label
                        color: catDelegate.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        font.weight: catDelegate.isSelected ? Font.Medium : Font.Normal
                        textPointSize: Tokens.font.size.small
                        Behavior on color { CAnim {} }
                    }

                    StyledRect {
                        implicitWidth: countText.implicitWidth + 10
                        implicitHeight: 18
                        radius: Tokens.rounding.full
                        color: catDelegate.isSelected ? Qt.alpha(Colours.palette.m3onPrimary, 0.25) : Qt.alpha(Colours.palette.m3onSurface, 0.12)

                        StyledText {
                            id: countText
                            anchors.centerIn: parent
                            text: String(catDelegate.modelData.count)
                            color: catDelegate.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3outline
                            textPointSize: 10
                            font.weight: Font.Medium
                        }
                    }
                }

                MouseArea {
                    id: catHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Keybinds.selectedCategory = catDelegate.modelData.id;
                        catListView.scrollToPill(catDelegate.x, catDelegate.width);
                    }
                }
            }

            WheelHandler {
                id: catWheel
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const dev = event.device;
                    const isTouchPad = dev && dev.type === PointerDevice.TouchPad;

                    if (isTouchPad && (event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0)) {
                        const pDelta = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.pixelDelta.y;
                        catListView.applyScrollDeltaX(-pDelta, 140);
                        event.accepted = true;
                        return;
                    }

                    const angle = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
                    if (angle !== 0) {
                        const step = (angle / 120) * 120;
                        catListView.applyScrollDeltaX(-step, isTouchPad ? 140 : 260);
                        event.accepted = true;
                    }
                }
            }
        }

        // ── Virtualized Keybindings List (Smooth 144Hz Scrolling) ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty state
            StyledRect {
                anchors.centerIn: parent
                width: parent.width
                implicitHeight: 160
                radius: Tokens.rounding.normal
                color: Qt.alpha(Colours.palette.m3onSurface, 0.04)
                visible: Keybinds.filteredBinds.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "keyboard_off"
                        color: Colours.palette.m3outline
                        iconPointSize: 36
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Keybinds.loading ? qsTr("Loading keybindings...") : qsTr("No matching keybindings found")
                        color: Colours.palette.m3outline
                        font.weight: Font.Medium
                        textPointSize: Tokens.font.size.normal
                    }
                }
            }

            component KeybindMarqueeText: Item {
                id: marqueeRoot

                required property string text
                property color color: Colours.palette.m3outline
                property real textPointSize: Tokens.font.size.small
                property bool running: false

                implicitHeight: argLabel.implicitHeight
                clip: true

                readonly property real overflow: Math.max(0, argLabel.implicitWidth - width)
                readonly property bool needsMarquee: width > 0 && overflow > 2
                property real scroll: 0

                StyledText {
                    id: argLabel
                    text: marqueeRoot.text
                    color: marqueeRoot.color
                    textPointSize: marqueeRoot.textPointSize
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideNone
                    x: marqueeRoot.needsMarquee ? marqueeRoot.scroll : 0
                }

                SequentialAnimation {
                    id: marqueeAnim
                    loops: Animation.Infinite

                    PauseAnimation { duration: 800 }
                    NumberAnimation {
                        target: marqueeRoot
                        property: "scroll"
                        from: 0
                        to: -marqueeRoot.overflow
                        duration: Math.max(1200, marqueeRoot.overflow * 1000 / 40)
                        easing.type: Easing.InOutQuad
                    }
                    PauseAnimation { duration: 1200 }
                    NumberAnimation {
                        target: marqueeRoot
                        property: "scroll"
                        from: -marqueeRoot.overflow
                        to: 0
                        duration: Math.max(1200, marqueeRoot.overflow * 1000 / 40)
                        easing.type: Easing.InOutQuad
                    }
                }

                function restartMarquee() {
                    marqueeAnim.stop();
                    marqueeRoot.scroll = 0;
                    if (needsMarquee && running && visible && width > 0) {
                        marqueeAnim.start();
                    }
                }

                onTextChanged: Qt.callLater(restartMarquee)
                onWidthChanged: Qt.callLater(restartMarquee)
                onNeedsMarqueeChanged: Qt.callLater(restartMarquee)
                onRunningChanged: Qt.callLater(restartMarquee)
                Component.onCompleted: Qt.callLater(restartMarquee)
            }

            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                model: Keybinds.filteredBinds
                visible: Keybinds.filteredBinds.length > 0

                delegate: StyledRect {
                    id: bindCard
                    width: listView.width
                    implicitHeight: 64
                    radius: Tokens.rounding.large
                    color: itemHover.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : Qt.alpha(Colours.palette.m3onSurface, 0.04)

                    required property var modelData

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        spacing: Tokens.spacing.normal

                        // Category Icon
                        StyledRect {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3secondaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: bindCard.modelData.icon || "keyboard"
                                color: Colours.palette.m3onSecondaryContainer
                                iconPointSize: Tokens.font.size.normal
                            }
                        }

                        // Description & Command Info
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: bindCard.modelData.description || bindCard.modelData.dispatcher
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Medium
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: Tokens.spacing.extraSmall

                                StyledRect {
                                    implicitWidth: dispTag.implicitWidth + 8
                                    implicitHeight: 18
                                    radius: Tokens.rounding.full
                                    color: Qt.alpha(Colours.palette.m3primary, 0.14)

                                    StyledText {
                                        id: dispTag
                                        anchors.centerIn: parent
                                        text: bindCard.modelData.dispatcher
                                        color: Colours.palette.m3primary
                                        textPointSize: 10
                                        font.weight: Font.DemiBold
                                    }
                                }

                                KeybindMarqueeText {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: bindCard.modelData.arg || ""
                                    color: Colours.palette.m3outline
                                    textPointSize: Tokens.font.size.small
                                    visible: (bindCard.modelData.arg || "").length > 0
                                    running: itemHover.containsMouse
                                }
                            }
                        }

                        // Shortcut Key Badges Sequence
                        RowLayout {
                            spacing: 4

                            // Modifier Pills
                            Repeater {
                                model: bindCard.modelData.mods

                                delegate: StyledRect {
                                    required property string modelData
                                    implicitHeight: 28
                                    implicitWidth: modLabel.implicitWidth + 16
                                    radius: Tokens.rounding.full
                                    color: Colours.palette.m3secondaryContainer

                                    StyledText {
                                        id: modLabel
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        color: Colours.palette.m3onSecondaryContainer
                                        font.weight: Font.Bold
                                        textPointSize: 11
                                    }
                                }
                            }

                            // Plus sign if modifiers exist
                            StyledText {
                                text: "+"
                                color: Colours.palette.m3outline
                                font.weight: Font.Bold
                                textPointSize: 12
                                visible: bindCard.modelData.mods && bindCard.modelData.mods.length > 0
                            }

                            // Main Key Pill
                            StyledRect {
                                implicitHeight: 28
                                implicitWidth: Math.max(28, keyLabel.implicitWidth + 16)
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3primaryContainer

                                StyledText {
                                    id: keyLabel
                                    anchors.centerIn: parent
                                    text: bindCard.modelData.displayKey
                                    color: Colours.palette.m3onPrimaryContainer
                                    font.weight: Font.Bold
                                    textPointSize: 11
                                }
                            }
                        }

                        // Actions: Edit & Delete
                        RowLayout {
                            spacing: 2

                            IconButton {
                                icon: "edit"
                                type: IconButton.Text
                                onClicked: {
                                    const pt = mapToItem(modalLayer, 0, 0);
                                    root.originX = pt.x;
                                    root.originY = pt.y;
                                    root.originW = width;
                                    root.originH = height;
                                    root.originRadius = height / 2;
                                    root.isAddMode = false;
                                    root.editingBind = bindCard.modelData;
                                    dialogComponent.initFromBind(bindCard.modelData);
                                    modalLayer.openModal();
                                }
                            }

                            IconButton {
                                icon: "delete"
                                type: IconButton.Text
                                onClicked: Keybinds.deleteKeybind(bindCard.modelData)
                            }
                        }
                    }

                    MouseArea {
                        id: itemHover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }
    }

    // ── Interactive Key Recorder & Edit Modal (Olvex M3 Expressive Container Transform) ──
    Item {
        id: modalLayer
        parent: (root.session && root.session.rootItem) ? root.session.rootItem : root
        anchors.fill: parent
        visible: root.showEditDialog || morphAnimating
        enabled: root.showEditDialog || morphAnimating
        focus: root.showEditDialog
        z: 9999

        Keys.onEscapePressed: event => {
            if (dialogComponent.isRecording) {
                dialogComponent.isRecording = false;
                event.accepted = true;
            } else if (root.showEditDialog && !collapseTransition.running) {
                modalLayer.closeModal();
                event.accepted = true;
            }
        }

        readonly property bool morphAnimating: expandTransition.running || collapseTransition.running

        property real targetW: Math.min(560, Math.max(320, root.width - 32))
        property real targetH: dialogContent.implicitHeight + 48
        property real targetX: 0
        property real targetY: 0

        function updateTargetGeometry() {
            targetW = Math.min(560, Math.max(320, root.width - 32));
            targetH = dialogContent.implicitHeight + 48;
            const pt = root.mapToItem(modalLayer, (root.width - targetW) / 2, (root.height - targetH) / 2);
            targetX = pt.x;
            targetY = pt.y;
        }

        readonly property int expandDur: Tokens.anim.durations.expressiveDefaultSpatial || 400
        readonly property int collapseDur: Tokens.anim.durations.expressiveFastSpatial || 260

        function openModal() {
            if (root.showEditDialog) return;
            updateTargetGeometry();
            dialogBox.state = "docked";
            root.showEditDialog = true;
            modalLayer.forceActiveFocus();
            expandDeferred.start();
        }

        function closeModal() {
            if (!root.showEditDialog || collapseTransition.running) return;
            dialogComponent.isRecording = false;
            dialogBox.state = "docked";
            hideTimer.start();
        }

        Timer {
            id: expandDeferred
            interval: 16
            repeat: false
            onTriggered: {
                if (root.showEditDialog) {
                    modalLayer.updateTargetGeometry();
                    dialogBox.state = "expanded";
                    modalLayer.forceActiveFocus();
                }
            }
        }

        Timer {
            id: hideTimer
            interval: modalLayer.collapseDur
            repeat: false
            onTriggered: {
                root.showEditDialog = false;
            }
        }

        // Scrim Backdrop Dim with M3 Expressive Fade
        StyledRect {
            id: scrimRect
            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3scrim || "#000000", 0.60)
            opacity: 0.0

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                hoverEnabled: true
                onWheel: wheel => wheel.accepted = true
                onClicked: modalLayer.closeModal()
            }
        }

        // M3 Container Transform Morphing Container
        StyledRect {
            id: dialogBox
            x: root.originX
            y: root.originY
            width: root.originW
            height: root.originH
            radius: root.originRadius
            color: Colours.palette.m3surfaceContainerHigh
            border.width: 0
            clip: state !== "expanded" || expandTransition.running || collapseTransition.running

            state: "docked"

            states: [
                State {
                    name: "docked"
                    PropertyChanges {
                        target: dialogBox
                        x: root.originX
                        y: root.originY
                        width: root.originW
                        height: root.originH
                        radius: root.originRadius
                    }
                    PropertyChanges { target: scrimRect; opacity: 0.0 }
                    PropertyChanges { target: startSurfaceTint; opacity: root.isAddMode ? 1.0 : 0.0 }
                    PropertyChanges { target: buttonPlaceholder; opacity: root.isAddMode ? 1.0 : 0.0 }
                    PropertyChanges { target: dialogContentContainer; opacity: 0.0 }
                    PropertyChanges { target: closeBtn; opacity: 0.0 }
                },
                State {
                    name: "expanded"
                    PropertyChanges {
                        target: dialogBox
                        x: modalLayer.targetX
                        y: modalLayer.targetY
                        width: modalLayer.targetW
                        height: modalLayer.targetH
                        radius: 28
                    }
                    PropertyChanges { target: scrimRect; opacity: 1.0 }
                    PropertyChanges { target: startSurfaceTint; opacity: 0.0 }
                    PropertyChanges { target: buttonPlaceholder; opacity: 0.0 }
                    PropertyChanges { target: dialogContentContainer; opacity: 1.0 }
                    PropertyChanges { target: closeBtn; opacity: 1.0 }
                }
            ]

            transitions: [
                Transition {
                    id: expandTransition
                    from: "docked"
                    to: "expanded"
                    ParallelAnimation {
                        NumberAnimation {
                            target: dialogBox
                            properties: "x,y,width,height"
                            duration: modalLayer.expandDur
                            easing: Tokens.anim.expressiveDefaultSpatial
                        }
                        NumberAnimation {
                            target: dialogBox
                            property: "radius"
                            duration: Math.round(modalLayer.expandDur * 0.75)
                            easing: Tokens.anim.expressiveDefaultSpatial
                        }
                        NumberAnimation {
                            target: scrimRect
                            property: "opacity"
                            duration: modalLayer.expandDur
                            easing: Tokens.anim.expressiveDefaultEffects
                        }
                        // Phase 1: Button text/icon fades out immediately (0 -> 70ms)
                        NumberAnimation {
                            target: buttonPlaceholder
                            property: "opacity"
                            duration: 70
                            easing.type: Easing.InQuad
                        }
                        // Phase 2: Start surface tint fades out smoothly as container grows (0 -> 130ms)
                        NumberAnimation {
                            target: startSurfaceTint
                            property: "opacity"
                            duration: 130
                            easing.type: Easing.OutQuad
                        }
                        // Phase 3: Dialog form content emerges cleanly on the pure surface (120ms -> 400ms)
                        SequentialAnimation {
                            PauseAnimation { duration: 120 }
                            NumberAnimation {
                                target: dialogContentContainer
                                property: "opacity"
                                duration: modalLayer.expandDur - 120
                                easing: Tokens.anim.expressiveDefaultEffects
                            }
                        }
                        SequentialAnimation {
                            PauseAnimation { duration: 150 }
                            NumberAnimation {
                                target: closeBtn
                                property: "opacity"
                                duration: modalLayer.expandDur - 150
                                easing: Tokens.anim.expressiveDefaultEffects
                            }
                        }
                    }
                },
                Transition {
                    id: collapseTransition
                    from: "expanded"
                    to: "docked"
                    ParallelAnimation {
                        NumberAnimation {
                            target: dialogBox
                            properties: "x,y,width,height,radius"
                            duration: modalLayer.collapseDur
                            easing: Tokens.anim.emphasized
                        }
                        NumberAnimation {
                            target: scrimRect
                            property: "opacity"
                            duration: modalLayer.collapseDur
                            easing: Tokens.anim.expressiveFastEffects
                        }
                        // Phase 1: Smoothly fade out dialog content immediately (0 -> 60ms)
                        NumberAnimation {
                            target: dialogContentContainer
                            property: "opacity"
                            duration: 60
                            easing.type: Easing.InQuad
                        }
                        NumberAnimation {
                            target: closeBtn
                            property: "opacity"
                            duration: 50
                            easing.type: Easing.InQuad
                        }
                        // Phase 2: Smooth surface color crossfade back to button color (50ms -> 240ms)
                        SequentialAnimation {
                            PauseAnimation { duration: 50 }
                            NumberAnimation {
                                target: startSurfaceTint
                                property: "opacity"
                                duration: modalLayer.collapseDur - 50
                                easing.type: Easing.OutCubic
                            }
                        }
                        // Phase 3: Fade in button icon & label as container docks (140ms -> 260ms)
                        SequentialAnimation {
                            PauseAnimation { duration: 140 }
                            NumberAnimation {
                                target: buttonPlaceholder
                                property: "opacity"
                                duration: modalLayer.collapseDur - 140
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                }
            ]

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                hoverEnabled: true
                onWheel: wheel => wheel.accepted = true
            }

            // Start Surface Tint (m3primary) for perfect color crossfade without muddy RGB interpolation
            StyledRect {
                id: startSurfaceTint
                anchors.fill: parent
                radius: parent.radius
                color: root.isAddMode ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh
                opacity: 0.0
                z: 0
            }

            // Collapsed Button Placeholder (Visible during collapse / early expand)
            RowLayout {
                id: buttonPlaceholder
                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall
                visible: root.isAddMode && opacity > 0.001
                opacity: 0.0
                z: 1

                MaterialIcon {
                    text: "add"
                    color: Colours.palette.m3onPrimary
                    iconPointSize: Tokens.font.size.normal
                }

                StyledText {
                    text: qsTr("Add Bind")
                    color: Colours.palette.m3onPrimary
                    font.weight: Font.DemiBold
                    textPointSize: Tokens.font.size.small
                }
            }

            // Top-Right Close Button
            IconButton {
                id: closeBtn
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 18
                z: 10
                icon: "close"
                type: IconButton.Text
                visible: opacity > 0.001
                opacity: 0.0

                onClicked: modalLayer.closeModal()
            }

            // Decoupled Form Container (Prevents child layout thrashing / text reflow during shrinking)
            Item {
                id: dialogContentContainer
                anchors.fill: parent
                anchors.margins: 24
                opacity: 0.0
                z: 2

                ColumnLayout {
                    id: dialogContent
                    anchors.fill: parent
                    spacing: Tokens.spacing.large

                // ── Dialog Clean Header (No Unnecessary Icon Badges) ──
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.rightMargin: 40
                    spacing: 2

                    StyledText {
                        text: root.isAddMode ? qsTr("Add New Keybinding") : qsTr("Edit Keybinding")
                        color: Colours.palette.m3onSurface
                        font.weight: Font.DemiBold
                        textPointSize: Tokens.font.size.large
                    }

                    StyledText {
                        text: root.isAddMode 
                            ? qsTr("Configure custom keyboard shortcut and system action")
                            : qsTr("Modify shortcut triggers, action dispatcher or arguments")
                        color: Colours.palette.m3onSurfaceVariant
                        textPointSize: Tokens.font.size.small
                    }
                }

                // ── Shortcut Keys Section (Olvex Sliding Segmented Control) ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    // Header with Olvex Segmented Slider Control
                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: qsTr("Shortcut Keys")
                            color: Colours.palette.m3onSurface
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.small
                            Layout.fillWidth: true
                        }

                        Segmented {
                            model: [
                                { label: qsTr("Record") },
                                { label: qsTr("Type Manually") }
                            ]
                            currentIndex: dialogComponent.inputMode === "record" ? 0 : 1
                            onSelected: index => {
                                dialogComponent.inputMode = (index === 0 ? "record" : "manual");
                                if (index !== 0) dialogComponent.isRecording = false;
                            }
                        }
                    }

                    // ── Mode 1: Interactive Key Recorder Box ──
                    StyledRect {
                        id: keyRecorderBox
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: Tokens.rounding.large
                        visible: dialogComponent.inputMode === "record"
                        opacity: dialogComponent.inputMode === "record" ? 1.0 : 0.0
                        color: dialogComponent.isRecording 
                            ? Qt.alpha(Colours.palette.m3primary, 0.18) 
                            : (recHover.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.12) : Qt.alpha(Colours.palette.m3onSurface, 0.08))
                        border.width: dialogComponent.isRecording ? 1.5 : 0
                        border.color: Colours.palette.m3primary
                        focus: dialogComponent.isRecording

                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on color { CAnim {} }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                visible: dialogComponent.isRecording
                                text: "fiber_manual_record"
                                color: Colours.palette.m3primary
                                iconPointSize: 16

                                SequentialAnimation on opacity {
                                    running: dialogComponent.isRecording
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 550; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 1.0; duration: 550; easing.type: Easing.InOutQuad }
                                }
                            }

                            StyledText {
                                text: dialogComponent.isRecording 
                                    ? qsTr("Listening for key combination... (Esc to cancel)") 
                                    : (dialogComponent.recordedShortcut || qsTr("Click to record shortcut"))
                                color: dialogComponent.isRecording ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                font.weight: Font.Bold
                                textPointSize: Tokens.font.size.normal
                            }
                        }

                        MouseArea {
                            id: recHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                dialogComponent.isRecording = true;
                                keyRecorderBox.forceActiveFocus();
                            }
                        }

                        Keys.onEscapePressed: event => {
                            dialogComponent.isRecording = false;
                            event.accepted = true;
                        }

                        Keys.onPressed: event => {
                            if (!dialogComponent.isRecording) return;

                            if (event.key === Qt.Key_Escape) {
                                dialogComponent.isRecording = false;
                                event.accepted = true;
                                return;
                            }

                            // Capture modifiers
                            const mods = [];
                            if (event.modifiers & Qt.MetaModifier) mods.push("SUPER");
                            if (event.modifiers & Qt.ControlModifier) mods.push("CTRL");
                            if (event.modifiers & Qt.AltModifier) mods.push("ALT");
                            if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT");

                            // Ignore standalone modifier presses until a key is hit
                            const keyName = dialogComponent.keyToString(event.key);
                            if (!keyName || ["SUPER", "CTRL", "ALT", "SHIFT"].includes(keyName)) {
                                event.accepted = true;
                                return;
                            }

                            dialogComponent.selectedMods = mods;
                            dialogComponent.selectedKey = keyName;
                            dialogComponent.syncShortcutDisplay();
                            dialogComponent.isRecording = false;
                            event.accepted = true;
                        }
                    }

                    // ── Mode 2: Manual Modifier Selection & Key Input ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small
                        visible: dialogComponent.inputMode === "manual"
                        opacity: dialogComponent.inputMode === "manual" ? 1.0 : 0.0

                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        // M3 Specification Filter Chips (32dp, 8dp radius, secondary-container selected)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: ["SUPER", "CTRL", "ALT", "SHIFT"]

                                delegate: StyledRect {
                                    id: modToggle
                                    required property string modelData
                                    readonly property bool isChecked: dialogComponent.selectedMods.includes(modToggle.modelData)

                                    implicitHeight: 32
                                    implicitWidth: modRow.implicitWidth + (modToggle.isChecked ? 24 : 20)
                                    radius: 8
                                    color: modToggle.isChecked 
                                        ? Colours.palette.m3secondaryContainer 
                                        : (chipHover.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : "transparent")
                                    border.width: modToggle.isChecked ? 0 : 1
                                    border.color: modToggle.isChecked ? "transparent" : Qt.alpha(Colours.palette.m3outline, 0.40)
                                    scale: chipHover.containsPress ? 0.96 : (chipHover.containsMouse ? 1.02 : 1.0)

                                    Behavior on color { CAnim {} }
                                    Behavior on border.color { CAnim {} }
                                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                    RowLayout {
                                        id: modRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        MaterialIcon {
                                            visible: modToggle.isChecked
                                            text: "check"
                                            color: Colours.palette.m3onSecondaryContainer
                                            iconPointSize: 16
                                        }

                                        StyledText {
                                            id: modToggleText
                                            text: modToggle.modelData
                                            color: modToggle.isChecked ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                            font.weight: modToggle.isChecked ? Font.DemiBold : Font.Medium
                                            textPointSize: Tokens.font.size.small
                                            Behavior on color { CAnim {} }
                                        }
                                    }

                                    MouseArea {
                                        id: chipHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: dialogComponent.toggleMod(modToggle.modelData)
                                    }
                                }
                            }
                        }

                        // Clean Manual Key Input Field (No Redundant Icons)
                        StyledRect {
                            id: manualKeyBox
                            Layout.fillWidth: true
                            implicitHeight: 48
                            radius: 12
                            color: manualKeyInput.activeFocus 
                                ? Qt.alpha(Colours.palette.m3onSurface, 0.14)
                                : (manualKeyHover.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.10) : Qt.alpha(Colours.palette.m3onSurface, 0.07))
                            border.width: 0

                            Behavior on color { CAnim {} }

                            TextInput {
                                id: manualKeyInput
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.large
                                anchors.rightMargin: Tokens.padding.large
                                verticalAlignment: TextInput.AlignVCenter
                                color: Colours.palette.m3onSurface
                                font.family: Tokens.font.family.sans
                                font.pointSize: Tokens.font.size.small
                                text: dialogComponent.selectedKey
                                onTextChanged: {
                                    dialogComponent.selectedKey = text.trim();
                                    dialogComponent.syncShortcutDisplay();
                                }

                                StyledText {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Type key name (e.g. Return, Space, Q, 1, F1, comma)...")
                                    color: Colours.palette.m3outline
                                    textPointSize: Tokens.font.size.small
                                    visible: !manualKeyInput.text && !manualKeyInput.activeFocus
                                }
                            }

                            HoverHandler { id: manualKeyHover }
                        }
                    }

                    // Live Shortcut Preview Badge Sequence (M3 Badge Specification)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: dialogComponent.selectedKey.length > 0 || dialogComponent.selectedMods.length > 0

                        StyledText {
                            text: qsTr("Shortcut Preview:")
                            color: Colours.palette.m3onSurfaceVariant
                            font.weight: Font.Medium
                            textPointSize: Tokens.font.size.small
                            Layout.rightMargin: 2
                        }

                        Repeater {
                            model: dialogComponent.selectedMods

                            delegate: StyledRect {
                                required property string modelData
                                implicitHeight: 32
                                implicitWidth: modPrevText.implicitWidth + 24
                                radius: 8
                                color: Colours.palette.m3secondaryContainer
                                border.width: 0

                                StyledText {
                                    id: modPrevText
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    color: Colours.palette.m3onSecondaryContainer
                                    font.weight: Font.DemiBold
                                    textPointSize: Tokens.font.size.small
                                }
                            }
                        }

                        StyledText {
                            text: "+"
                            color: Colours.palette.m3onSurfaceVariant
                            font.weight: Font.Bold
                            textPointSize: Tokens.font.size.normal
                            visible: dialogComponent.selectedMods.length > 0 && dialogComponent.selectedKey.length > 0
                        }

                        StyledRect {
                            implicitHeight: 32
                            implicitWidth: Math.max(32, keyPrevText.implicitWidth + 24)
                            radius: 8
                            color: Colours.palette.m3primaryContainer
                            visible: dialogComponent.selectedKey.length > 0
                            border.width: 0

                            StyledText {
                                id: keyPrevText
                                anchors.centerIn: parent
                                text: dialogComponent.selectedKey
                                color: Colours.palette.m3onPrimaryContainer
                                font.weight: Font.Bold
                                textPointSize: Tokens.font.size.small
                            }
                        }
                    }
                }

                // ── Dispatcher Type Field (Clean Input, No Unnecessary Icons) ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: qsTr("Dispatcher (Action Type)")
                        color: Colours.palette.m3onSurface
                        font.weight: Font.DemiBold
                        textPointSize: Tokens.font.size.small
                    }

                    StyledRect {
                        id: dispBox
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: Tokens.rounding.large
                        color: dispInput.activeFocus 
                            ? Qt.alpha(Colours.palette.m3onSurface, 0.14)
                            : (dispHover.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.10) : Qt.alpha(Colours.palette.m3onSurface, 0.07))
                        border.width: 0

                        Behavior on color { CAnim {} }

                        TextInput {
                            id: dispInput
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.large
                            anchors.rightMargin: Tokens.padding.large
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colours.palette.m3onSurface
                            font.family: Tokens.font.family.sans
                            font.pointSize: Tokens.font.size.small
                            text: dialogComponent.selectedDispatcher
                            onTextChanged: dialogComponent.selectedDispatcher = text

                            StyledText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "exec, global, workspace, killactive, togglefloating..."
                                color: Colours.palette.m3outline
                                textPointSize: Tokens.font.size.small
                                visible: !dispInput.text && !dispInput.activeFocus
                            }
                        }

                        HoverHandler { id: dispHover }
                    }
                }

                // ── Command / Argument Field (Clean Input, No Unnecessary Icons) ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: qsTr("Argument / Command")
                        color: Colours.palette.m3onSurface
                        font.weight: Font.DemiBold
                        textPointSize: Tokens.font.size.small
                    }

                    StyledRect {
                        id: argBox
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: Tokens.rounding.large
                        color: argInput.activeFocus 
                            ? Qt.alpha(Colours.palette.m3onSurface, 0.14)
                            : (argHover.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.10) : Qt.alpha(Colours.palette.m3onSurface, 0.07))
                        border.width: 0

                        Behavior on color { CAnim {} }

                        TextInput {
                            id: argInput
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.large
                            anchors.rightMargin: Tokens.padding.large
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colours.palette.m3onSurface
                            font.family: Tokens.font.family.sans
                            font.pointSize: Tokens.font.size.small
                            text: dialogComponent.selectedArg
                            onTextChanged: dialogComponent.selectedArg = text

                            StyledText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "e.g. kitty, olvex:session, 1..."
                                color: Colours.palette.m3outline
                                textPointSize: Tokens.font.size.small
                                visible: !argInput.text && !argInput.activeFocus
                            }
                        }

                        HoverHandler { id: argHover }
                    }
                }

                // ── Conflict Warning Banner (M3 Error Container) ──
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: conflictCol.implicitHeight + 16
                    radius: Tokens.rounding.large
                    color: Qt.alpha(Colours.palette.m3error || "#ba1a1a", 0.14)
                    border.width: 0
                    visible: dialogComponent.conflictWarning.length > 0

                    RowLayout {
                        id: conflictCol
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        anchors.topMargin: Tokens.padding.small
                        anchors.bottomMargin: Tokens.padding.small
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            Layout.alignment: Qt.AlignVCenter
                            text: "warning"
                            color: Colours.palette.m3error || "#ba1a1a"
                            iconPointSize: Tokens.font.size.large
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 2

                            StyledText {
                                text: qsTr("Shortcut Already In Use")
                                color: Colours.palette.m3error || "#ba1a1a"
                                font.weight: Font.Bold
                                textPointSize: Tokens.font.size.small
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: dialogComponent.conflictWarning
                                color: Colours.palette.m3onSurface
                                textPointSize: Tokens.font.size.smaller
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }

                // ── Action Buttons (Cancel & Save) ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.normal

                    Item { Layout.fillWidth: true }

                    ButtonBase {
                        id: cancelBtn
                        implicitHeight: 44
                        implicitWidth: 110
                        type: ButtonBase.Tonal
                        radius: Tokens.rounding.full
                        inactiveColour: Qt.alpha(Colours.palette.m3onSurface, 0.08)
                        activeColour: Qt.alpha(Colours.palette.m3onSurface, 0.16)
                        inactiveOnColour: Colours.palette.m3onSurface
                        activeOnColour: Colours.palette.m3onSurface
                        border.width: 0
                        scale: cancelMouse.containsPress ? 0.96 : (cancelMouse.containsMouse ? 1.02 : 1.0)

                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                        onClicked: modalLayer.closeModal()

                        StyledText {
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            color: Colours.palette.m3onSurface
                            font.weight: Font.Medium
                            textPointSize: Tokens.font.size.small
                        }

                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cancelBtn.clicked()
                        }
                    }

                    ButtonBase {
                        id: saveBtn
                        readonly property bool hasConflict: dialogComponent.conflictWarning.length > 0
                        readonly property bool canSave: dialogComponent.selectedKey.length > 0 && dialogComponent.selectedDispatcher.length > 0 && !hasConflict
                        implicitHeight: 44
                        implicitWidth: hasConflict ? 160 : 140
                        type: ButtonBase.Filled
                        radius: Tokens.rounding.full
                        inactiveColour: hasConflict ? Qt.alpha(Colours.palette.m3error || "#ba1a1a", 0.25) : Colours.palette.m3primary
                        activeColour: hasConflict ? Qt.alpha(Colours.palette.m3error || "#ba1a1a", 0.35) : Qt.darker(Colours.palette.m3primary, 1.1)
                        inactiveOnColour: Colours.palette.m3onPrimary
                        activeOnColour: Colours.palette.m3onPrimary
                        opacity: canSave ? 1.0 : 0.4
                        border.width: 0
                        scale: (canSave && saveMouse.containsPress) ? 0.96 : ((canSave && saveMouse.containsMouse) ? 1.02 : 1.0)

                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                        onClicked: {
                            if (!saveBtn.canSave) return;
                            Keybinds.saveKeybind(
                                root.editingBind,
                                dialogComponent.selectedMods,
                                dialogComponent.selectedKey,
                                dialogComponent.selectedDispatcher,
                                dialogComponent.selectedArg,
                                dialogComponent.selectedFlag
                            );
                            modalLayer.closeModal();
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: saveBtn.hasConflict ? qsTr("Conflict Blocked") : qsTr("Save Bind")
                            color: saveBtn.canSave ? Colours.palette.m3onPrimary : (saveBtn.hasConflict ? (Colours.palette.m3error || "#ba1a1a") : Qt.alpha(Colours.palette.m3onSurface, 0.38))
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.small
                            Behavior on color { CAnim {} }
                        }

                        MouseArea {
                            id: saveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: saveBtn.canSave ? Qt.PointingHandCursor : (saveBtn.hasConflict ? Qt.ForbiddenCursor : Qt.ArrowCursor)
                            onClicked: saveBtn.clicked()
                        }
                    }
                }
            }
            }
        }
    }

    // Helper Object for Dialog state
    QtObject {
        id: dialogComponent

        property bool isRecording: false
        onIsRecordingChanged: {
            if (isRecording) {
                Keybinds.startKeyRecording();
            } else {
                Keybinds.stopKeyRecording();
            }
        }
        property string inputMode: "record" // "record" | "manual"
        property var selectedMods: []
        property string selectedKey: ""
        property string recordedShortcut: ""
        property string selectedDispatcher: "exec"
        property string selectedArg: ""
        property string selectedFlag: "bind"

        function toggleMod(mod) {
            const list = (selectedMods || []).slice();
            const idx = list.indexOf(mod);
            if (idx >= 0) {
                list.splice(idx, 1);
            } else {
                list.push(mod);
            }
            selectedMods = list;
            syncShortcutDisplay();
        }

        function syncShortcutDisplay() {
            const modStr = (selectedMods || []).join(" + ");
            if (modStr.length > 0 && selectedKey.length > 0) {
                recordedShortcut = `${modStr} + ${selectedKey}`;
            } else if (modStr.length > 0) {
                recordedShortcut = modStr;
            } else {
                recordedShortcut = selectedKey;
            }
        }

        readonly property string conflictWarning: {
            if (!selectedKey || selectedKey.trim().length === 0) return "";
            
            const currentMods = (selectedMods || []).map(m => m.toUpperCase().trim()).sort();
            const currentModStr = currentMods.join("+");
            const currentKeyLow = selectedKey.trim().toLowerCase();

            for (let i = 0; i < Keybinds.binds.length; i++) {
                const b = Keybinds.binds[i];
                if (root.editingBind && b.id === root.editingBind.id) continue;
                
                const bMods = (b.mods || []).map(m => m.toUpperCase().trim()).sort();
                const bModStr = bMods.join("+");
                
                const bKeyLow = (b.key || "").trim().toLowerCase();
                const bDisplayKeyLow = (b.displayKey || "").trim().toLowerCase();
                
                const modMatch = (bModStr === currentModStr);
                const keyMatch = (bKeyLow === currentKeyLow || bDisplayKeyLow === currentKeyLow);
                
                if (modMatch && keyMatch) {
                    const bindName = b.description || b.dispatcher || (b.mods.join("+") + " + " + b.displayKey);
                    return qsTr("Already bound to \"%1\" (%2 %3)").arg(bindName).arg(b.dispatcher).arg(b.arg || "");
                }
            }
            return "";
        }

        function initNew() {
            inputMode = "record";
            selectedMods = ["SUPER"];
            selectedKey = "";
            recordedShortcut = "";
            selectedDispatcher = "exec";
            selectedArg = "";
            selectedFlag = "bind";
            isRecording = false;
        }

        function initFromBind(bind) {
            if (!bind) return initNew();
            inputMode = "record";
            selectedMods = (bind.mods || []).slice();
            selectedKey = bind.key || "";
            recordedShortcut = bind.shortcutDisplay || "";
            selectedDispatcher = bind.dispatcher || "exec";
            selectedArg = bind.arg || "";
            selectedFlag = bind.flag || "bind";
            isRecording = false;
        }

        function keyToString(key) {
            if (key >= Qt.Key_A && key <= Qt.Key_Z) {
                return String.fromCharCode(key);
            }
            if (key >= Qt.Key_0 && key <= Qt.Key_9) {
                return String.fromCharCode(key);
            }
            if (key >= Qt.Key_F1 && key <= Qt.Key_F12) {
                return "F" + (key - Qt.Key_F1 + 1);
            }

            switch(key) {
                case Qt.Key_Return: case Qt.Key_Enter: return "Return";
                case Qt.Key_Space: return "Space";
                case Qt.Key_Tab: return "Tab";
                case Qt.Key_Backspace: return "BackSpace";
                case Qt.Key_Delete: return "Delete";
                case Qt.Key_Insert: return "Insert";
                case Qt.Key_Home: return "Home";
                case Qt.Key_End: return "End";
                case Qt.Key_PageUp: return "Page_Up";
                case Qt.Key_PageDown: return "Page_Down";
                case Qt.Key_Left: return "Left";
                case Qt.Key_Right: return "Right";
                case Qt.Key_Up: return "Up";
                case Qt.Key_Down: return "Down";
                case Qt.Key_QuoteLeft: return "grave";
                case Qt.Key_Minus: return "minus";
                case Qt.Key_Equal: return "equal";
                case Qt.Key_BracketLeft: return "bracketleft";
                case Qt.Key_BracketRight: return "bracketright";
                case Qt.Key_Backslash: return "backslash";
                case Qt.Key_Semicolon: return "semicolon";
                case Qt.Key_Apostrophe: return "apostrophe";
                case Qt.Key_Comma: return "comma";
                case Qt.Key_Period: return "period";
                case Qt.Key_Slash: return "slash";
                default: return "";
            }
        }
    }
}
