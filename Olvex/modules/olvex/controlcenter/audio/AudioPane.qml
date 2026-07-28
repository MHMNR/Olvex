pragma ComponentBehavior: Bound

import QtQuick
import "../../../controlcenter"
import "../../../controlcenter/audio" as CoreAudio

Item {
    id: root

    required property Session session

    anchors.fill: parent

    CoreAudio.AudioPane {
        anchors.fill: parent
        session: root.session
    }
}
