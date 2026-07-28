pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Olvex.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// Floating clipboard window — triggered by Super+V / `olvex clipboard` IPC
// Keyboard: Up/Down navigate, Enter copy+close, Esc close, Delete remove entry
PanelWindow {
    id: root

    implicitWidth: 680
    implicitHeight: 520
    visible: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // ── State ──────────────────────────────────────
    property int selectedIndex: 0
    property string searchText: ""
    property var filteredEntries: []

    // ── IPC open trigger ──────────────────────────
    IpcHandler {
        target: "clipboard"
        function open() {
            root.visible = true
            root.selectedIndex = 0
            root.searchText = ""
            searchField.forceActiveFocus()
            root.refreshFiltered()
        }
    }

    onVisibleChanged: {
        if (visible) {
            Cliphist.refresh()
            selectedIndex = 0
            searchText = ""
            searchField.forceActiveFocus()
        } else {
            Quickshell.execDetached(["bash", "-c", "rm -rf /tmp/olvex-clip/"])
        }
    }



    function refreshFiltered() {
        var q = searchText.trim().toLowerCase()
        var raw = Cliphist.entries
        if (!raw) raw = []
        if (q !== "") raw = raw.filter(e => String(e).toLowerCase().indexOf(q) !== -1)
        var arr = []
        for (var i = 0; i < raw.length && i < 200; i++) arr.push(raw[i])
        filteredEntries = arr
    }

    function copyAndClose(entry) {
        if (!entry) return
        Cliphist.copy(entry)
        root.visible = false
    }

    function isImage(entry) {
        return Cliphist.entryIsImage(entry)
    }

    function entryId(entry) {
        return entry ? entry.split("\t")[0] : ""
    }

    function entryText(entry) {
        if (!entry) return ""
        return entry.replace(/^\s*\d+\t/, "").replace(/^\s*/, "")
    }

    // ── Temp image decode ─────────────────────────
    // Decodes cliphist image entry to /tmp/olvex-clip/<id>.png
    function decodeImage(entry) {
        const id = entryId(entry)
        if (!id) return
        const outPath = `/tmp/olvex-clip/${id}.png`
        Quickshell.execDetached(["bash", "-c",
            `mkdir -p /tmp/olvex-clip && printf '%s' '${entry.replace(/'/g, "'\\''")}' | cliphist decode > ${outPath}`
        ])
    }

    // Connections to keep filtered list in sync
    Connections {
        target: Cliphist
        function onEntriesChanged() { root.refreshFiltered() }
    }

    // ── Background ────────────────────────────────
    color: "transparent"

    Rectangle {
        id: container
        anchors.fill: parent
        radius: 20
        color: Qt.rgba(0.09, 0.08, 0.12, 0.96)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        // ── Keyboard handling ─────────────────────────
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.visible = false
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.filteredEntries.length > 0)
                    root.copyAndClose(root.filteredEntries[root.selectedIndex])
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                root.selectedIndex = Math.min(root.filteredEntries.length - 1, root.selectedIndex + 1)
                listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Delete) {
                if (root.filteredEntries.length > 0) {
                    Cliphist.deleteEntry(root.filteredEntries[root.selectedIndex])
                    root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                }
                event.accepted = true
            }
        }

        // Shadow via Shape to avoid layer transparency issues on Wayland

        // ── Header ────────────────────────────────
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 56
            anchors.topMargin: 4

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 20
                spacing: 10

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "content_paste"
                    color: Colours.palette.m3primary
                    iconPointSize: 16
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clipboard"
                    color: Qt.rgba(1, 1, 1, 0.92)
                    textPointSize: Tokens.font.size.large
                    font.weight: 600
                }
            }

            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 20
                text: root.filteredEntries.length + " items"
                color: Qt.rgba(1, 1, 1, 0.35)
                textPointSize: Tokens.font.size.small
            }
        }

        // Divider
        Rectangle {
            id: divider
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        // ── Search bar ────────────────────────────
        Item {
            id: searchBar
            anchors.top: divider.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 52
            anchors.topMargin: 8

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Qt.rgba(1, 1, 1, searchField.activeFocus ? 0.08 : 0.05)
                border.color: searchField.activeFocus
                    ? Qt.alpha(Colours.palette.m3primary, 0.6)
                    : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 14
                    spacing: 10

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        color: Qt.rgba(1, 1, 1, 0.4)
                        iconPointSize: 14
                    }

                    TextInput {
                        id: searchField
                        width: searchBar.width - 80
                        color: Qt.rgba(1, 1, 1, 0.88)
                        font.pixelSize: Math.round(Tokens.font.size.normal * 96 / 72)
                        font.family: Tokens.font.family.sans
                        selectionColor: Qt.alpha(Colours.palette.m3primary, 0.4)
                        selectedTextColor: Qt.rgba(1, 1, 1, 0.95)
                        clip: true

                        // Placeholder
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search clipboard..."
                            color: Qt.rgba(1, 1, 1, 0.28)
                            textPointSize: Tokens.font.size.normal
                            visible: !searchField.text.length
                        }

                        onTextChanged: {
                            root.searchText = text
                            root.selectedIndex = 0
                            root.refreshFiltered()
                        }

                        Keys.onUpPressed: event => {
                            root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                            event.accepted = true
                        }
                        Keys.onDownPressed: event => {
                            root.selectedIndex = Math.min(root.filteredEntries.length - 1, root.selectedIndex + 1)
                            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                            event.accepted = true
                        }
                        Keys.onReturnPressed: event => {
                            if (root.filteredEntries.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length)
                                root.copyAndClose(root.filteredEntries[root.selectedIndex])
                            event.accepted = true
                        }
                        Keys.onEnterPressed: event => {
                            if (root.filteredEntries.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length)
                                root.copyAndClose(root.filteredEntries[root.selectedIndex])
                            event.accepted = true
                        }
                        Keys.onEscapePressed: event => {
                            root.visible = false
                            event.accepted = true
                        }
                        Keys.onDeletePressed: event => {
                            if (root.filteredEntries.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length) {
                                Cliphist.deleteEntry(root.filteredEntries[root.selectedIndex])
                                root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                            }
                            event.accepted = true
                        }

                        Keys.forwardTo: [container]
                    }
                }

                // Clear search button
                Item {
                    visible: searchField.text.length > 0
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 10
                    width: 28; height: 28

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "close"
                        color: Qt.rgba(1, 1, 1, 0.4)
                        iconPointSize: 12
                    }
                    StateLayer { radius: 14; onClicked: { searchField.text = ""; searchField.forceActiveFocus() } }
                }
            }
        }

        // ── Entry list ────────────────────────────
        StyledListView {
            id: listView
            anchors.top: searchBar.bottom
            anchors.bottom: footer.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 8
            clip: true

            model: root.filteredEntries
            spacing: 2

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.18)
                    implicitWidth: 4
                }
            }

            delegate: Item {
                id: delegate
                required property var modelData
                required property int index
                width: listView.width
                height: isImg ? imageThumbHeight + 24 : 52

                readonly property bool isImg: root.isImage(modelData)
                readonly property bool isSelected: index === root.selectedIndex
                readonly property int imageThumbHeight: 120
                readonly property string imgPath: `/tmp/olvex-clip/${root.entryId(modelData)}.png`

                // Decode image on first appearance
                Component.onCompleted: {
                    if (isImg) root.decodeImage(modelData)
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    radius: 10
                    color: delegate.isSelected
                        ? Qt.alpha(Colours.palette.m3primary, 0.18)
                        : Qt.rgba(1, 1, 1, 0.0)
                    border.color: delegate.isSelected
                        ? Qt.alpha(Colours.palette.m3primary, 0.35)
                        : "transparent"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }

                    // ── Image entry ───────────────
                    Item {
                        visible: delegate.isImg
                        anchors.fill: parent
                        anchors.margins: 10

                        Row {
                            anchors.fill: parent
                            spacing: 12

                            StyledClippingRect {
                                width: 180
                                height: delegate.imageThumbHeight
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.06)
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    source: ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }

                                    Timer {
                                        interval: 400
                                        running: delegate.isImg && thumbImg.source === ""
                                        onTriggered: thumbImg.source = `file://${delegate.imgPath}`
                                    }
                                }

                                // Placeholder while loading
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "image"
                                    color: Qt.rgba(1, 1, 1, 0.2)
                                    iconPointSize: 24
                                    visible: parent.children[0].status !== Image.Ready
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                StyledText {
                                    text: "Image"
                                    color: Qt.rgba(1, 1, 1, 0.55)
                                    textPointSize: Tokens.font.size.small
                                    font.weight: Font.Medium
                                }

                                // Extract dimensions from entry text
                                StyledText {
                                    text: {
                                        const m = delegate.modelData.match(/(\d+x\d+)/)
                                        return m ? m[1] : ""
                                    }
                                    color: Qt.rgba(1, 1, 1, 0.30)
                                    textPointSize: Tokens.font.size.tiny ?? 9
                                }
                            }
                        }
                    }

                    // ── Text entry ────────────────
                    Item {
                        visible: !delegate.isImg
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 44
                        anchors.topMargin: 0
                        anchors.bottomMargin: 0

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            spacing: 12

                            // Entry index badge
                            Rectangle {
                                width: 28; height: 20
                                radius: 6
                                color: Qt.rgba(1, 1, 1, 0.06)
                                anchors.verticalCenter: parent.verticalCenter
                                visible: delegate.index < 9

                                StyledText {
                                    anchors.centerIn: parent
                                    text: (delegate.index + 1).toString()
                                    color: Qt.rgba(1, 1, 1, 0.3)
                                    textPointSize: Tokens.font.size.tiny ?? 9
                                }
                            }

                            StyledText {
                                width: parent.width - 40
                                text: root.entryText(delegate.modelData)
                                color: Qt.rgba(1, 1, 1, delegate.isSelected ? 0.95 : 0.72)
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }
                    }

                    // Delete button (appears on hover/select)
                    Item {
                        visible: delegate.isSelected
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 8
                        width: 32; height: 32

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "delete"
                            color: Qt.rgba(1, 0.4, 0.4, 0.7)
                            iconPointSize: 14
                        }
                        StateLayer {
                            radius: 8
                            onClicked: {
                                Cliphist.deleteEntry(delegate.modelData)
                                root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                            }
                        }
                    }

                    StateLayer {
                        radius: 10
                        onClicked: {
                            root.selectedIndex = delegate.index
                            root.copyAndClose(delegate.modelData)
                        }
                        onContainsMouseChanged: {
                            if (containsMouse) root.selectedIndex = delegate.index
                        }
                    }
                }
            }

            // ── Empty state ───────────────────────
            Item {
                visible: root.filteredEntries.length === 0
                anchors.centerIn: parent
                width: parent.width
                height: 120

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.searchText.length > 0 ? "search_off" : "content_paste_off"
                        color: Qt.rgba(1, 1, 1, 0.15)
                        iconPointSize: 32
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.searchText.length > 0 ? "No results" : "Nothing copied yet"
                        color: Qt.rgba(1, 1, 1, 0.25)
                        textPointSize: Tokens.font.size.normal
                    }
                }
            }
        }

        // ── Footer ────────────────────────────────
        Rectangle {
            id: footer
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48
            radius: 20
            // top corners flat
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.radius
                color: parent.color
            }
            color: Qt.rgba(0.07, 0.06, 0.10, 1.0)

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16
                spacing: 6

                // Keyboard hints
                component KeyHint: Row {
                    property string keyLabel: ""
                    property string action: ""
                    spacing: 4
                    Rectangle {
                        width: keyText.implicitWidth + 10; height: 18
                        radius: 4
                        color: Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        StyledText {
                            id: keyText
                            anchors.centerIn: parent
                            text: parent.parent.keyLabel
                            color: Qt.rgba(1, 1, 1, 0.45)
                            textPointSize: Tokens.font.size.tiny ?? 9
                        }
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.action
                        color: Qt.rgba(1, 1, 1, 0.25)
                        textPointSize: Tokens.font.size.tiny ?? 9
                    }
                }

                KeyHint { keyLabel: "↑↓"; action: "navigate" }
                KeyHint { keyLabel: "↵"; action: "copy" }
                KeyHint { keyLabel: "Del"; action: "remove" }
                KeyHint { keyLabel: "Esc"; action: "close" }
            }

            // Clear all button
            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 12
                width: clearRow.implicitWidth + 24
                height: 30

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Qt.rgba(1, 0.3, 0.3, 0.0)
                    border.color: Qt.rgba(1, 0.4, 0.4, 0.25)
                    border.width: 1
                }

                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "delete_sweep"
                        color: Qt.rgba(1, 0.5, 0.5, 0.6)
                        iconPointSize: 12
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clear all"
                        color: Qt.rgba(1, 0.5, 0.5, 0.6)
                        textPointSize: Tokens.font.size.small
                    }
                }

                StateLayer {
                    radius: 8
                    onClicked: {
                        Cliphist.wipe()
                        root.visible = false
                    }
                }
            }
        }
    }


}
