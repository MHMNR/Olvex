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
import qs.modules.settings.display

Item {
    id: root

    property Session session
    signal back

    // Local draft copies for non-destructive live editing
    property var draftMonitors: []
    property var draftWorkspaces: []
    property int selectedIndex: 0
    property string currentTab: "display" // "display", "workspaces", "profiles"
    property bool useDescription: DisplayManager.useDescription
    property bool hasUnsavedChanges: false
    property bool canvasExpanded: false

    // Identify overlay instance (lazy loaded on demand only)
    Loader {
        active: DisplayManager.identifyActive
        sourceComponent: IdentifyOverlay {}
    }

    // Initialize/sync drafts from DisplayManager
    function syncFromService() {
        let copy = DisplayManager.deepCopyMonitors();
        if (copy && copy.length === 1) {
            if (typeof copy[0].x !== "number" || isNaN(copy[0].x)) copy[0].x = 0;
            if (typeof copy[0].y !== "number" || isNaN(copy[0].y)) copy[0].y = 0;
            copy[0].isPrimary = true;
        } else if (copy && copy.length > 1) {
            let minX = Infinity, minY = Infinity;
            let primaryIndex = copy.findIndex(m => m.name === DisplayManager.primaryMonitorName);
            if (primaryIndex < 0) primaryIndex = copy.findIndex(m => m.isPrimary);
            if (primaryIndex < 0) primaryIndex = 0;

            for (let i = 0; i < copy.length; i++) {
                const mx = (typeof copy[i].x === "number") ? copy[i].x : 0;
                const my = (typeof copy[i].y === "number") ? copy[i].y : 0;
                if (mx < minX) minX = mx;
                if (my < minY) minY = my;
                copy[i].isPrimary = (i === primaryIndex);
            }
            if ((minX !== Infinity && minX < 0) || (minY !== Infinity && minY < 0)) {
                const shiftX = (minX !== Infinity && minX < 0) ? -minX : 0;
                const shiftY = (minY !== Infinity && minY < 0) ? -minY : 0;
                for (let i = 0; i < copy.length; i++) {
                    copy[i].x = Math.max(0, copy[i].x + shiftX);
                    copy[i].y = Math.max(0, copy[i].y + shiftY);
                }
            }
        }
        draftMonitors = copy;
        draftWorkspaces = DisplayManager.workspaces ? DisplayManager.workspaces.map(w => Object.assign({}, w)) : [];
        useDescription = DisplayManager.useDescription;
        if (selectedIndex >= draftMonitors.length) {
            selectedIndex = 0;
        }
        hasUnsavedChanges = false;
    }

    Component.onCompleted: {
        root.syncFromService();
    }

    Connections {
        target: DisplayManager
        function onMonitorsChanged() {
            if (!root.hasUnsavedChanges && !DisplayManager.safetyActive) {
                root.syncFromService();
            }
        }
        function onConfigurationSaved() {
            root.hasUnsavedChanges = false;
        }
        function onSafetyReverted() {
            root.syncFromService();
        }
        function onSafetyConfirmed() {
            root.syncFromService();
        }
    }

    // Auto align helper
    function autoAlign(alignment) {
        if (!draftMonitors || draftMonitors.length === 0) return;
        const copy = DisplayManager.deepCopyMonitors(draftMonitors);
        let curX = 0;
        let curY = 0;

        for (let i = 0; i < copy.length; i++) {
            if (alignment === "horizontal") {
                copy[i].x = curX;
                copy[i].y = 0;
                curX += copy[i].logicalWidth;
            } else if (alignment === "vertical") {
                copy[i].x = 0;
                copy[i].y = curY;
                curY += copy[i].logicalHeight;
            }
        }
        root.draftMonitors = copy;
        root.hasUnsavedChanges = true;
    }

    // Set selected monitor as primary (preserves exact positions, exactly 1 primary)
    function setPrimaryMonitor() {
        if (!draftMonitors || selectedIndex < 0 || selectedIndex >= draftMonitors.length) return;
        const copy = DisplayManager.deepCopyMonitors(draftMonitors);
        for (let i = 0; i < copy.length; i++) {
            copy[i].isPrimary = (i === selectedIndex);
        }
        if (copy[selectedIndex]) {
            DisplayManager.primaryMonitorName = copy[selectedIndex].name;
        }
        root.draftMonitors = copy;
        root.hasUnsavedChanges = true;
    }

    // Escape shortcut to exit canvas fullscreen
    Shortcut {
        enabled: displayCanvas.isFullscreen
        sequence: "Escape"
        onActivated: {
            displayCanvas.isFullscreen = false;
        }
    }

    ColumnLayout {
        id: pageLayout
        anchors.fill: parent
        anchors.margins: Tokens.padding ? Tokens.padding.normal : 12
        spacing: Tokens.spacing ? Tokens.spacing.normal : 12

        // ── 1. Top Section: Sub-Category Tabs (Segmented) ───────
        Item {
            visible: opacity > 0.01
            opacity: displayCanvas.isFullscreen ? 0 : 1
            Layout.fillWidth: true
            Layout.preferredHeight: displayCanvas.isFullscreen ? 0 : 44
            clip: true

            Behavior on opacity { Anim { type: Anim.FastEffects } }
            Behavior on Layout.preferredHeight { Anim { type: Anim.Emphasized } }

            RowLayout {
                anchors.fill: parent

                Segmented {
                    Layout.alignment: Qt.AlignLeft
                    model: [
                        { label: qsTr("Display Properties"), val: "display" },
                        { label: qsTr("Workspaces Binding"), val: "workspaces" },
                        { label: qsTr("Profiles & Presets"), val: "profiles" }
                    ]
                    currentIndex: {
                        if (root.currentTab === "workspaces") return 1;
                        if (root.currentTab === "profiles") return 2;
                        return 0;
                    }
                    onSelected: (idx) => {
                        if (idx === 0) root.currentTab = "display";
                        else if (idx === 1) root.currentTab = "workspaces";
                        else if (idx === 2) root.currentTab = "profiles";
                    }
                }

                Item { Layout.fillWidth: true }

                // Quick status text
                StyledText {
                    text: `${root.draftMonitors.length} ${qsTr("Display(s) Connected")}`
                    textPointSize: Tokens.font ? Tokens.font.size.smaller : 11
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // ── 2. Middle Section: Scrollable Content (Arrangement + Inspector) ─
        StyledFlickable {
            id: displayFlick

            Layout.fillWidth: true
            Layout.fillHeight: true
            interactive: !displayCanvas.isFullscreen
            clip: true
            contentWidth: width
            contentHeight: displayCanvas.isFullscreen ? height : (flickCol.implicitHeight + 40)

            Connections {
                target: root
                function onCurrentTabChanged() {
                    displayFlick.contentY = 0;
                }
            }

            Connections {
                target: displayCanvas
                function onIsFullscreenChanged() {
                    if (displayCanvas.isFullscreen)
                        displayFlick.contentY = 0;
                }
            }

            Column {
                id: flickCol

                width: displayFlick.width
                spacing: root.currentTab === "display" ? 3 : (Tokens.spacing ? Tokens.spacing.normal : 12)

                // Collapsible Display Arrangement Row Card (Display Properties tab only)
                StyledClippingRect {
                    id: canvasCard

                    readonly property int headerH: 64
                    readonly property int expandedCanvasH: Math.min(320, Math.max(220, root.height * 0.35))

                    visible: root.currentTab === "display" || displayCanvas.isFullscreen
                    width: parent.width
                    height: displayCanvas.isFullscreen
                        ? displayFlick.height
                        : (root.canvasExpanded ? (headerH + expandedCanvasH + 12) : headerH)
                    topLeftRadius: displayCanvas.isFullscreen ? 16 : 22
                    topRightRadius: displayCanvas.isFullscreen ? 16 : 22
                    bottomLeftRadius: displayCanvas.isFullscreen ? 16 : (root.currentTab === "display" ? 6 : 22)
                    bottomRightRadius: displayCanvas.isFullscreen ? 16 : (root.currentTab === "display" ? 6 : 22)
                    color: Colours.palette.m3surfaceContainerHigh
                    border.width: 0
                    border.color: "transparent"
                    clip: true

                    Behavior on height {
                        Anim {
                            type: Anim.Emphasized
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Clickable Row Header
                        Item {
                            id: canvasHeader

                            Layout.fillWidth: true
                            Layout.preferredHeight: displayCanvas.isFullscreen ? 0 : canvasCard.headerH
                            visible: opacity > 0.01
                            opacity: displayCanvas.isFullscreen ? 0 : 1
                            clip: true

                            Behavior on opacity { Anim { type: Anim.FastEffects } }
                            Behavior on Layout.preferredHeight { Anim { type: Anim.Emphasized } }

                            StateLayer {
                                anchors.fill: parent
                                radius: 22
                                color: Colours.palette.m3onSurface
                                onClicked: root.canvasExpanded = !root.canvasExpanded
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 16
                                spacing: 14

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("Display Arrangement")
                                        textPointSize: Tokens.font.size.normal
                                        font.weight: Font.Medium
                                        color: Colours.palette.m3onSurface
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: {
                                            const count = root.draftMonitors ? root.draftMonitors.length : 0;
                                            const action = root.canvasExpanded ? qsTr("Click to collapse layout") : qsTr("Click to arrange & preview displays");
                                            return count === 1
                                                ? qsTr("1 display · %1").arg(action)
                                                : qsTr("%1 displays · %2").arg(count).arg(action);
                                        }
                                        textPointSize: Tokens.font.size.small
                                        color: Colours.palette.m3onSurfaceVariant
                                        elide: Text.ElideRight
                                    }
                                }

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "expand_more"
                                    color: Colours.palette.m3onSurfaceVariant
                                    iconPointSize: 22
                                    rotation: root.canvasExpanded ? 180 : 0

                                    Behavior on rotation {
                                        Anim {
                                            type: Anim.FastSpatial
                                        }
                                    }
                                }
                            }
                        }

                        // Expandable Canvas Container
                        Item {
                            id: displayCanvasContainer

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.leftMargin: displayCanvas.isFullscreen ? 0 : 12
                            Layout.rightMargin: displayCanvas.isFullscreen ? 0 : 12
                            Layout.bottomMargin: displayCanvas.isFullscreen ? 0 : 12
                            visible: opacity > 0.01
                            opacity: (root.canvasExpanded || displayCanvas.isFullscreen) ? 1 : 0
                            clip: true

                            Behavior on opacity {
                                Anim {
                                    type: Anim.FastEffects
                                }
                            }

                            DisplayCanvas {
                                id: displayCanvas

                                anchors.fill: parent
                                monitors: root.draftMonitors
                                selectedIndex: root.selectedIndex
                                draftWorkspaces: root.draftWorkspaces

                                onSelectMonitor: (idx) => {
                                    root.selectedIndex = idx;
                                }

                                onMonitorsUpdated: (newMonitors) => {
                                    root.draftMonitors = newMonitors;
                                    root.hasUnsavedChanges = true;
                                }

                                onAutoAlignRequested: (align) => {
                                    root.autoAlign(align);
                                }
                            }
                        }
                    }
                }

                Item {
                    id: activeTabItem
                    visible: !displayCanvas.isFullscreen
                    width: parent.width
                    implicitHeight: {
                        if (root.currentTab === "display") return displayControls.implicitHeight;
                        if (root.currentTab === "workspaces") return workspacesTabLoader.item ? workspacesTabLoader.item.implicitHeight : 300;
                        return profilesTabLoader.item ? profilesTabLoader.item.implicitHeight : 300;
                    }

                // Tab 1: Display Properties Controls
                DisplayControls {
                    id: displayControls
                    visible: root.currentTab === "display"
                    width: parent.width
                    monitor: (root.draftMonitors && root.selectedIndex >= 0 && root.selectedIndex < root.draftMonitors.length)
                             ? root.draftMonitors[root.selectedIndex]
                             : null
                    allMonitors: root.draftMonitors
                    useDescription: root.useDescription

                    onMonitorUpdated: (updated) => {
                        const copy = DisplayManager.deepCopyMonitors(root.draftMonitors);
                        copy[root.selectedIndex] = updated;
                        root.draftMonitors = copy;
                        root.hasUnsavedChanges = true;
                    }

                    onUseDescriptionToggled: (val) => {
                        root.useDescription = val;
                        DisplayManager.useDescription = val;
                        root.hasUnsavedChanges = true;
                    }

                    onSetAsPrimaryRequested: {
                        root.setPrimaryMonitor();
                    }
                }

                // Tab 2: Workspaces Binding
                Loader {
                    id: workspacesTabLoader
                    active: root.currentTab === "workspaces"
                    visible: active
                    width: parent.width
                    sourceComponent: WorkspacesTab {
                        width: workspacesTabLoader.width
                        monitors: root.draftMonitors
                        workspaces: DisplayManager.workspaces
                        draftWorkspaces: root.draftWorkspaces

                        onWorkspaceBound: (wsNum, monName, isDef) => {
                            const copy = (root.draftWorkspaces || []).map(w => Object.assign({}, w));
                            const idx = copy.findIndex(w => w.workspace === wsNum);
                            if (idx >= 0) {
                                copy[idx].monitor = monName;
                                copy[idx].isDefault = isDef;
                            } else {
                                copy.push({ workspace: wsNum, monitor: monName, isDefault: isDef });
                            }
                            root.draftWorkspaces = copy;
                            root.hasUnsavedChanges = true;
                        }

                        onWorkspaceUnbound: (wsNum) => {
                            const copy = (root.draftWorkspaces || []).filter(w => w.workspace !== wsNum).map(w => Object.assign({}, w));
                            root.draftWorkspaces = copy;
                            root.hasUnsavedChanges = true;
                        }
                    }
                }

                // Tab 3: Profiles & Presets
                Loader {
                    id: profilesTabLoader
                    active: root.currentTab === "profiles"
                    visible: active
                    width: parent.width
                    sourceComponent: ProfilesTab {
                        width: profilesTabLoader.width
                        profiles: DisplayManager.profiles
                        activeProfileName: DisplayManager.activeProfileName

                        onSaveCurrentProfileRequested: (name) => {
                            DisplayManager.saveProfile(name, root.draftMonitors, root.draftWorkspaces, root.useDescription);
                            DisplayManager.loadProfiles();
                        }

                        onLoadProfileRequested: (pObj) => {
                            DisplayManager.applyProfile(pObj);
                            root.syncFromService();
                        }

                        onDeleteProfileRequested: (name) => {
                            DisplayManager.deleteProfile(name);
                            DisplayManager.loadProfiles();
                        }
                    }
                }
            }
            }
        }

        // ── 4. Sticky Bottom Action Bar (Apply & Test, Save, Revert)
        StyledRect {
            visible: opacity > 0.01
            opacity: displayCanvas.isFullscreen ? 0 : 1
            Layout.fillWidth: true
            Layout.preferredHeight: displayCanvas.isFullscreen ? 0 : 56
            implicitHeight: 56
            clip: true

            Behavior on opacity { Anim { type: Anim.FastEffects } }
            Behavior on Layout.preferredHeight { Anim { type: Anim.Emphasized } }
            radius: Tokens.rounding ? Tokens.rounding.large : 16
            color: Colours.palette.m3surfaceContainerHighest
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding ? Tokens.padding.large : 16
                anchors.rightMargin: Tokens.padding ? Tokens.padding.large : 16
                spacing: Tokens.spacing ? Tokens.spacing.normal : 12

                // Left: Sync status text
                StyledText {
                    text: root.hasUnsavedChanges ? qsTr("Unsaved display adjustments") : qsTr("Display configuration in sync")
                    textPointSize: Tokens.font ? Tokens.font.size.smaller : 11
                    font.weight: Font.Medium
                    color: root.hasUnsavedChanges ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                // Right: Actions
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8

                    // Revert Button
                    StyledRect {
                        implicitWidth: revertText.implicitWidth + (Tokens.padding ? Tokens.padding.large : 16) * 2
                        implicitHeight: 38
                        radius: Tokens.rounding ? Tokens.rounding.full : 999
                        color: Colours.palette.m3surfaceContainerHigh
                        opacity: root.hasUnsavedChanges ? 1 : 0.5
                        enabled: root.hasUnsavedChanges

                        StyledText {
                            id: revertText
                            anchors.centerIn: parent
                            text: qsTr("Revert")
                            font.weight: Font.Medium
                            textPointSize: Tokens.font ? Tokens.font.size.smaller : 11
                            color: Colours.palette.m3onSurface
                        }

                        StateLayer {
                            radius: parent.radius
                            onClicked: root.syncFromService()
                        }
                    }

                    // Apply & Test Button (With 10s countdown modal)
                    StyledRect {
                        implicitWidth: applyText.implicitWidth + (Tokens.padding ? Tokens.padding.large : 16) * 2
                        implicitHeight: 38
                        radius: Tokens.rounding ? Tokens.rounding.full : 999
                        color: Colours.palette.m3secondaryContainer

                        StyledText {
                            id: applyText
                            anchors.centerIn: parent
                            text: qsTr("Apply & Test")
                            font.weight: Font.Bold
                            textPointSize: Tokens.font ? Tokens.font.size.smaller : 11
                            color: Colours.palette.m3onSecondaryContainer
                        }

                        StateLayer {
                            radius: parent.radius
                            onClicked: {
                                DisplayManager.startSafetyApply(
                                    root.draftMonitors,
                                    root.draftWorkspaces,
                                    root.useDescription
                                );
                            }
                        }
                    }

                    // Save Permanently Button
                    StyledRect {
                        implicitWidth: saveText.implicitWidth + (Tokens.padding ? Tokens.padding.large : 16) * 2
                        implicitHeight: 38
                        radius: Tokens.rounding ? Tokens.rounding.full : 999
                        color: Colours.palette.m3primary

                        StyledText {
                            id: saveText
                            anchors.centerIn: parent
                            text: qsTr("Save")
                            font.weight: Font.Bold
                            textPointSize: Tokens.font ? Tokens.font.size.smaller : 11
                            color: Colours.palette.m3onPrimary
                        }

                        StateLayer {
                            radius: parent.radius
                            onClicked: {
                                DisplayManager.applyLive(root.draftMonitors, root.draftWorkspaces, root.useDescription);
                                DisplayManager.saveConfiguration(root.draftMonitors, root.draftWorkspaces, root.useDescription);
                                root.hasUnsavedChanges = false;
                            }
                        }
                    }
                }
            }
        }
                }

    // ── Safety Countdown Modal Dialog (Lazy loaded) ─────────────
    Loader {
        active: DisplayManager.safetyActive
        sourceComponent: SafetyModal {
            active: DisplayManager.safetyActive
            secondsRemaining: DisplayManager.safetySecondsRemaining
            onConfirmClicked: {
                DisplayManager.confirmSafetyApply();
                root.syncFromService();
            }
            onRevertClicked: {
                DisplayManager.revertSafetyApply();
                root.syncFromService();
            }
        }
    }
}
