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

    // Identify overlay instance
    IdentifyOverlay {
        id: idOverlay
    }

    // Initialize/sync drafts from DisplayManager
    function syncFromService() {
        draftMonitors = DisplayManager.deepCopyMonitors();
        draftWorkspaces = JSON.parse(JSON.stringify(DisplayManager.workspaces || []));
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
        const copy = JSON.parse(JSON.stringify(draftMonitors));
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

    // Set selected monitor as origin (0, 0) and shift others accordingly
    function setPrimaryOrigin() {
        if (!draftMonitors || selectedIndex < 0 || selectedIndex >= draftMonitors.length) return;
        const target = draftMonitors[selectedIndex];
        const offsetX = target.x;
        const offsetY = target.y;

        const copy = JSON.parse(JSON.stringify(draftMonitors));
        for (let i = 0; i < copy.length; i++) {
            copy[i].x = Math.max(0, copy[i].x - offsetX);
            copy[i].y = Math.max(0, copy[i].y - offsetY);
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
        anchors.fill: parent
        anchors.margins: Tokens.padding ? Tokens.padding.normal : 12
        spacing: Tokens.spacing ? Tokens.spacing.normal : 12

        // ── 1. Top Section: Visual Multi-Monitor Stage / Canvas ─
        DisplayCanvas {
            id: displayCanvas
            Layout.fillWidth: true
            Layout.preferredHeight: isFullscreen ? -1 : Math.min(320, Math.max(220, root.height * 0.35))
            Layout.fillHeight: isFullscreen
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

        // ── 2. Middle Section: Sub-Category Tabs (Segmented) ────
        Item {
            visible: !displayCanvas.isFullscreen
            Layout.fillWidth: true
            Layout.preferredHeight: 44

                        RowLayout {
                            anchors.fill: parent

                            Segmented {
                                Layout.alignment: Qt.AlignLeft
                                model: [
                                    { label: qsTr("Display Properties"), icon: "display_settings", val: "display" },
                                    { label: qsTr("Workspaces Binding"), icon: "grid_view", val: "workspaces" },
                                    { label: qsTr("Profiles & Presets"), icon: "bookmarks", val: "profiles" }
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

        // ── 3. Bottom Section: Scrollable Inspector Content ─────
        StyledFlickable {
            visible: !displayCanvas.isFullscreen
            Layout.fillWidth: true
            Layout.fillHeight: !displayCanvas.isFullscreen
            clip: true
            contentWidth: width
            contentHeight: activeTabItem.implicitHeight + 40
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: activeTabItem
                width: parent.width
                implicitHeight: {
                    if (root.currentTab === "display") return displayControls.implicitHeight;
                    if (root.currentTab === "workspaces") return workspacesTab.implicitHeight;
                    return profilesTab.implicitHeight;
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
                        const copy = JSON.parse(JSON.stringify(root.draftMonitors));
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
                        root.setPrimaryOrigin();
                    }
                }

                // Tab 2: Workspaces Binding
                WorkspacesTab {
                    id: workspacesTab
                    visible: root.currentTab === "workspaces"
                    width: parent.width
                    monitors: root.draftMonitors
                    workspaces: DisplayManager.workspaces
                    draftWorkspaces: root.draftWorkspaces

                    onWorkspaceBound: (wsNum, monName, isDef) => {
                        const copy = JSON.parse(JSON.stringify(root.draftWorkspaces || []));
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
                        const copy = (root.draftWorkspaces || []).filter(w => w.workspace !== wsNum);
                        root.draftWorkspaces = copy;
                        root.hasUnsavedChanges = true;
                    }
                }

                // Tab 3: Profiles & Presets
                ProfilesTab {
                    id: profilesTab
                    visible: root.currentTab === "profiles"
                    width: parent.width
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

        // ── 4. Sticky Bottom Action Bar (Apply & Test, Save, Revert)
        StyledRect {
            visible: !displayCanvas.isFullscreen
            Layout.fillWidth: true
            implicitHeight: 56
                        radius: Tokens.rounding ? Tokens.rounding.large : 16
                        color: Colours.palette.m3surfaceContainerHigh
                        border.width: 1
                        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding ? Tokens.padding.normal : 12
                            anchors.rightMargin: Tokens.padding ? Tokens.padding.normal : 12
                            spacing: Tokens.spacing ? Tokens.spacing.normal : 12

                            // Unsaved changes indicator
                            StyledRect {
                                visible: root.hasUnsavedChanges
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: Tokens.rounding ? Tokens.rounding.full : 999
                                color: Colours.palette.m3tertiary
                            }

                            StyledText {
                                text: root.hasUnsavedChanges ? qsTr("Unsaved display adjustments") : qsTr("Display configuration in sync")
                                textPointSize: Tokens.font ? Tokens.font.size.smaller : 11
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            Item { Layout.fillWidth: true }

                            // Revert Button
                            StyledRect {
                                implicitWidth: revertRow.implicitWidth + (Tokens.padding ? Tokens.padding.normal : 12) * 2
                                implicitHeight: 38
                                radius: Tokens.rounding ? Tokens.rounding.full : 999
                                color: Colours.palette.m3surfaceContainerHighest
                                opacity: root.hasUnsavedChanges ? 1 : 0.6
                                enabled: root.hasUnsavedChanges

                                RowLayout {
                                    id: revertRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    MaterialIcon {
                                        text: "undo"
                                        iconPointSize: Tokens.font ? Tokens.font.size.small : 12
                                        color: Colours.palette.m3onSurface
                                    }
                                    StyledText {
                                        text: qsTr("Revert")
                                        font.weight: Font.Medium
                                        textPointSize: Tokens.font ? Tokens.font.size.smaller : 11
                                        color: Colours.palette.m3onSurface
                                    }
                                }

                                StateLayer {
                                    radius: parent.radius
                                    onClicked: root.syncFromService()
                                }
                            }

                            // Apply & Test Button (With 10s countdown modal)
                            StyledRect {
                                implicitWidth: applyRow.implicitWidth + (Tokens.padding ? Tokens.padding.normal : 12) * 2
                                implicitHeight: 38
                                radius: Tokens.rounding ? Tokens.rounding.full : 999
                                color: Colours.palette.m3secondaryContainer

                                RowLayout {
                                    id: applyRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    MaterialIcon {
                                        text: "play_arrow"
                                        iconPointSize: Tokens.font ? Tokens.font.size.small : 12
                                        color: Colours.palette.m3onSecondaryContainer
                                    }
                                    StyledText {
                                        text: qsTr("Apply & Test")
                                        font.weight: Font.Bold
                                        textPointSize: Tokens.font ? Tokens.font.size.smaller : 11
                                        color: Colours.palette.m3onSecondaryContainer
                                    }
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
                                implicitWidth: saveRow.implicitWidth + (Tokens.padding ? Tokens.padding.normal : 12) * 2
                                implicitHeight: 38
                                radius: Tokens.rounding ? Tokens.rounding.full : 999
                                color: Colours.palette.m3primary

                                RowLayout {
                                    id: saveRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    MaterialIcon {
                                        text: "save"
                                        iconPointSize: Tokens.font ? Tokens.font.size.small : 12
                                        color: Colours.palette.m3onPrimary
                                    }
                                    StyledText {
                                        text: qsTr("Save")
                                        font.weight: Font.Bold
                                        textPointSize: Tokens.font ? Tokens.font.size.smaller : 11
                                        color: Colours.palette.m3onPrimary
                                    }
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

    // ── Safety Countdown Modal Dialog ───────────────────────────
    SafetyModal {
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
