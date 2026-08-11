pragma ComponentBehavior: Bound


import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

Item {
    id: root

    property string activeSection: "theme"
    signal sectionSelected(string section)

    readonly property var sections: [
        { id: "theme", label: qsTr("Theme"), icon: "contrast" },
        { id: "transparency", label: qsTr("Transparency"), icon: "opacity" },
        { id: "fonts", label: qsTr("Fonts"), icon: "font_download" },
        { id: "shape", label: qsTr("Shape & Spacing"), icon: "rounded_corner" },
        { id: "motion", label: qsTr("Motion"), icon: "animation" },
        { id: "wallpapers", label: qsTr("Wallpapers"), icon: "wallpaper" },
        { id: "lockscreen", label: qsTr("Lockscreen"), icon: "lock" }
    ]

    
    StyledRect {
        id: highlightRect
        x: colLayout.x + Tokens.padding.small
        width: colLayout.width - (Tokens.padding.small * 2)
        height: 40
        radius: height / 2
        color: Colours.palette.m3primary
        
        Behavior on y {
            Anim { type: Anim.FastSpatial }
        }
    }

    ColumnLayout {
        id: colLayout
        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: root.sections

            delegate: Item {
                id: delegateRoot
                Layout.fillWidth: true
                implicitHeight: 40

                required property var modelData

                readonly property bool isActive: root.activeSection === delegateRoot.modelData.id

                onIsActiveChanged: {
                    if (isActive) {
                        highlightRect.y = Qt.binding(() => colLayout.y + delegateRoot.y);
                    }
                }
                Component.onCompleted: {
                    if (isActive) {
                        highlightRect.y = Qt.binding(() => colLayout.y + delegateRoot.y);
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.large
                    anchors.rightMargin: Tokens.padding.large
                    spacing: Tokens.spacing.normal

                    MaterialIcon {
                        text: delegateRoot.modelData.icon
                        color: delegateRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        iconPointSize: Tokens.font.size.normal
                        Behavior on color { CAnim {} }
                    }

                    StyledText {
                        text: delegateRoot.modelData.label
                        color: delegateRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        font.weight: delegateRoot.isActive ? Font.Medium : Font.Normal
                        textPointSize: Tokens.font.size.normal
                        Layout.fillWidth: true
                        Behavior on color { CAnim {} }
                    }
                }
                StyledRect {
                    anchors.fill: parent
                    radius: height / 2
                    color: Colours.palette.m3onSurface
                    opacity: segMa.pressed ? 0.1 : (segMa.containsMouse && !delegateRoot.isActive ? 0.08 : 0)

                    Behavior on opacity {
                        Anim { type: Anim.FastEffects }
                    }
                }

                MouseArea {
                    id: segMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sectionSelected(delegateRoot.modelData.id)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
