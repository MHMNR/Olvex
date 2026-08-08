pragma ComponentBehavior: Bound


import ".."
import "../chrome"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Olvex.Config
import qs.services

ColumnLayout {
    id: root
    
    property Session session
    spacing: Tokens.spacing.large

    function idxOf(list, val) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === val) return i;
        }
        return 0;
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
                model: Qt.fontFamilies()
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
                    const all = Qt.fontFamilies();
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
                model: Qt.fontFamilies()
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
            ButtonBase {
                implicitHeight: 36
                color: Colours.palette.m3surfaceContainerHigh
                radius: Tokens.rounding.normal
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small
                    MaterialIcon {
                        text: "add"
                        color: Colours.palette.m3onSurface
                        iconPointSize: Tokens.font.size.large
                    }
                    StyledText {
                        text: qsTr("Install Font")
                        color: Colours.palette.m3onSurface
                    }
                }
                
                onClicked: {
                    // Placeholder for font installation logic.
                    // Usually you'd open a FileDialog and copy to ~/.local/share/fonts
                    // and run fc-cache -f
                    console.log("Add Custom Font clicked");
                }
            }
        }
    }
}
