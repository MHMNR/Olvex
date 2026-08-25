pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool locked: false
    property bool unlocking: false
}
