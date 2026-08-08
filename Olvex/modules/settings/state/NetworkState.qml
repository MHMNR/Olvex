import ".."
import "../chrome"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick

QtObject {
    id: root

    property var active: null
    property bool showPasswordDialog: false
    property var pendingNetwork: null
}
