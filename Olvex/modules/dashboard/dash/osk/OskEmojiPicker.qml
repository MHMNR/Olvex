import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services
import Olvex.Services
import Olvex.Config
import "emojis.js" as EmojiData

Item {
    id: root
    

    objectName: "emojiPicker"

    signal hideRequested()
    signal layoutSwitchRequested(string targetLayout)
    property var wordEngine: null



    readonly property var ydotool: typeof Ydotool !== "undefined" ? Ydotool : null
    property real baseWidth: 65
    property real baseHeight: 65

    implicitWidth: 10 * baseWidth
    implicitHeight: 5 * baseHeight

    property string currentSkinTone: ""
    readonly property var skinTones: ["", "🏻", "🏼", "🏽", "🏾", "🏿"]

    // Persistent recent list (flushed from pendingRecents on close)
    property var sessionRecentsContext: null
    property var openSnapshot: []
    property var pendingRecents: []
    property string searchText: ""

    onSessionRecentsContextChanged: {
        if (sessionRecentsContext) {
            let loadedRecents = sessionRecentsContext.sessionRecentEmojis || [];
            openSnapshot = loadedRecents.slice();
            pendingRecents = loadedRecents.slice();
        }
    }

    function isToneable(emoji) {
        if (!emoji) return false;
        const toneable = /[\u{1F442}-\u{1F44B}\u{1F44E}-\u{1F450}\u{1F466}-\u{1F469}\u{1F46B}-\u{1F46E}\u{1F470}-\u{1F478}\u{1F47C}\u{1F481}-\u{1F483}\u{1F485}-\u{1F487}\u{1F4AA}\u{1F574}\u{1F575}\u{1F590}\u{1F596}\u{1F645}-\u{1F647}\u{1F64B}-\u{1F64F}\u{1F6A3}\u{1F6B4}-\u{1F6B6}\u{1F6C0}\u{1F6CC}\u{1F90C}\u{1F90F}-\u{1F91E}\u{1F926}\u{1F930}-\u{1F939}\u{1F93D}-\u{1F93E}\u{1F9D1}-\u{1F9DD}\u{1FAF0}-\u{1FAF8}]/u;
        return toneable.test(emoji);
    }

    function applySkinTone(emoji) {
        if (!currentSkinTone || !isToneable(emoji)) return emoji;
        let base = emoji.replace(/[\u{1F3FB}-\u{1F3FF}\u{FE0F}]/ug, "");
        return base + currentSkinTone;
    }

    function queueRecent(emoji) {
        let list = pendingRecents.slice();
        let idx = list.indexOf(emoji);
        if (idx !== -1) list.splice(idx, 1);
        list.unshift(emoji);
        if (list.length > 36) list = list.slice(0, 36);
        pendingRecents = list;
        if (sessionRecentsContext) {
            sessionRecentsContext.sessionRecentEmojis = list;
        }
    }

    function typeEmoji(emojiText, baseEmoji) {
        if (!emojiText) return;
        Quickshell.execDetached(["wtype", emojiText]);
        if (root.wordEngine && typeof root.wordEngine.onChar === "function") {
            root.wordEngine.onChar(emojiText);
        }
        if (baseEmoji) {
            root.queueRecent(baseEmoji);
        }
    }

    // Build row-based model: [{type:"header",name,icon,catIdx} | {type:"row",emojis:[],catIdx}]
    property var rowModel: {
        const COLS = 10;
        let rows = [];
        let cats = (typeof EmojiData !== "undefined" && EmojiData.categories) ? EmojiData.categories : [{"name": "Error", "emojis": ["❌"]}];
        for (let i = 0; i < cats.length; i++) {
            let cat = cats[i];
            let list = (cat.name === "Recent") ? root.openSnapshot : cat.emojis;
            if (list.length === 0 && cat.name === "Recent") continue;
            rows.push({ type: "header", name: cat.name, icon: cat.icon || "", catIdx: i });
            for (let j = 0; j < list.length; j += COLS) {
                rows.push({ type: "row", emojis: list.slice(j, j + COLS), catIdx: i });
            }
        }
        return rows;
    }

    property var searchResults: {
        if (!searchText) return [];
        let results = [];
        let query = searchText.toLowerCase();
        for (let i = 0; i < EmojiData.categories.length; i++) {
            let cat = EmojiData.categories[i];
            if (cat.name === "Recent") continue;
            if (cat.name.toLowerCase().indexOf(query) !== -1 || query.length > 1) {
                results = results.concat(cat.emojis);
            }
        }
        return results.slice(0, 140);
    }

    // Returns index of first row for catIdx
    function firstRowForCat(catIdx) {
        for (let i = 0; i < rowModel.length; i++) {
            if (rowModel[i].catIdx === catIdx) return i;
        }
        return 0;
    }

    // Skin tone popup
    Rectangle {
        id: tonePopup
        visible: false
        z: 100
        width: 230
        height: 48
        color: Colours.tPalette.m3surfaceContainer || "#222222"
        radius: 24
        border.color: Colours.palette.m3primary
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            Repeater {
                model: root.skinTones
                delegate: Rectangle {
                    width: 28; height: 28; radius: 14
                    color: index === 0 ? "#FFCC22" : ["#F7D2B2","#D4AC8D","#BB9167","#8E562E","#613D30"][index-1]
                    border.width: root.currentSkinTone === modelData ? 2 : 0
                    border.color: Colours.palette.m3primary
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.currentSkinTone = modelData; tonePopup.visible = false; }
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        spacing: 0

        // ── Main emoji list (vertically scrolling, section headers) ─────────
        ListView {
            id: mainList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: !root.searchText
            model: root.rowModel
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds

            // Sync active category tab while scrolling
            onContentYChanged: {
                let idx = indexAt(10, contentY + 10);
                if (idx >= 0 && idx < root.rowModel.length) {
                    bottomBar.activeCategory = root.rowModel[idx].catIdx;
                }
            }

            delegate: unifiedDelegate
        }

        // ── Search results (7-per-row grid reuse) ────────────────────────
        ListView {
            id: searchList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !!root.searchText
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: {
                // chunk into rows of 10
                const COLS = 10;
                let chunks = [];
                let sr = root.searchResults;
                for (let i = 0; i < sr.length; i += COLS) {
                    chunks.push({ type: "row", emojis: sr.slice(i, i + COLS), catIdx: -1 });
                }
                return chunks;
            }
            delegate: unifiedDelegate
        }

        // ── Bottom bar: ABC | category tabs | backspace ──────────────────
        RowLayout {
            id: bottomBar
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 0

            property int activeCategory: 0

            OskKey {
                baseWidth: root.baseWidth
                baseHeight: 50
                widthMultiplierOverride: 1.5
                keyData: ({ keytype: "normal", label: "ABC", isLayoutSwitch: true, switchTarget: "Phone" })
                onLayoutSwitchRequested: (t) => root.layoutSwitchRequested(t)
            }

            // Category icon tabs
            ListView {
                id: catTabs
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                orientation: ListView.Horizontal
                model: EmojiData.categories
                spacing: 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: true

                WheelHandler {
                    onWheel: (event) => {
                        let step = event.angleDelta.y;
                        if (step === 0) step = event.angleDelta.x;
                        let maxX = Math.max(0, catTabs.contentWidth - catTabs.width);
                        catTabs.contentX = Math.max(0, Math.min(catTabs.contentX - step, maxX));
                    }
                }

                delegate: Item {
                    width: root.baseWidth - 4
                    height: 50

                    readonly property bool isActive: bottomBar.activeCategory === index

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 10
                        color: parent.isActive ? Qt.alpha(Colours.palette.m3primary, 0.15) : "transparent"

                        Behavior on color { ColorAnimation { duration: 120 } }

                        StyledText {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -3
                            text: modelData.icon || ""
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 20
                            color: parent.parent.isActive
                                ? Colours.palette.m3primary
                                : Qt.alpha(Colours.palette.m3onSurface, 0.55)
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        // Active underline indicator (Gboard style)
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.parent.isActive ? 16 : 0
                            height: 2
                            radius: 1
                            color: Colours.palette.m3primary
                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            bottomBar.activeCategory = index;
                            root.searchText = "";
                            let rowIdx = root.firstRowForCat(index);
                            mainList.positionViewAtIndex(rowIdx, ListView.Beginning);
                        }
                    }
                }
            }

            OskKey {
                baseWidth: root.baseWidth
                baseHeight: 50
                widthMultiplierOverride: 1.5
                keyData: ({ keytype: "normal", label: "backspace", keycode: 14, isIcon: true })
                wordEngine: root.wordEngine
            }
        }
    }

    // Unified Delegate avoiding Loader context issues
    Component {
        id: unifiedDelegate
        Item {
            width: ListView.view ? ListView.view.width : root.width
            height: modelData.type === "header" ? 28 : root.baseHeight

            // Header part
            Item {
                anchors.centerIn: parent
                width: 10 * root.baseWidth
                height: 28
                visible: modelData.type === "header"

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    text: modelData.name || ""
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.5)
                    font.letterSpacing: 0.5
                }
            }

            // Row part
            Item {
                anchors.centerIn: parent
                width: 10 * root.baseWidth
                height: root.baseHeight
                visible: modelData.type === "row"

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                Repeater {
                    model: modelData.type === "row" ? modelData.emojis : null
                    delegate: Item {
                        width: root.baseWidth
                        height: root.baseHeight

                        property string emojiStr: modelData
                        property string emojiDisplayed: root.applySkinTone(emojiStr)

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 8
                            color: emojiArea.pressed ? Qt.alpha(Colours.palette.m3onSurface, 0.1) : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: parent.emojiDisplayed
                            font.pixelSize: 30
                        }

                        MouseArea {
                            id: emojiArea
                            anchors.fill: parent
                            pressAndHoldInterval: 350

                            onClicked: {
                                root.typeEmoji(parent.emojiDisplayed, parent.emojiStr);
                            }

                            onPressAndHold: {
                                if (root.isToneable(parent.emojiStr)) {
                                    tonePopup.x = Math.min(
                                        Math.max(0, parent.mapToItem(root, 0, 0).x - 80),
                                        root.width - tonePopup.width - 8
                                    );
                                    tonePopup.y = parent.mapToItem(root, 0, 0).y - tonePopup.height - 4;
                                    tonePopup.visible = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
}
