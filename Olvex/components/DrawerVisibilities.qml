import Quickshell
import QtQml

QtObject {
    id: root

    // Transient drawer states (never saved to disk)
    property bool bar: true
    property bool flyouts: false
    property bool powermenu: false
    property bool launcher: false
    property bool wallpaperLauncher: false
    property bool dashboard: false
    property bool qspanel: false
    property bool notificationcenter: false
    property bool bottomPanel: false
    property bool clipboard: false
    property bool osk: false

    // Persistent properties (saved to disk)
    property alias isOskDocked: persistent.isOskDocked
    property alias launcherSearchText: persistent.launcherSearchText
    property alias pinnedApps: persistent.pinnedApps
    property alias pinnedAppsLandingAppId: persistent.pinnedAppsLandingAppId

    property PersistentProperties _persistent: PersistentProperties {
        id: persistent
        property bool isOskDocked: false
        property string launcherSearchText
        property list<string> pinnedApps
        property string pinnedAppsLandingAppId: ""
    }
}
