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

    property var browserApps: []
    property var fileManagerApps: []
    property var terminalApps: []
    property var editorApps: []
    property var videoApps: []
    property var imageApps: []

    property string currentBrowser: ""
    property string currentFileManager: ""
    property string currentTerminal: ""
    property string currentEditor: ""
    property string currentVideo: ""
    property string currentImage: ""

    function indexForVal(list, val) {
        if (!list || !list.length) return 0;
        const idx = list.findIndex(o => o.val === val);
        return idx >= 0 ? idx : 0;
    }

    function setMimeDefault(mime, desktopId) {
        if (!desktopId) return;
        setMimeProc.command = ["xdg-mime", "default", desktopId, mime];
        setMimeProc.running = true;
    }

    function setTerminalDefault(desktopId) {
        if (!desktopId) return;
        setTermProc.command = ["bash", "-c", "mkdir -p ~/.config && printf '%s\\n' \"$1\" > ~/.config/xdg-terminals.list", "sh", desktopId];
        setTermProc.running = true;
    }

    Process {
        id: setMimeProc
        onExited: (exitCode) => {
            if (exitCode === 0 && typeof Toaster !== "undefined" && Toaster.toast)
                Toaster.toast(qsTr("Default app updated"), "", "check_circle");
        }
    }

    Process {
        id: setTermProc
        onExited: (exitCode) => {
            if (exitCode === 0 && typeof Toaster !== "undefined" && Toaster.toast)
                Toaster.toast(qsTr("Default terminal updated"), "", "terminal");
        }
    }

    Process {
        id: scanProc
        running: true
        command: [
            "python3", "-c",
            "import os, glob, json, subprocess\n" +
            "dirs = ['/usr/share/applications', os.path.expanduser('~/.local/share/applications')]\n" +
            "cats = {'WebBrowser': {}, 'FileManager': {}, 'TerminalEmulator': {}, 'TextEditor': {}, 'Video': {}, 'Graphics': {}}\n" +
            "for d in dirs:\n" +
            "  for p in glob.glob(os.path.join(d, '*.desktop')):\n" +
            "    fn = os.path.basename(p)\n" +
            "    name, cat_str, nodisp = None, '', False\n" +
            "    try:\n" +
            "      with open(p, 'r', errors='ignore') as f:\n" +
            "        in_entry = False\n" +
            "        for line in f:\n" +
            "          s = line.strip()\n" +
            "          if s == '[Desktop Entry]': in_entry = True; continue\n" +
            "          if s.startswith('[') and in_entry: break\n" +
            "          if not in_entry: continue\n" +
            "          if s.startswith('Name=') and not name: name = s[5:].strip()\n" +
            "          elif s.startswith('Categories='): cat_str = s[11:].strip()\n" +
            "          elif s == 'NoDisplay=true' or s == 'Hidden=true': nodisp = True\n" +
            "    except Exception: continue\n" +
            "    if nodisp or not name: continue\n" +
            "    cset = set(c.strip() for c in cat_str.split(';') if c.strip())\n" +
            "    for k in cats:\n" +
            "      if k in cset: cats[k][fn] = {'label': name, 'val': fn}\n" +
            "def qmime(m):\n" +
            "  try: return subprocess.check_output(['xdg-mime', 'query', 'default', m], stderr=subprocess.DEVNULL).decode().strip()\n" +
            "  except Exception: return ''\n" +
            "term = ''\n" +
            "tp = os.path.expanduser('~/.config/xdg-terminals.list')\n" +
            "if os.path.exists(tp):\n" +
            "  with open(tp, 'r', errors='ignore') as f:\n" +
            "    for l in f:\n" +
            "      l = l.strip()\n" +
            "      if l and not l.startswith('#'): term = l; break\n" +
            "out = {\n" +
            "  'apps': {k: sorted(v.values(), key=lambda x: x['label'].lower()) for k, v in cats.items()},\n" +
            "  'cur': {\n" +
            "    'browser': qmime('x-scheme-handler/http'),\n" +
            "    'fm': qmime('inode/directory'),\n" +
            "    'terminal': term,\n" +
            "    'editor': qmime('text/plain'),\n" +
            "    'video': qmime('video/mp4'),\n" +
            "    'image': qmime('image/png')\n" +
            "  }\n" +
            "}\n" +
            "print(json.dumps(out))\n"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (data.apps) {
                        root.browserApps = data.apps.WebBrowser || [];
                        root.fileManagerApps = data.apps.FileManager || [];
                        root.terminalApps = data.apps.TerminalEmulator || [];
                        root.editorApps = data.apps.TextEditor || [];
                        root.videoApps = data.apps.Video || [];
                        root.imageApps = data.apps.Graphics || [];
                    }
                    if (data.cur) {
                        root.currentBrowser = data.cur.browser || "";
                        root.currentFileManager = data.cur.fm || "";
                        root.currentTerminal = data.cur.terminal || "";
                        root.currentEditor = data.cur.editor || "";
                        root.currentVideo = data.cur.video || "";
                        root.currentImage = data.cur.image || "";
                    }
                } catch (e) {}
            }
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
            title: qsTr("Core Applications")
            description: qsTr("Choose default applications for links, folders, and terminal")
            icon: "apps"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Web browser")
                description: qsTr("Default handler for HTTP/HTTPS links")
                OptionPicker {
                    model: root.browserApps
                    currentIndex: root.indexForVal(root.browserApps, root.currentBrowser)
                    onSelected: i => {
                        const opt = root.browserApps[i];
                        if (opt) {
                            root.currentBrowser = opt.val;
                            root.setMimeDefault("x-scheme-handler/http", opt.val);
                            root.setMimeDefault("x-scheme-handler/https", opt.val);
                        }
                    }
                }
            }

            SettingRow {
                title: qsTr("File manager")
                description: qsTr("Default app for opening directories")
                OptionPicker {
                    model: root.fileManagerApps
                    currentIndex: root.indexForVal(root.fileManagerApps, root.currentFileManager)
                    onSelected: i => {
                        const opt = root.fileManagerApps[i];
                        if (opt) {
                            root.currentFileManager = opt.val;
                            root.setMimeDefault("inode/directory", opt.val);
                        }
                    }
                }
            }

            SettingRow {
                title: qsTr("Terminal emulator")
                description: qsTr("Default XDG terminal (~/.config/xdg-terminals.list)")
                OptionPicker {
                    model: root.terminalApps
                    currentIndex: root.indexForVal(root.terminalApps, root.currentTerminal)
                    onSelected: i => {
                        const opt = root.terminalApps[i];
                        if (opt) {
                            root.currentTerminal = opt.val;
                            root.setTerminalDefault(opt.val);
                        }
                    }
                }
            }
        }

        Section {
            Layout.fillWidth: true
            title: qsTr("Files & Media")
            description: qsTr("Default viewers and editors for common file types")
            icon: "perm_media"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Text editor")
                description: qsTr("Default app for plain text files")
                OptionPicker {
                    model: root.editorApps
                    currentIndex: root.indexForVal(root.editorApps, root.currentEditor)
                    onSelected: i => {
                        const opt = root.editorApps[i];
                        if (opt) {
                            root.currentEditor = opt.val;
                            root.setMimeDefault("text/plain", opt.val);
                        }
                    }
                }
            }

            SettingRow {
                title: qsTr("Video player")
                description: qsTr("Default app for video playback")
                OptionPicker {
                    model: root.videoApps
                    currentIndex: root.indexForVal(root.videoApps, root.currentVideo)
                    onSelected: i => {
                        const opt = root.videoApps[i];
                        if (opt) {
                            root.currentVideo = opt.val;
                            root.setMimeDefault("video/mp4", opt.val);
                        }
                    }
                }
            }

            SettingRow {
                title: qsTr("Image viewer")
                description: qsTr("Default app for PNG and JPEG images")
                OptionPicker {
                    model: root.imageApps
                    currentIndex: root.indexForVal(root.imageApps, root.currentImage)
                    onSelected: i => {
                        const opt = root.imageApps[i];
                        if (opt) {
                            root.currentImage = opt.val;
                            root.setMimeDefault("image/png", opt.val);
                            root.setMimeDefault("image/jpeg", opt.val);
                        }
                    }
                }
            }
        }
    }
}

