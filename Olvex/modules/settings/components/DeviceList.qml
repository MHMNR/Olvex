pragma ComponentBehavior: Bound


import ".."
import "../ui"
import "."
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.services


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
    id: root

    property Session session: null
    property var model: null
    property Component delegate: null

    property string title: ""
    property string description: ""
    property var activeItem: null
    property Component headerComponent: null
    property Component titleSuffix: null
    property bool showHeader: true
    property alias view: view

    signal itemSelected(var item)

    spacing: Tokens.spacing.small

    Loader {
        id: headerLoader

        Layout.fillWidth: true
        asynchronous: true
        sourceComponent: root.headerComponent
        visible: root.headerComponent !== null && root.showHeader
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: root.headerComponent ? 0 : 0
        spacing: Tokens.spacing.small
        visible: root.title !== "" || root.description !== ""

        StyledText {
            visible: root.title !== ""
            text: root.title
            textPointSize: Tokens.font.size.large
            font.weight: 400
        }

        Loader {
            asynchronous: true
            sourceComponent: root.titleSuffix
            visible: root.titleSuffix !== null
        }

        Item {
            Layout.fillWidth: true
        }
    }

    StyledText {
        visible: root.description !== ""
        Layout.fillWidth: true
        text: root.description
        color: Colours.palette.m3outline
    }

    StyledListView {
        id: view

        Layout.fillWidth: true
        implicitHeight: contentHeight

        model: root.model
        delegate: root.delegate

        spacing: Tokens.spacing.small / 2
        interactive: false
        edgeFades: false
        clip: false
    }
}
