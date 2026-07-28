pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

// Bottom panel clipboard popup — toggled via DrawerVisibilities.clipboard
Item {
    id: root
    required property DrawerVisibilities visibilities

    readonly property bool visible_: visibilities.clipboard ?? false
    property var filteredEntries: []
    property string searchText: ""

    function isImage(entry) { return Cliphist.entryIsImage(entry) }
    function entryText(entry) {
        if (!entry) return ""
        return entry.replace(/^\s*\d+\t/, "").replace(/^\s*/, "")
    }
    function entryId(entry) { return entry ? entry.split("\t")[0] : "" }
    function decodeImage(entry) {
        const id = entryId(entry)
        Quickshell.execDetached(["bash", "-c",
            `mkdir -p /tmp/olvex-clip && printf '%s' '${entry.replace(/'/g, "'\\''")}' | cliphist decode > /tmp/olvex-clip/${id}.png`
        ])
    }

    function refreshFiltered() {
        var q = root.searchText.trim().toLowerCase()
        var raw = Cliphist.entries
        if (!raw) raw = []
        if (q !== "") raw = raw.filter(e => String(e).toLowerCase().indexOf(q) !== -1)
        var arr = []
        for (var i = 0; i < raw.length && i < 100; i++) arr.push(raw[i])
        root.filteredEntries = arr
    }

    Connections {
        target: Cliphist
        function onEntriesChanged() { root.refreshFiltered() }
    }

    onVisible_Changed: {
        if (visible_) { Cliphist.refresh() }
    }

    // ── Panel container ───────────────────────────
    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(0.09, 0.08, 0.12, 0.97)
        border.color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
        clip: true

        // ── Header row ────────────────────────────
        Item {
            id: panelHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14
                spacing: 8

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "content_paste"
                    color: Colours.palette.m3primary
                    font.pointSize: 13
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clipboard"
                    color: Qt.rgba(1, 1, 1, 0.88)
                    font.pointSize: Tokens.font.size.normal
                    font.weight: Font.SemiBold
                }
            }

            // Clear all
            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
                width: 28; height: 28

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "delete_sweep"
                    color: Qt.rgba(1, 0.5, 0.5, 0.55)
                    font.pointSize: 14
                }
                StateLayer { radius: 14; onClicked: Cliphist.wipe() }
            }
        }

        Rectangle {
            anchors.top: panelHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        // ── Search ────────────────────────────────
        Item {
            id: panelSearch
            anchors.top: panelHeader.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height: 36

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: panelSearchInput.activeFocus
                    ? Qt.alpha(Colours.palette.m3primary, 0.5)
                    : Qt.rgba(1, 1, 1, 0.07)
                border.width: 1

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    spacing: 8

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        color: Qt.rgba(1, 1, 1, 0.3)
                        font.pointSize: 11
                    }

                    TextInput {
                        id: panelSearchInput
                        width: panel.width - 80
                        color: Qt.rgba(1, 1, 1, 0.85)
                        font.pointSize: Tokens.font.size.small
                        font.family: Tokens.font.family
                        clip: true

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search..."
                            color: Qt.rgba(1, 1, 1, 0.22)
                            font.pointSize: Tokens.font.size.small
                            visible: !panelSearchInput.text.length
                        }

                        onTextChanged: {
                            root.searchText = text
                            root.refreshFiltered()
                        }
                    }
                }
            }
        }

        // ── List ──────────────────────────────────
        ListView {
            id: panelList
            anchors.top: panelSearch.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            clip: true

            model: root.filteredEntries
            spacing: 1

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.15)
                    implicitWidth: 3
                }
            }

            delegate: Item {
                id: pd
                required property var modelData
                required property int index
                width: panelList.width
                height: isImg ? 88 : 40

                readonly property bool isImg: root.isImage(modelData)
                readonly property string imgPath: `/tmp/olvex-clip/${root.entryId(modelData)}.png`

                Component.onCompleted: {
                    if (isImg) root.decodeImage(modelData)
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    radius: 8
                    color: "transparent"

                    // Image entry
                    Row {
                        visible: pd.isImg
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        StyledClippingRect {
                            width: 110; height: 64
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.05)
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                anchors.fill: parent
                                source: pd.isImg ? `file://${pd.imgPath}` : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "image"
                                color: Qt.rgba(1, 1, 1, 0.18)
                                font.pointSize: 18
                                visible: parent.children[0].status !== Image.Ready
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            StyledText {
                                text: "Image"
                                color: Qt.rgba(1, 1, 1, 0.5)
                                font.pointSize: Tokens.font.size.small
                                font.weight: Font.Medium
                            }
                            StyledText {
                                text: {
                                    const m = pd.modelData.match(/(\d+x\d+)/)
                                    return m ? m[1] : ""
                                }
                                color: Qt.rgba(1, 1, 1, 0.25)
                                font.pointSize: Tokens.font.size.tiny ?? 9
                            }
                        }
                    }

                    // Text entry
                    Item {
                        visible: !pd.isImg
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 36

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            text: root.entryText(pd.modelData)
                            color: Qt.rgba(1, 1, 1, 0.72)
                            font.pointSize: Tokens.font.size.small
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Delete on hover
                    Item {
                        id: deleteBtn
                        visible: deleteHover.containsMouse
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 6
                        width: 26; height: 26

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            color: Qt.rgba(1, 0.45, 0.45, 0.7)
                            font.pointSize: 11
                        }
                        MouseArea {
                            id: deleteHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Cliphist.deleteEntry(pd.modelData)
                        }
                    }

                    StateLayer {
                        radius: 8
                        onClicked: Cliphist.copy(pd.modelData)
                    }
                }
            }

            // Empty state
            Item {
                visible: root.filteredEntries.length === 0
                anchors.centerIn: parent
                width: parent.width
                height: 80

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "content_paste_off"
                        color: Qt.rgba(1, 1, 1, 0.12)
                        font.pointSize: 24
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Nothing copied yet"
                        color: Qt.rgba(1, 1, 1, 0.22)
                        font.pointSize: Tokens.font.size.small
                    }
                }
            }
        }
    }
}
