pragma ComponentBehavior: Bound


import ".."
import "../ui"
import "."
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Olvex.Config
import qs.services

RowLayout {
    id: root

    property Component leftContent: null
    property Component rightContent: null
    property real leftWidthRatio: 0.24
    property int leftMinimumWidth: 220
    property int leftMaximumWidth: 280
    property var leftLoaderProperties: ({})
    property var rightLoaderProperties: ({})
    property alias leftLoader: leftLoader
    property alias rightLoader: rightLoader

    spacing: 0

    Item {
        id: leftPane

        Layout.preferredWidth: Math.floor(parent.width * root.leftWidthRatio)
        Layout.minimumWidth: root.leftMinimumWidth
        Layout.maximumWidth: root.leftMaximumWidth
        Layout.fillHeight: true

        Rectangle {
            id: leftCard
            anchors.fill: parent
            anchors.margins: Tokens.padding.normal
            anchors.leftMargin: Tokens.padding.normal
            anchors.rightMargin: Tokens.padding.small
            radius: Tokens.rounding.large
            color: Colours.palette.m3surfaceContainerHigh


            Loader {
                id: leftLoader
                anchors.fill: parent
                anchors.margins: Tokens.padding.normal
                asynchronous: true
                sourceComponent: root.leftContent

                Component.onCompleted: {
                    for (const key in root.leftLoaderProperties) {
                        leftLoader[key] = root.leftLoaderProperties[key];
                    }
                }
            }
        }
    }

    Item {
        id: rightPane

        Layout.fillWidth: true
        Layout.fillHeight: true

        Rectangle {
            id: rightCard
            anchors.fill: parent
            anchors.margins: Tokens.padding.normal
            anchors.leftMargin: Tokens.padding.small
            anchors.rightMargin: Tokens.padding.normal
            radius: Tokens.rounding.large
            color: Colours.palette.m3surfaceContainerHigh


            Loader {
                id: rightLoader
                anchors.fill: parent
                anchors.margins: Tokens.padding.normal
                asynchronous: true
                sourceComponent: root.rightContent

                Component.onCompleted: {
                    for (const key in root.rightLoaderProperties) {
                        rightLoader[key] = root.rightLoaderProperties[key];
                    }
                }
            }
        }
    }
}
