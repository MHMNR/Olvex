import "../../components"
import "../../components/controls"
import "../../components/containers"
import "./state"
import QtQuick
import qs.modules.settings

QtObject {
    id: sessionObj

    required property var rootItem

    // Legacy rail aliases (kept for deep-link / older callers)
    property bool floating: false
    property string active: ""
    property int activeIndex: 0
    property bool navExpanded: false

    // Bento navigation
    property string currentId: "" // "" → home
    property string pageId: ""
    property string query: ""
    property rect srcRect: Qt.rect(0, 0, 0, 0)

    readonly property var panes: PaneRegistry.labels

    readonly property BluetoothState bt: BluetoothState {}
    readonly property NetworkState network: NetworkState {}
    readonly property EthernetState ethernet: EthernetState {}
    readonly property LauncherState launcher: LauncherState {}
    readonly property VpnState vpn: VpnState {}

    // Alias used by SettingsWindow / NavRail: session.root
    readonly property var root: rootItem

    // Top-level floating overlays (set by SettingsWindow.onCompleted)
    property var wifiConfigMenu: null

    property bool _syncingActive: false

    onActiveChanged: {
        if (_syncingActive)
            return;
        if (active && active !== currentId) {
            const cat = PaneRegistry.getById(active) || PaneRegistry.getByLabel(active);
            if (cat)
                open(cat.id);
        }
    }

    onCurrentIdChanged: {
        if (currentId !== "") {
            pageId = currentId;
            _syncingActive = true;
            active = currentId;
            activeIndex = Math.max(0, panes.indexOf(currentId));
            _syncingActive = false;
        }
    }

    function open(id: string): void {
        pageId = id;
        currentId = id;
    }

    function openFrom(item, id: string, stackItem): void {
        if (!item || !stackItem) {
            open(id);
            return;
        }
        // 1) freeze start bounds  2) morph on @ card rect  3) expand same JS turn
        // All before next paint → no dead frames. Never callLater.
        const p = item.mapToItem(stackItem, 0, 0);
        srcRect = Qt.rect(p.x, p.y, item.width, item.height);
        pageId = id;
        currentId = id;
    }

    function goHome(): void {
        // Collapse first; pageId cleared when transformProgress hits 0
        currentId = "";
    }

    function matches(cat): bool {
        if (query === "")
            return true;
        const q = query.toLowerCase();
        return cat.title.toLowerCase().includes(q) || cat.sub.toLowerCase().includes(q) || cat.id.includes(q) || cat.label.toLowerCase().includes(q);
    }
}
