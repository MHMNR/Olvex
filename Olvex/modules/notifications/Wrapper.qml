import QtQuick
import qs.components

Item {
    id: root

    required property DrawerVisibilities visibilities
    property alias flyoutsPanel: content.flyoutsPanel
    property alias powermenuPanel: content.powermenuPanel

    visible: height > 0
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Content {
        id: content

        visibilities: root.visibilities
    }
}
