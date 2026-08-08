
import QtQuick
import "../../../settings"
import "../../../settings/sound" as CoreSound

Item {
    id: root

    required property Session session

    anchors.fill: parent

    CoreSound.SoundPage {
        anchors.fill: parent
        session: root.session
    }
}
