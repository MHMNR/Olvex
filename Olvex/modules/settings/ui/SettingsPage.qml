

import ".."
import "."
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
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

    // Hosted pane (when hostMode). Assign via hostComponent.
    property Component hostComponent: null
    property alias host: hostContainer

    // Transparent page fill so root window m3surface+alpha and Hyprland blur show through
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        z: -1
    }

    onVisibleChanged: {
        if (visible)
            flick.contentY = 0;
    }

    StyledFlickable {
        id: flick

        visible: !root.hostMode
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        contentWidth: width
        contentHeight: contentCol.implicitHeight + Tokens.padding.large * 2
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: contentCol

            x: Tokens.padding.large * 2
            y: Tokens.padding.large
            width: parent.width - Tokens.padding.large * 4
            spacing: Tokens.spacing.large

            opacity: 0.0
            transform: Translate { id: contentTrans; y: 20 }

            Component.onCompleted: {
                revealAnim.start();
            }

            ParallelAnimation {
                id: revealAnim
                NumberAnimation { target: contentCol; property: "opacity"; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
                NumberAnimation { target: contentTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutCubic }
            }
        }
    }

    Item {
        id: hostContainer

        visible: root.hostMode
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 0

        Loader {
            anchors.fill: parent
            sourceComponent: root.hostComponent
        }
    }
}
