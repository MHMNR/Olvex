import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

// Selectable card. Children declared inside become the preview area.
StyledRect {
    id: root

    property string title
    property string description
    property string icon
    property bool selected: false
    property real previewHeight: 84

    default property alias preview: previewHolder.data

    signal clicked

    implicitHeight: col.implicitHeight + 28
    radius: 16
    color: selected ? Qt.alpha(Colours.palette.m3primary, 0.14) : Colours.layer(Colours.palette.m3surfaceContainer, 2)
    border.width: 0
    border.color: "transparent"
    scale: layer.pressed ? 0.985 : 1.0

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on border.color {
        CAnim {}
    }

    ColumnLayout {
        id: col

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 10

        Item {
            id: previewHolder

            Layout.fillWidth: true
            Layout.preferredHeight: root.previewHeight
            visible: root.previewHeight > 0
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialIcon {
                visible: !!root.icon
                text: root.icon
                iconPointSize: 20
                color: root.selected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.weight: Font.DemiBold
                textPointSize: Tokens.font.size.normal
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            MaterialIcon {
                text: "check_circle"
                fill: 1
                iconPointSize: 20
                color: Colours.palette.m3primary
                opacity: root.selected ? 1 : 0
                scale: root.selected ? 1 : 0.5

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }
                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: !!root.description
            text: root.description
            wrapMode: Text.WordWrap
            textPointSize: Tokens.font.size.smaller
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    StateLayer {
        id: layer

        anchors.fill: parent
        radius: root.radius
        color: Colours.palette.m3onSurface
        onClicked: root.clicked()
    }
}

