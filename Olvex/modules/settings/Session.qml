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
    property string activeSection: ""
    property string query: ""
    property rect srcRect: Qt.rect(0, 0, 0, 0)
    property bool modalActive: false
    signal requestCloseModal()

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

    // Android-style Search Deep Link Highlight Flash
    property string highlightKey: ""
    property string highlightSection: ""
    property string highlightPage: ""
    property string highlightQuery: ""
    property string highlightTitle: ""
    property string highlightId: ""
    property real highlightTimestamp: 0

    function flashSection(key, section, page, query, title, id) {
        highlightKey = key || "";
        highlightSection = section || "";
        highlightPage = page || "";
        highlightQuery = query || "";
        highlightTitle = title || "";
        highlightId = id || "";
        highlightTimestamp = Date.now();
        // Also write to the PaneRegistry singleton so SettingRow and Section components
        // that are deep inside Loaders can react without tree traversal.
        PaneRegistry.flashHighlight(key, section, page, query, title, id);
    }

    function open(id) {
        pageId = id;
        currentId = id;
    }

    function openPageAndSection(page, section, targetKey, query, title, id) {
        activeSection = section || "";
        flashSection(targetKey || section, section, page, query, title, id);
        open(page);
    }

    function openPageAndSectionFrom(item, page, section, stackItem, targetKey, query, title, id) {
        activeSection = section || "";
        flashSection(targetKey || section, section, page, query, title, id);
        openFrom(item, page, stackItem);
    }

    function openFrom(item, id, stackItem) {
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

    function goHome() {
        // Collapse first; pageId cleared when transformProgress hits 0
        currentId = "";
    }

    function matches(cat) {
        if (query === "")
            return true;
        const q = query.toLowerCase();
        return cat.title.toLowerCase().includes(q) || cat.sub.toLowerCase().includes(q) || cat.id.includes(q) || cat.label.toLowerCase().includes(q);
    }
}
