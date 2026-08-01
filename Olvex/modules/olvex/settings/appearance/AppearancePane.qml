pragma ComponentBehavior: Bound

import QtQuick
import "../../../settings"
import "../../../settings/appearance" as CoreAppearance

Item {
    id: root

    required property Session session

    anchors.fill: parent

    CoreAppearance.AppearancePage {
        anchors.fill: parent
        session: root.session
    }
}
