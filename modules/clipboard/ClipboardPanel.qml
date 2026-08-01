pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Olvex.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.components.containers
import qs.services

// Bottom panel clipboard popup — toggled via DrawerVisibilities.clipboard
Item {
    id: root
    required property DrawerVisibilities visibilities

    readonly property bool visible_: visibilities.clipboard ?? false
    property var filteredEntries: []
    property string searchText: ""
    property int selectedIndex: 0
    property int hoveredIndex: -1

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
        if (visible_) {
            Cliphist.refresh()
            selectedIndex = 0
            panelSearchInput.forceActiveFocus()
        }
    }

    // M3 list row — tonal surface, radius morph, emphasized motion
    component PanelClipRow : Item {
        id: row

        required property var modelData
        required property int index

        readonly property bool isImg: root.isImage(modelData)
        readonly property string imgPath: `/tmp/olvex-clip/${root.entryId(modelData)}.png`
        readonly property string preview: root.entryText(modelData)
        readonly property bool isHovered: root.hoveredIndex === index || root.selectedIndex === index

        signal activated()
        signal deleteRequested()
        signal hoverSelected()

        width: ListView.view ? ListView.view.width : 0
        implicitHeight: 56
        property real rowOpacity
        property real rowScale
        opacity: rowOpacity
        scale: rowScale

        Component.onCompleted: {
            if (isImg)
                root.decodeImage(modelData)
            rowOpacity = 0
            rowScale = 0.96
            rowReveal.start()
        }

        ParallelAnimation {
            id: rowReveal

            Anim {
                target: row
                property: "rowOpacity"
                to: 1
                type: Anim.Emphasized
            }
            Anim {
                target: row
                property: "rowScale"
                to: 1
                type: Anim.Emphasized
            }
        }

        Item {
            id: rowBody

            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing.small / 2
            anchors.rightMargin: Tokens.spacing.small / 2
            scale: rowMa.pressed ? 0.98
                : (row.isHovered ? 1.01 : (rowMa.containsMouse ? 1.005 : 1.0))
            transformOrigin: Item.Center

            Behavior on scale {
                SpringAnimation {
                    spring: rowMa.pressed ? 5.0 : 4.2
                    damping: rowMa.pressed ? 0.65 : 0.70
                    mass: 1.0
                    epsilon: 0.005
                }
            }

            StyledRect {
                id: rowSurface

                anchors.fill: parent
                radius: rowMa.pressed ? (height / 2) : Tokens.rounding.normal
                color: row.isHovered
                    ? Colours.tileHoverAccent
                    : (rowMa.containsMouse
                        ? Colours.tileHoverSecondary
                        : Colours.tileFillSubtle)
                border.width: row.isHovered ? 1 : 0
                border.color: Qt.alpha(Colours.palette.m3primary, 0.22)

                Behavior on radius {
                    Anim { type: Anim.Emphasized }
                }
                Behavior on color {
                    CAnim {}
                }
            }

            MouseArea {
                id: rowMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.activated()
                onContainsMouseChanged: {
                    if (containsMouse)
                        row.hoverSelected()
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.normal
                anchors.rightMargin: Tokens.padding.small
                spacing: Tokens.spacing.small
                z: 1

                StyledRect {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 24
                    radius: height / 2
                    color: row.isHovered
                        ? Colours.palette.m3primary
                        : Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

                    StyledText {
                        anchors.centerIn: parent
                        text: root.entryId(row.modelData)
                        textPointSize: Tokens.font.size.tiny ?? 9
                        font.weight: Font.DemiBold
                        color: row.isHovered
                            ? Colours.palette.m3onPrimary
                            : Colours.palette.m3onSurfaceVariant

                        Behavior on color { CAnim {} }
                    }
                }

                StyledClippingRect {
                    visible: row.isImg
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: Tokens.rounding.small
                    color: Colours.palette.m3tertiaryContainer
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)

                    Image {
                        id: panelThumb
                        anchors.fill: parent
                        anchors.margins: 1
                        source: ""
                        sourceSize: Qt.size(80, 80)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            Anim { type: Anim.FastEffects }
                        }

                        Timer {
                            interval: 400
                            running: row.isImg && panelThumb.source === ""
                            onTriggered: panelThumb.source = `file://${row.imgPath}`
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "image"
                        color: Qt.alpha(Colours.palette.m3onTertiaryContainer, 0.45)
                        iconPointSize: 16
                        visible: parent.children[0].status !== Image.Ready
                    }
                }

                StyledRect {
                    visible: row.isImg
                    Layout.preferredWidth: imgChipLbl.implicitWidth + Tokens.padding.normal
                    Layout.preferredHeight: 22
                    radius: height / 2
                    color: Colours.palette.m3tertiaryContainer

                    StyledText {
                        id: imgChipLbl

                        anchors.centerIn: parent
                        text: "Image"
                        textPointSize: Tokens.font.size.tiny ?? 9
                        font.weight: Font.Medium
                        color: Colours.palette.m3onTertiaryContainer
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: row.isImg
                        ? (row.preview.length > 0 ? row.preview : "Image clip")
                        : row.preview
                    textPointSize: Tokens.font.size.small
                    font.weight: row.isHovered ? Font.DemiBold : Font.Normal
                    color: row.isHovered
                        ? Colours.palette.m3onSurface
                        : Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                    maximumLineCount: 1

                    Behavior on color { CAnim {} }
                }

                IconButton {
                    type: IconButton.Text
                    icon: "close"
                    iconPointSize: 12
                    inactiveOnColour: Colours.palette.m3error
                    opacity: rowMa.containsMouse || row.isHovered ? 1 : 0
                    visible: opacity > 0
                    onClicked: row.deleteRequested()

                    Behavior on opacity {
                        Anim { type: Anim.FastEffects }
                    }
                }
            }
        }
    }

    // ── Panel container ───────────────────────────
    StyledRect {
        id: panel
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: Colours.tileSurface
        border.width: 1
        border.color: Colours.tileStroke
        clip: true

        // ── Header row ────────────────────────────
        Item {
            id: panelHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.normal
                spacing: Tokens.spacing.small

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "content_paste"
                    color: Colours.palette.m3primary
                    iconPointSize: 14
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clipboard"
                    color: Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.normal
                    font.weight: Font.DemiBold
                }
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Tokens.padding.small
                type: IconButton.Text
                icon: "delete_sweep"
                iconPointSize: 14
                inactiveOnColour: Colours.palette.m3error
                onClicked: Cliphist.wipe()
            }
        }

        Rectangle {
            anchors.top: panelHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Tokens.padding.normal
            anchors.rightMargin: Tokens.padding.normal
            height: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
        }

        // ── Search ────────────────────────────────
        Item {
            id: panelSearch
            anchors.top: panelHeader.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Tokens.padding.normal
            anchors.rightMargin: Tokens.padding.normal
            height: 40

            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.normal
                color: Colours.tileFillHover
                border.color: panelSearchInput.activeFocus
                    ? Qt.alpha(Colours.palette.m3primary, 0.55)
                    : Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                border.width: 1

                Behavior on border.color { CAnim {} }

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.normal
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        color: Colours.palette.m3onSurfaceVariant
                        iconPointSize: 12
                    }

                    TextInput {
                        id: panelSearchInput
                        width: panel.width - 88
                        color: Colours.palette.m3onSurface
                        font.pixelSize: Math.round(Tokens.font.size.small * 96 / 72)
                        font.family: Tokens.font.family.sans
                        clip: true

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search..."
                            color: Colours.palette.m3onSurfaceVariant
                            textPointSize: Tokens.font.size.small
                            opacity: 0.55
                            visible: !panelSearchInput.text.length
                        }

                        onTextChanged: {
                            root.searchText = text
                            root.selectedIndex = 0
                            root.refreshFiltered()
                        }

                        Keys.onUpPressed: event => {
                            root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                            panelList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                            event.accepted = true
                        }
                        Keys.onDownPressed: event => {
                            root.selectedIndex = Math.min(root.filteredEntries.length - 1, root.selectedIndex + 1)
                            panelList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                            event.accepted = true
                        }
                        Keys.onReturnPressed: event => {
                            if (root.filteredEntries.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length) {
                                Cliphist.copy(root.filteredEntries[root.selectedIndex])
                                root.visibilities.clipboard = false
                            }
                            event.accepted = true
                        }
                        Keys.onEnterPressed: event => {
                            if (root.filteredEntries.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length) {
                                Cliphist.copy(root.filteredEntries[root.selectedIndex])
                                root.visibilities.clipboard = false
                            }
                            event.accepted = true
                        }
                        Keys.onDeletePressed: event => {
                            if (root.filteredEntries.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length) {
                                Cliphist.deleteEntry(root.filteredEntries[root.selectedIndex])
                                root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                            }
                            event.accepted = true
                        }
                        Keys.onBackspacePressed: event => {
                            if (panelSearch.text.length === 0 && root.filteredEntries.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length) {
                                Cliphist.deleteEntry(root.filteredEntries[root.selectedIndex])
                                root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }

        // ── List ──────────────────────────────────
        StyledListView {
            id: panelList
            anchors.top: panelSearch.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Tokens.spacing.small
            anchors.bottomMargin: Tokens.spacing.small
            clip: true

            model: root.filteredEntries
            spacing: Tokens.spacing.small

            displaced: Transition {
                Anim {
                    properties: "x,y"
                    type: Anim.Emphasized
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    radius: 2
                    color: Qt.alpha(Colours.palette.m3primary, 0.45)
                    implicitWidth: 3
                }
            }

            delegate: PanelClipRow {
                onActivated: Cliphist.copy(modelData)
                onHoverSelected: root.hoveredIndex = index
                onDeleteRequested: Cliphist.deleteEntry(modelData)
            }

            // Empty state
            Item {
                visible: root.filteredEntries.length === 0
                anchors.centerIn: parent
                width: parent.width
                height: 96

                Column {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "content_paste_off"
                        color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.35)
                        iconPointSize: 28
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Nothing copied yet"
                        color: Colours.palette.m3onSurfaceVariant
                        textPointSize: Tokens.font.size.small
                        opacity: 0.65
                    }
                }
            }
        }
    }
}