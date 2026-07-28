pragma ComponentBehavior: Bound

import QtQuick
import "../../../controlcenter"
import "../../../controlcenter/appearance" as CoreAppearance

Item {
    id: root

    required property Session session

    anchors.fill: parent

    CoreAppearance.AppearancePane {
        anchors.fill: parent
        session: root.session
    }
}
