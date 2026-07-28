pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Olvex.Config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services

Item {
    id: root

    required property DrawerVisibilities visibilities

    // ── State ────────────────────────────────────────────────────────────────
    property list<var> history: []
    property int maxHistory: 99999
    property bool listening: true
    property bool useCliphist: true
    // Probe result: updated on startup to reflect whether cliphist binary exists
    property bool cliphistAvailable: false

    readonly property bool visible_: visibilities.clipboard ?? false

    // ── Clipboard polling via wl-paste --watch ───────────────────────────────
    // If cliphist is available (via Olvex/services/Cliphist.qml) prefer it.
    Process {
        id: watchProc
        command: ["wl-paste", "--watch", "cat"]
        running: root.listening && !root.useCliphist
        stdout: SplitParser {
            onRead: line => {
                if (!line.trim()) return;
                // Deduplicate: remove existing identical entry
                const idx = root.history.findIndex(e => e.text === line);
                if (idx !== -1) root.history.splice(idx, 1);
                root.history.unshift({ text: line, time: Date.now() });
                historyChanged();
            }
        }
    }

    // Probe for cliphist on startup
    Process {
        id: cliphistProbe
        command: ["bash", "-c", "command -v cliphist >/dev/null"]
        running: false
        function onExited(exitCode, exitStatus) {
            root.cliphistAvailable = (exitCode === 0);
            // Prefer cliphist only if explicitly enabled and available
            root.useCliphist = root.useCliphist && root.cliphistAvailable;
            if (root.useCliphist) {
                try { Cliphist.refresh(); cliphistPopulateTimer.start(); } catch(e) {}
            }
        }
    }

    // Optional Cliphist-based history (preferred when installed)
    Timer {
        id: cliphistPopulateTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (!root.useCliphist) return;
            try {
                const entries = Cliphist.entries || [];
                root.history = entries.map(e => ({
                    raw: e,
                    text: cleanCliphistEntry(e),
                    isImage: Cliphist.entryIsImage(e),
                    imagePath: Cliphist.entryIsImage(e) ? Cliphist.decodeImageTo(e) : "",
                    time: Date.now()
                }));
                if (root.history.length > root.maxHistory)
                    root.history = root.history.slice(0, root.maxHistory);
                historyChanged();
            } catch (e) {
                // no-op
            }
        }
    }

    // Periodic poll to pick up Cliphist.entries when the service refreshes
    Timer {
        id: cliphistPoller
        interval: 1000
        repeat: true
        running: root.useCliphist
        onTriggered: {
            try {
                const entries = Cliphist.entries || [];
                // Only update if different length or first entry differs
                if (entries.length !== root.history.length || (entries[0] && root.history[0] && entries[0] !== root.history[0].raw)) {
                    root.history = entries.map(e => ({
                        raw: e,
                        text: cleanCliphistEntry(e),
                        isImage: Cliphist.entryIsImage(e),
                        imagePath: Cliphist.entryIsImage(e) ? Cliphist.decodeImageTo(e) : "",
                        time: Date.now()
                    }));
                    historyChanged();
                }
            } catch (e) {}
        }
    }

    // ── Panel ────────────────────────────────────────────────────────────────
    implicitWidth: Tokens.sizes.utilities.width
    implicitHeight: Math.min(panelCol.implicitHeight + Tokens.padding.large * 2, 520)

    // Glass background
    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: Qt.rgba(1, 1, 1, 0.06)
        border.color: Qt.rgba(1, 1, 1, 0.15)
        border.width: 1
    }
    StyledRect {
        anchors.fill: parent
        anchors.margins: 1
        radius: Tokens.rounding.large - 1
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
    }

    ColumnLayout {
        id: panelCol
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        // ── Search ────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42
            radius: Tokens.rounding.large
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "search"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: Colours.palette.m3onSurface
                    font.pointSize: Tokens.font.size.small
                    font.family: Tokens.font.family
                    clip: true
                    selectByMouse: true
                    onTextChanged: root.searchText = text

                    Text {
                        visible: !searchInput.text.length
                        text: qsTr("Search clipboard")
                        color: Qt.rgba(1, 1, 1, 0.28)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 26
                    radius: Tokens.rounding.full
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1

                    StyledText {
                        anchors.centerIn: parent
                        text: qsTr("Ctrl+K")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.extraSmall
                    }
                }
            }
        }

        // ── History list ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: 1
            clip: true

            StyledListView {
                id: listView
                anchors.fill: parent
                spacing: Tokens.spacing.small
                model: root.history
                visible: root.history.length > 0

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: listView
                }

                displaced: Transition {
                    NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutCubic }
                }

                delegate: ClipItem {
                    width: listView.width
                    entry: modelData
                    index: index
                    onCopyRequested: {
                        const item = root.history[index];
                        if (root.useCliphist && item.raw) {
                            Cliphist.copy(item.raw);
                        } else {
                            Quickshell.execDetached(["sh", "-c",
                                "printf '%s' " + root.shellQuote(entry.text) + " | wl-copy"]);
                        }
                        root.visibilities.clipboard = false;
                    }
                    onDeleteRequested: {
                        root.history.splice(index, 1);
                        root.historyChanged();
                    }
                }
            }

            Item {
                anchors.centerIn: parent
                visible: root.history.length === 0
                implicitHeight: emptyCol.implicitHeight
                implicitWidth: emptyCol.implicitWidth

                ColumnLayout {
                    id: emptyCol
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "content_paste_off"
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.extraLarge
                        opacity: 0.5
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Nothing copied yet")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.small
                        opacity: 0.6
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42
            radius: Tokens.rounding.large
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: Tokens.spacing.small

                StyledText {
                    text: Cliphist && Cliphist.hasError ? Cliphist.errorMessage : qsTr("Ready")
                    color: Cliphist && Cliphist.hasError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.extraSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Item {
                    implicitWidth: copyChip.implicitWidth
                    implicitHeight: copyChip.implicitHeight

                    Rectangle {
                        id: copyChip
                        implicitWidth: copyRow.implicitWidth + 18
                        implicitHeight: 30
                        radius: Tokens.rounding.full
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        Row {
                            id: copyRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIcon {
                                text: "keyboard_return"
                                color: Colours.palette.m3primary
                                font.pointSize: Tokens.font.size.small
                            }
                            StyledText {
                                text: qsTr("Copy")
                                color: Colours.palette.m3onSurface
                                font.pointSize: Tokens.font.size.extraSmall
                            }
                        }
                    }
                }

                Item {
                    implicitWidth: deleteChip.implicitWidth
                    implicitHeight: deleteChip.implicitHeight

                    Rectangle {
                        id: deleteChip
                        implicitWidth: deleteRow.implicitWidth + 18
                        implicitHeight: 30
                        radius: Tokens.rounding.full
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        Row {
                            id: deleteRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIcon {
                                text: "delete"
                                color: Colours.palette.m3error
                                font.pointSize: Tokens.font.size.small
                            }
                            StyledText {
                                text: qsTr("Delete")
                                color: Colours.palette.m3onSurface
                                font.pointSize: Tokens.font.size.extraSmall
                            }
                        }
                    }
                }

                Item {
                    implicitWidth: closeChip.implicitWidth
                    implicitHeight: closeChip.implicitHeight

                    Rectangle {
                        id: closeChip
                        implicitWidth: closeRow.implicitWidth + 18
                        implicitHeight: 30
                        radius: Tokens.rounding.full
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        Row {
                            id: closeRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIcon {
                                text: "close"
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Tokens.font.size.small
                            }
                            StyledText {
                                text: qsTr("Close")
                                color: Colours.palette.m3onSurface
                                font.pointSize: Tokens.font.size.extraSmall
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function shellQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    function cleanCliphistEntry(str) {
        if (!str) return "";
        // Remove leading "NUM\t" if present
        return str.replace(/^\s*\d+\t/, "").replace(/^\s*/, "");
    }

    function cliphistId(entry) {
        if (!entry || !entry.raw)
            return "";
        const idx = String(entry.raw).indexOf("\t");
        return idx > 0 ? String(entry.raw).slice(0, idx).trim() : "";
    }

    Component.onCompleted: {
        // Probe for cliphist and populate accordingly
        cliphistProbe.running = true;
    }

    // ── Clip item component ───────────────────────────────────────────────────
    component ClipItem: Item {
        id: clipItem

        required property var entry
        required property int index
        signal copyRequested()
        signal deleteRequested()

        implicitHeight: itemRow.implicitHeight + Tokens.padding.normal * 2
        readonly property bool hasImage: !!(clipItem.entry && clipItem.entry.isImage)
        readonly property string thumbnailPath: clipItem.entry ? clipItem.entry.imagePath : ""

        // Card background
        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.normal
            color: copyState.containsMouse
                ? Qt.rgba(1, 1, 1, 0.08)
                : Qt.rgba(1, 1, 1, 0.03)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        StateLayer {
            id: copyState
            anchors.fill: parent
            radius: Tokens.rounding.normal
            hoverEnabled: true
            onClicked: clipItem.copyRequested()
        }

        RowLayout {
            id: itemRow
            anchors {
                left: parent.left; right: parent.right
                top: parent.top
                margins: Tokens.padding.normal
            }
            spacing: Tokens.spacing.small

            Rectangle {
                visible: clipItem.hasImage
                Layout.preferredWidth: 54
                Layout.preferredHeight: 54
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: clipItem.hasImage && clipItem.thumbnailPath.length > 0
                    source: clipItem.thumbnailPath.length > 0 ? ("file://" + clipItem.thumbnailPath) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !clipItem.hasImage || clipItem.thumbnailPath.length === 0
                    color: Qt.rgba(1, 1, 1, 0.04)

                    StyledText {
                        anchors.centerIn: parent
                        text: "img"
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font.pointSize: Tokens.font.size.small
                        font.weight: Font.Medium
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: clipItem.hasImage ? (clipItem.entry.text || qsTr("Image")) : ((clipItem.entry && clipItem.entry.text) ? clipItem.entry.text : "")
                    font.pointSize: Tokens.font.size.small
                    color: Colours.palette.m3onSurface
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: clipItem.entry && clipItem.entry.raw ? clipItem.entry.raw : ""
                        font.pointSize: Tokens.font.size.extraSmall
                        color: Colours.palette.m3onSurfaceVariant
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: cliphistId(clipItem.entry)
                        font.pointSize: Tokens.font.size.extraSmall
                        color: Colours.palette.m3primary
                    }
                }
            }

            // Delete button
            Item {
                implicitWidth: 28
                implicitHeight: 28
                Layout.alignment: Qt.AlignVCenter

                StateLayer {
                    id: delState
                    anchors.fill: parent
                    radius: Tokens.rounding.full
                    hoverEnabled: true
                    onClicked: clipItem.deleteRequested()
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "close"
                    font.pointSize: Tokens.font.size.small
                    color: delState.containsMouse
                        ? Colours.palette.m3error
                        : Colours.palette.m3onSurfaceVariant
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        scale: 0.98
        opacity: 0
        Component.onCompleted: {
            opacity = 1
            scale = 1
        }
        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack; overshoot: 1.15 }
        }
    }
}
