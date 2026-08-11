pragma ComponentBehavior: Bound


import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Olvex.Config
import qs.services
import qs.components.filedialog
import qs.utils
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: root
    
    property Session session
    property var allFonts: Qt.fontFamilies()
    property string installPath: ""
    property string pendingFontName: ""
    spacing: Tokens.spacing.large

    function idxOf(list, val) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === val) return i;
        }
        return 0;
    }

    Process {
        id: installProc
        command: ["bash", "-c", `mkdir -p ~/.local/share/fonts && cp '${root.installPath}' ~/.local/share/fonts/ && fc-cache -f`]
        onExited: {
            Quickshell.execDetached(["notify-send", "-a", "olvex-shell", "-u", "low", qsTr("Font Installed"), qsTr("Successfully installed %1").arg(root.pendingFontName)]);
            fontListProc.running = true;
        }
    }

    Process {
        id: fontListProc
        command: ["bash", "-c", "fc-list : family | awk -F, '{print $1}' | sort | uniq"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "") {
                    let fonts = text.trim().split("\n");
                    let all = Array.from(Qt.fontFamilies());
                    for (let i = 0; i < fonts.length; i++) {
                        let f = fonts[i].trim();
                        if (f && !all.includes(f)) all.push(f);
                    }
                    all.sort((a, b) => a.localeCompare(b));
                    root.allFonts = all;
                }
            }
        }
    }

    Component.onCompleted: {
        fontListProc.running = true;
    }

    readonly property FileDialog fontPicker: FileDialog {
        title: qsTr("Select Font File")
        filterLabel: qsTr("Font Files (*.ttf, *.otf)")
        filters: ["*.ttf", "*.otf"]
        initialCwd: ["Home"]

        onAccepted: path => {
            let urlPath = path;
            if (urlPath.startsWith("file://")) {
                urlPath = urlPath.substring(7);
            }
            root.installPath = urlPath;
            let srcName = urlPath.split('/').pop().replace(/\.(ttf|otf)$/i, "");
            root.pendingFontName = srcName;
            Quickshell.execDetached(["notify-send", "-a", "olvex-shell", "-u", "low", qsTr("Installing Font"), qsTr("Copying %1...").arg(srcName)]);
            
            installProc.running = false;
            installProc.running = true;
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Fonts")
        description: qsTr("Typeface families and global text size")
        icon: "text_fields"

        SettingRow {
            title: qsTr("Sans-serif")
            description: qsTr("Primary interface font — full system list, scrollable")
            OptionPicker {
                id: sansPicker
                menuMaxHeight: 360
                model: root.allFonts
                currentIndex: {
                    const cur = GlobalConfig.appearance.font.family.sans || "Rubik";
                    return root.idxOf(sansPicker.model, cur);
                }
                onSelected: i => {
                    GlobalConfig.appearance.font.family.sans = sansPicker.model[i];
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Monospace")
            description: qsTr("Font for numbers, code and terminals")
            OptionPicker {
                id: monoPicker
                menuMaxHeight: 360
                model: {
                    const all = root.allFonts;
                    const mono = all.filter(f => /mono|code|consolas|jetbrains|fira|iosevka|hack|source code|cascadia|caskaydia|nerd|sf mono|ubuntu mono|dejavu sans mono|droid sans mono|liberation mono|comic mono|maple|victor|inconsolata|anonymous|courier|menlo|monaco/i.test(f));
                    return mono.length > 0 ? mono : all;
                }
                currentIndex: {
                    const cur = GlobalConfig.appearance.font.family.mono || "CaskaydiaCove NF";
                    return root.idxOf(monoPicker.model, cur);
                }
                onSelected: i => {
                    GlobalConfig.appearance.font.family.mono = monoPicker.model[i];
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Lockscreen & Desktop Clock")
            description: qsTr("Font used for the large time displays")
            OptionPicker {
                id: clockPicker
                menuMaxHeight: 360
                model: root.allFonts
                currentIndex: {
                    const cur = GlobalConfig.appearance.font.family.clock || "Rubik";
                    return root.idxOf(clockPicker.model, cur);
                }
                onSelected: i => {
                    GlobalConfig.appearance.font.family.clock = clockPicker.model[i];
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Add Custom Font")
            description: qsTr("Install a new font file to the system")
            divider: false
            IconTextButton {
                icon: "add"
                text: qsTr("Install Font")
                type: IconTextButton.Filled
                onClicked: root.fontPicker.open()
            }
        }
    }
}
