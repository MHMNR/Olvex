import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services
import "../../settings/ui"
import ".."

// Step 3: Default applications (Terminal, Web Browser, File Manager).
// Uses Olvex's standard SettingRow + official OptionPicker component.
Item {
    id: root

    required property var wiz
    required property var backend

    function selectTerminal(id) {
        root.wiz.selectedTerminal = id;
        root.backend.applyDefaultApps(root.wiz.selectedTerminal, root.wiz.selectedBrowser, root.wiz.selectedFileManager);
    }

    function selectBrowser(id) {
        root.wiz.selectedBrowser = id;
        root.backend.applyDefaultApps(root.wiz.selectedTerminal, root.wiz.selectedBrowser, root.wiz.selectedFileManager);
    }

    function selectFileManager(id) {
        root.wiz.selectedFileManager = id;
        root.backend.applyDefaultApps(root.wiz.selectedTerminal, root.wiz.selectedBrowser, root.wiz.selectedFileManager);
    }

    function keysForBind(bindId, fallback) {
        const binds = root.wiz.shortcutBinds;
        const arr = (binds && binds[bindId] && binds[bindId].length > 0)
            ? binds[bindId]
            : fallback;
        return arr.map((k, idx) => ({
            text: k,
            isTrigger: idx === arr.length - 1
        }));
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 16

        StepHeader {
            order: 0
            title: qsTr("Default applications")
            subtitle: qsTr("Select installed default apps and see their shortcut keybindings.")
        }

        Section {
            Layout.fillWidth: true
            title: qsTr("Applications")
            description: qsTr("System-wide defaults for terminal, browser and file manager")
            icon: "apps"

            SettingRow {
                icon: "terminal"
                title: qsTr("Terminal emulator")
                customCardColor: root.wiz.cardColor(2)
                customCardHoverColor: root.wiz.cardHoverColor(3)
                keys: root.keysForBind("terminal", ["Super", "T"])
                description: qsTr("Launched for terminal tasks and shell commands")

                OptionPicker {
                    model: root.wiz.availableTerminals
                    currentIndex: root.wiz.indexOfAppId(model, root.wiz.selectedTerminal)
                    onSelected: index => root.selectTerminal(model[index].id)
                }
            }

            SettingRow {
                icon: "language"
                title: qsTr("Web browser")
                customCardColor: root.wiz.cardColor(2)
                customCardHoverColor: root.wiz.cardHoverColor(3)
                keys: root.keysForBind("browser", ["Super", "B"])
                description: qsTr("Default browser for web links and online services")

                OptionPicker {
                    model: root.wiz.availableBrowsers
                    currentIndex: root.wiz.indexOfAppId(model, root.wiz.selectedBrowser)
                    onSelected: index => root.selectBrowser(model[index].id)
                }
            }

            SettingRow {
                icon: "folder"
                title: qsTr("File manager")
                customCardColor: root.wiz.cardColor(2)
                customCardHoverColor: root.wiz.cardHoverColor(3)
                keys: root.keysForBind("fileManager", ["Super", "E"])
                description: qsTr("Opened for files, directories and file picker")

                OptionPicker {
                    model: root.wiz.availableFileManagers
                    currentIndex: root.wiz.indexOfAppId(model, root.wiz.selectedFileManager)
                    onSelected: index => root.selectFileManager(model[index].id)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
