pragma ComponentBehavior: Bound

import ".."
import "../chrome"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root
    
    property Session session
    spacing: Tokens.spacing.large
    opacity: 0.0
    transform: Translate { y: 20; id: yTrans }

    Component.onCompleted: {
        revealAnim.start()
    }

    ParallelAnimation {
        id: revealAnim
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: yTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutCubic }
    }
    
    function idxOf(list, val) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === val) return i;
        }
        return 0;
    }
    
    function modeIndex() {
        const m = GlobalConfig.appearance.themeMode;
        if (m === "light") return 0;
        if (m === "dark") return 1;
        return 2;
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Theme")
        description: qsTr("Light, dark, or automatic switching")
        icon: "contrast"

        SettingRow {
            title: qsTr("Mode")
            description: qsTr("Follow a fixed appearance or switch automatically")
            divider: true

            Segmented {
                model: [
                    { label: qsTr("Light"), icon: "light_mode" },
                    { label: qsTr("Dark"), icon: "dark_mode" },
                    { label: qsTr("Auto"), icon: "brightness_auto" }
                ]
                currentIndex: root.modeIndex()
                onSelected: i => {
                    const next = ["light", "dark", "auto"][i];
                    GlobalConfig.appearance.themeMode = next;
                    GlobalConfig.save();
                    Colours.setMode(next);
                }
            }
        }
        
        SettingRow {
            title: qsTr("Scheme variant")
            description: qsTr("Algorithm that maps the seed into a full palette")
            divider: false
            OptionPicker {
                id: variantPicker
                model: ["tonalspot", "vibrant", "expressive", "fidelity", "content", "neutral", "monochrome"]
                currentIndex: {
                    const v = (Schemes.currentVariant || "tonalspot").toLowerCase();
                    return root.idxOf(variantPicker.model, v);
                }
                onSelected: i => Schemes.setVariant(variantPicker.model[i])
            }
        }
    }
}
