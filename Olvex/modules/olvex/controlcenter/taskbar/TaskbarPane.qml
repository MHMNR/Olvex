pragma ComponentBehavior: Bound

import QtQuick
import "../../../controlcenter"
import "../../../controlcenter/taskbar" as CoreTaskbar

Item {
    id: root

    required property Session session

    anchors.fill: parent

    CoreTaskbar.TaskbarPane {
        anchors.fill: parent
        session: root.session
    }
}
