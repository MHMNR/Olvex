pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.containers
import qs.services

// Drill-in page: sticky header + scroll body, or hostMode for full-bleed panes.
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: "settings"
    property color accent: Colours.palette.m3primary
    property bool hostMode: false

    signal back

    default property alias content: contentCol.data

    // Hosted pane (when hostMode). Assign via hostedItem or reparent child with anchors.
    property alias host: hostContainer

    // Solid page fill — parent morph is also opaque; double-paint blocks any bleed
    // if Loader opacity/clip edges leave a gap during container transform.
    Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3surface
        z: -1
    }

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        z: 2

        RowLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.large
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.large
            spacing: Tokens.spacing.normal

            StyledRect {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconPointSize: Tokens.font.size.larger
                }

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3onSurface
                    onClicked: root.back()
                }
            }

            StyledRect {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: Tokens.rounding.large
                color: Qt.alpha(root.accent, 0.18)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.icon
                    fill: 1
                    color: root.accent
                    iconPointSize: Tokens.font.size.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                // title-large — size carries hierarchy, regular weight (no bold cut)
                StyledText {
                    text: root.title
                    font.weight: Font.Normal
                    font.letterSpacing: -0.2
                    lineHeight: 1.15
                    lineHeightMode: Text.ProportionalHeight
                    color: Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.large
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // body-medium page context
                StyledText {
                    visible: !!root.subtitle
                    text: root.subtitle
                    color: Colours.palette.m3onSurfaceVariant
                    font.weight: Font.Normal
                    font.letterSpacing: 0.1
                    lineHeight: 1.3
                    lineHeightMode: Text.ProportionalHeight
                    textPointSize: Tokens.font.size.smaller
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.5)
            opacity: !root.hostMode && flick.contentY > 4 ? 1 : 0

            Behavior on opacity {
                Anim { type: Anim.FastEffects }
            }
        }
    }

    StyledFlickable {
        id: flick

        visible: !root.hostMode
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        contentWidth: width
        contentHeight: contentCol.implicitHeight + Tokens.padding.large * 2
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: contentCol

            x: Tokens.padding.large * 2
            y: Tokens.padding.large
            width: parent.width - Tokens.padding.large * 4
            spacing: Tokens.spacing.large
        }
    }

    Item {
        id: hostContainer

        visible: root.hostMode
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.normal
        anchors.topMargin: 0
    }
}
