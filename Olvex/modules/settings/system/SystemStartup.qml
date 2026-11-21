import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Olvex
import Olvex.Config
import qs.services

Item {
    id: root

    property Session session
    property var appJoin
    property var appSplit
    property var idxOf

    property var autostartEntries: []

    function reloadEntries() {
        scanProc.running = true;
    }

    function toggleEntry(filePath, enabled) {
        toggleProc.command = [
            "python3", "-c",
            "import sys\n" +
            "p, en = sys.argv[1], sys.argv[2] == '1'\n" +
            "with open(p, 'r', errors='ignore') as f: lines = f.readlines()\n" +
            "out = [l for l in lines if not l.startswith('Hidden=') and not l.startswith('X-GNOME-Autostart-enabled=')]\n" +
            "out.append('Hidden=' + ('false' if en else 'true') + '\\n')\n" +
            "out.append('X-GNOME-Autostart-enabled=' + ('true' if en else 'false') + '\\n')\n" +
            "with open(p, 'w') as f: f.writelines(out)\n",
            filePath, enabled ? "1" : "0"
        ];
        toggleProc.running = true;
    }

    function removeEntry(filePath) {
        removeProc.command = ["rm", "-f", filePath];
        removeProc.running = true;
    }

    function addEntry(name, execCmd) {
        const cleanName = (name || "").trim();
        const cleanExec = (execCmd || "").trim();
        if (!cleanName || !cleanExec) return;
        addProc.command = [
            "python3", "-c",
            "import os, re, sys\n" +
            "name, cmd = sys.argv[1], sys.argv[2]\n" +
            "d = os.path.expanduser('~/.config/autostart')\n" +
            "os.makedirs(d, exist_ok=True)\n" +
            "slug = re.sub(r'[^a-z0-9_-]+', '-', name.lower()).strip('-') or 'startup-app'\n" +
            "p = os.path.join(d, f'olvex-{slug}.desktop')\n" +
            "with open(p, 'w') as f:\n" +
            "  f.write(f'[Desktop Entry]\\nType=Application\\nName={name}\\nExec={cmd}\\nHidden=false\\nX-GNOME-Autostart-enabled=true\\n')\n",
            cleanName, cleanExec
        ];
        addProc.running = true;
    }

    Process {
        id: scanProc
        running: true
        command: [
            "python3", "-c",
            "import os, glob, json\n" +
            "d = os.path.expanduser('~/.config/autostart')\n" +
            "items = []\n" +
            "if os.path.isdir(d):\n" +
            "  for p in sorted(glob.glob(os.path.join(d, '*.desktop'))):\n" +
            "    name, exe, hidden, gnome_en = os.path.basename(p), '', False, True\n" +
            "    try:\n" +
            "      with open(p, 'r', errors='ignore') as f:\n" +
            "        for line in f:\n" +
            "          s = line.strip()\n" +
            "          if s.startswith('Name='): name = s[5:].strip()\n" +
            "          elif s.startswith('Exec='): exe = s[5:].strip()\n" +
            "          elif s == 'Hidden=true': hidden = True\n" +
            "          elif s == 'X-GNOME-Autostart-enabled=false': gnome_en = False\n" +
            "    except Exception: continue\n" +
            "    items.append({'path': p, 'name': name, 'exec': exe, 'enabled': (not hidden) and gnome_en})\n" +
            "print(json.dumps(items))\n"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.autostartEntries = JSON.parse(text) || [];
                } catch (e) {
                    root.autostartEntries = [];
                }
            }
        }
    }

    Process {
        id: toggleProc
        onExited: root.reloadEntries()
    }

    Process {
        id: removeProc
        onExited: root.reloadEntries()
    }

    Process {
        id: addProc
        onExited: (exitCode) => {
            if (exitCode === 0) {
                newNameField.text = "";
                newExecField.text = "";
                if (typeof Toaster !== "undefined" && Toaster.toast)
                    Toaster.toast(qsTr("Startup app added"), "", "rocket_launch");
            }
            root.reloadEntries();
        }
    }

    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()

    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.normal || 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.normal || 300; easing.type: Easing.OutCubic }
    }

    implicitHeight: (col ? col.implicitHeight : 0) + Tokens.padding.large * 2

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        spacing: Tokens.spacing.large

        Section {
            Layout.fillWidth: true
            title: qsTr("Add Startup Application")
            description: qsTr("Create an XDG autostart entry in ~/.config/autostart")
            icon: "add_circle"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Application name")
                description: qsTr("Display label for the startup item")
                StyledTextField {
                    id: newNameField
                    width: Math.max(260, Math.round(contentWidth + leftPadding + rightPadding + 16))
                    placeholderText: qsTr("e.g. Discord")
                    Keys.onReturnPressed: newExecField.focus = true
                    Keys.onEnterPressed: newExecField.focus = true
                }
            }

            SettingRow {
                title: qsTr("Command")
                description: qsTr("Executable path or shell command")
                RowLayout {
                    spacing: Tokens.spacing.small
                    StyledTextField {
                        id: newExecField
                        width: Math.max(195, Math.round(contentWidth + leftPadding + rightPadding + 16))
                        Layout.preferredWidth: width
                        placeholderText: qsTr("e.g. discord --start-minimized")
                        Keys.onReturnPressed: {
                            if (newExecField.text.trim().length > 0)
                                root.addEntry(newNameField.text, newExecField.text)
                        }
                        Keys.onEnterPressed: {
                            if (newExecField.text.trim().length > 0)
                                root.addEntry(newNameField.text, newExecField.text)
                        }
                    }
                    StyledRect {
                        readonly property bool canAdd: newExecField.text.trim().length > 0
                        implicitWidth: addLbl.implicitWidth + 28
                        implicitHeight: 36
                        radius: Tokens.rounding.full
                        color: canAdd ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.12)

                        Behavior on color { CAnim {} }

                        StyledText {
                            id: addLbl
                            anchors.centerIn: parent
                            text: qsTr("Add")
                            color: parent.canAdd ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                            font.weight: Font.Medium
                            textPointSize: Tokens.font.size.small
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            enabled: parent.canAdd
                            onClicked: root.addEntry(newNameField.text, newExecField.text)
                        }
                    }
                }
            }
        }

        Section {
            Layout.fillWidth: true
            title: qsTr("XDG Autostart Entries")
            description: qsTr("Applications launched automatically on login")
            icon: "rocket_launch"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                visible: root.autostartEntries.length === 0
                title: qsTr("No autostart entries found")
                description: qsTr("Add an entry above or place .desktop files in ~/.config/autostart")
            }

            Repeater {
                model: root.autostartEntries
                delegate: SettingRow {
                    required property var modelData
                    title: modelData.name || qsTr("Unnamed")
                    description: modelData.exec || modelData.path
                    RowLayout {
                        spacing: Tokens.spacing.small
                        StyledSwitch {
                            checked: !!modelData.enabled
                            onToggled: root.toggleEntry(modelData.path, checked)
                        }
                        IconButton {
                            icon: "delete"
                            type: IconButton.Text
                            onClicked: root.removeEntry(modelData.path)
                        }
                    }
                }
            }
        }
    }
}

