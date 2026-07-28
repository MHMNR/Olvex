import "./dash"
import QtQuick
import qs.components

Item {
    implicitWidth: content.implicitWidth > 800 ? content.implicitWidth : 840
    implicitHeight: content.implicitHeight

    WeatherContent {
        id: content

        anchors.fill: parent
    }
}