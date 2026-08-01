pragma ComponentBehavior: Bound

import QtQuick
import "../../../controlcenter"
import "../../../controlcenter/sound" as CoreSound

Item {
    id: root

    required property Session session

    anchors.fill: parent

    CoreSound.SoundPage {
        anchors.fill: parent
        session: root.session
    }
}
