pragma ComponentBehavior: Bound

import QtQuick
import "../../../settings"
import "../../../settings/bar" as CoreBar

Item {
    id: root

    required property Session session

    anchors.fill: parent

    CoreBar.BarPage {
        anchors.fill: parent
        session: root.session
    }
}
