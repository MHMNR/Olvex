import ".."
import "../ui"
import "../components"
import QtQuick

SettingsMasterList {
    id: root

    property string activeSection: "theme"

    sections: [
        { id: "theme", label: qsTr("Theme"), icon: "contrast" },
        { id: "transparency", label: qsTr("Transparency"), icon: "opacity" },
        { id: "fonts", label: qsTr("Fonts"), icon: "font_download" },
        { id: "shape", label: qsTr("Shape & Spacing"), icon: "rounded_corner" },
        { id: "motion", label: qsTr("Motion"), icon: "animation" },
        { id: "wallpapers", label: qsTr("Wallpapers"), icon: "wallpaper" },
        { id: "lockscreen", label: qsTr("Lockscreen"), icon: "lock" }
    ]
}
