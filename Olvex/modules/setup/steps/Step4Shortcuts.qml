import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services
import ".."

// Step 4: Essential shortcuts overview.
// Reads actual configured binds dynamically from SetupState (synced with variables.lua & Hyprland).
FocusScope {
    id: root

    required property var wiz
    required property var backend

    readonly property var defaultKeys: ({
        "launcher": ["Super"],
        "drawers": ["Super", "K"],
        "clipboard": ["Super", "V"],
        "screenshot": ["Super", "Shift", "S"],
        "terminal": ["Super", "T"],
        "closeWindow": ["Super", "Q"],
        "cheatsheet": ["Super", "/"],
        "lockScreen": ["Super", "L"]
    })

    readonly property var tour: [
        {
            id: "launcher",
            icon: "apps",
            title: qsTr("App launcher"),
            hint: qsTr("Search apps, files & calculations")
        },
        {
            id: "drawers",
            icon: "dashboard",
            title: qsTr("All drawers"),
            hint: qsTr("Dashboard, launcher & utilities")
        },
        {
            id: "clipboard",
            icon: "content_copy",
            title: qsTr("Clipboard history"),
            hint: qsTr("Browse & paste recent clips")
        },
        {
            id: "screenshot",
            icon: "photo_camera",
            title: qsTr("Screen snip"),
            hint: qsTr("Capture area to clipboard or file")
        },
        {
            id: "terminal",
            icon: "terminal",
            title: qsTr("Terminal emulator"),
            hint: qsTr("Open command line terminal")
        },
        {
            id: "closeWindow",
            icon: "close",
            title: qsTr("Close active window"),
            hint: qsTr("Close the focused application")
        },
        {
            id: "cheatsheet",
            icon: "keyboard",
            title: qsTr("Full cheatsheet"),
            hint: qsTr("Explore every desktop shortcut")
        },
        {
            id: "lockScreen",
            icon: "lock",
            title: qsTr("Lock screen"),
            hint: qsTr("Lock your desktop session")
        }
    ]

    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: event => {
        const meta = event.modifiers & Qt.MetaModifier;
        const shift = event.modifiers & Qt.ShiftModifier;

        if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) {
            flashRow("launcher");
        } else if (meta && event.key === Qt.Key_K) {
            flashRow("drawers");
        } else if (meta && event.key === Qt.Key_V) {
            flashRow("clipboard");
        } else if (meta && shift && event.key === Qt.Key_S) {
            flashRow("screenshot");
        } else if (meta && event.key === Qt.Key_T) {
            flashRow("terminal");
        } else if (meta && (event.key === Qt.Key_Q || event.key === Qt.Key_C)) {
            flashRow("closeWindow");
        } else if (meta && event.key === Qt.Key_L) {
            flashRow("lockScreen");
        } else if (meta && event.key === Qt.Key_Slash) {
            flashRow("cheatsheet");
        }
    }

    property var activeHighlights: ({})

    function flashRow(id) {
        let copy = Object.assign({}, activeHighlights);
        copy[id] = true;
        activeHighlights = copy;
        root.wiz.markTried(id);

        let t = Qt.createQmlObject('import QtQuick; Timer { interval: 1400; running: true; repeat: false; }', root);
        t.triggered.connect(() => {
            let next = Object.assign({}, root.activeHighlights);
            delete next[id];
            root.activeHighlights = next;
            t.destroy();
        });
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 16

        StepHeader {
            order: 0
            title: qsTr("Essential shortcuts")
            subtitle: qsTr("Useful keybindings configured for your desktop environment.")
        }

        Stagger {
            order: 1
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                columnSpacing: 14
                rowSpacing: 12

                Repeater {
                    model: root.tour

                    delegate: StyledRect {
                        id: card

                        required property var modelData
                        required property int index

                        readonly property var currentKeys: {
                            if (root.wiz.shortcutBinds && root.wiz.shortcutBinds[modelData.id])
                                return root.wiz.shortcutBinds[modelData.id];
                            return root.defaultKeys[modelData.id] || ["Super"];
                        }
                        readonly property bool isHighlighted: !!root.activeHighlights[modelData.id]

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        implicitHeight: 74
                        radius: 16
                        border.width: 0
                        border.color: "transparent"
                        color: isHighlighted
                            ? Qt.alpha(Colours.palette.m3primary, 0.20)
                            : root.wiz.cardColor(2)

                        Behavior on color {
                            CAnim {}
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            // Squircle Icon Container
                            StyledRect {
                                implicitWidth: 38
                                implicitHeight: 38
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                Layout.alignment: Qt.AlignVCenter
                                radius: 11
                                color: Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.12 : 0.16)
                                border.width: 0
                                border.color: "transparent"

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -1
                                    text: card.modelData.icon
                                    iconPointSize: 19
                                    color: Colours.palette.m3primary
                                }
                            }

                            // Label, Inline Keycaps & Description
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    StyledText {
                                        text: card.modelData.title
                                        font.weight: Font.DemiBold
                                        textPointSize: Tokens.font.size.larger
                                        color: Colours.palette.m3onSurface
                                        elide: Text.ElideRight
                                    }

                                    // Keycaps placed right next to label
                                    Row {
                                        id: keyRow
                                        spacing: 2
                                        Layout.alignment: Qt.AlignVCenter

                                        Repeater {
                                            model: card.currentKeys

                                            delegate: Row {
                                                id: keyItem

                                                required property string modelData
                                                required property int index
                                                readonly property int totalCount: card.currentKeys.length

                                                spacing: 2

                                                StyledRect {
                                                    implicitHeight: 20
                                                    implicitWidth: Math.max(20, capText.implicitWidth + 8)
                                                    radius: 5
                                                    color: Colours.light
                                                        ? Qt.alpha(Colours.palette.m3onSurface, 0.08)
                                                        : Qt.alpha(Colours.palette.m3primary, 0.18)
                                                    border.width: 0
                                                    border.color: "transparent"

                                                    StyledText {
                                                        id: capText
                                                        anchors.centerIn: parent
                                                        text: keyItem.modelData
                                                        font.family: Tokens.font.family.mono || "monospace"
                                                        font.weight: Font.DemiBold
                                                        textPointSize: 9.5
                                                        color: Colours.light
                                                            ? Colours.palette.m3onSurface
                                                            : Colours.palette.m3primary
                                                    }
                                                }

                                                StyledText {
                                                    visible: keyItem.index < keyItem.totalCount - 1
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "+"
                                                    color: Colours.light
                                                        ? Qt.alpha(Colours.palette.m3onSurface, 0.45)
                                                        : Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.5)
                                                    font.weight: Font.DemiBold
                                                    textPointSize: 8
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: card.modelData.hint
                                    elide: Text.ElideRight
                                    textPointSize: Tokens.font.size.small
                                    color: Colours.light
                                        ? Qt.alpha(Colours.palette.m3onSurface, 0.74)
                                        : Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }

                        StateLayer {
                            anchors.fill: parent
                            radius: card.radius
                            color: Colours.palette.m3primary
                            onClicked: root.flashRow(card.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
