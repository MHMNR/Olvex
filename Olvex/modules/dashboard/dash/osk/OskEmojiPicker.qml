import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import Olvex.Services
import Olvex.Config
import "emojis.js" as EmojiData

Item {
    id: root
    objectName: "emojiPicker" // For parent to find
    
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
    property var recentEmojis: []
    
    property string searchText: ""

    function isToneable(emoji) {
        if (!emoji) return false;
        // Comprehensive regex for all toneable emojis up to Unicode 16.0
        const toneable = /[\u{1F442}-\u{1F44B}\u{1F44E}-\u{1F450}\u{1F466}-\u{1F469}\u{1F46B}-\u{1F46E}\u{1F470}-\u{1F478}\u{1F47C}\u{1F481}-\u{1F483}\u{1F485}-\u{1F487}\u{1F4AA}\u{1F574}\u{1F575}\u{1F590}\u{1F596}\u{1F645}-\u{1F647}\u{1F64B}-\u{1F64F}\u{1F6A3}\u{1F6B4}-\u{1F6B6}\u{1F6C0}\u{1F6CC}\u{1F90C}\u{1F90F}-\u{1F91E}\u{1F926}\u{1F930}-\u{1F939}\u{1F93D}-\u{1F93E}\u{1F9D1}-\u{1F9DD}\u{1FAF0}-\u{1FAF8}]/u;
        return toneable.test(emoji);
    }

    function applySkinTone(emoji) {
        if (!currentSkinTone || !isToneable(emoji)) return emoji;
        // Remove existing tones AND Variation Selector-16 (\u{FE0F}) which breaks tone rendering
        let base = emoji.replace(/[\u{1F3FB}-\u{1F3FF}\u{FE0F}]/ug, "");
        return base + currentSkinTone;
    }

    function updateRecent(emoji) {
        let list = recentEmojis.slice();
        let idx = list.indexOf(emoji);
        if (idx !== -1) list.splice(idx, 1);
        list.unshift(emoji);
        if (list.length > 36) list = list.slice(0, 36);
        recentEmojis = list;
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
        return results.slice(0, 100);
    }

    // Skin Tone Popup
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
                    width: 28
                    height: 28
                    radius: 14
                    color: index === 0 ? "#FFCC22" : ["#F7D2B2", "#D4AC8D", "#BB9167", "#8E562E", "#613D30"][index-1]
                    border.width: root.currentSkinTone === modelData ? 2 : 0
                    border.color: Colours.palette.m3primary
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.currentSkinTone = modelData;
                            tonePopup.visible = false;
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        spacing: 0

        property var flattenedEmojiModel: {
            let all = [];
            for (let i = 0; i < EmojiData.categories.length; i++) {
                let cat = EmojiData.categories[i];
                let list = cat.name === "Recent" ? root.recentEmojis : cat.emojis;
                for (let j = 0; j < list.length; j++) {
                    all.push({ "emoji": list[j], "catIndex": i });
                }
            }
            return all;
        }

        // Main Emoji Scroll (Optimized GridView)
        GridView {
            id: mainScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: !root.searchText
            cellWidth: root.baseWidth
            cellHeight: root.baseHeight
            model: contentCol.flattenedEmojiModel

            onContentYChanged: {
                let idx = indexAt(10, contentY + 10);
                if (idx !== -1 && mainScroll.model[idx]) {
                    let catIdx = mainScroll.model[idx].catIndex;
                    if (bottomBar.activeCategory !== catIdx) {
                        bottomBar.activeCategory = catIdx;
                    }
                }
            }

            delegate: Item {
                width: root.baseWidth
                height: root.baseHeight
                
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 8
                    color: mArea.pressed ? Qt.alpha(Colours.palette.m3onSurface, 0.1) : "transparent"
                }
                
                StyledText {
                    anchors.centerIn: parent
                    text: root.applySkinTone(modelData.emoji)
                    textPixelSize: 32 // Slightly smaller for better fit
                }

                MouseArea {
                    id: mArea
                    anchors.fill: parent
                    onClicked: {
                        let emoji = root.applySkinTone(modelData.emoji);
                        if (root.ydotool) {
                            root.ydotool.typeString(emoji);
                            root.updateRecent(modelData.emoji);
                        }
                    }
                }
            }
        }

        // Search Results View
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !!root.searchText
            
            GridView {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                cellWidth: root.baseWidth
                cellHeight: root.baseHeight
                model: root.searchResults
                
                delegate: Item {
                    width: root.baseWidth
                    height: root.baseHeight
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 8
                        color: sArea.pressed ? Qt.alpha(Colours.palette.m3onSurface, 0.1) : "transparent"
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: root.applySkinTone(modelData)
                        textPixelSize: 42
                    }
                    MouseArea {
                        id: sArea
                        anchors.fill: parent
                        onClicked: {
                            let emoji = root.applySkinTone(modelData);
                            if (root.ydotool) {
                                root.ydotool.typeString(emoji);
                                if (root.wordEngine) root.wordEngine.onChar(emoji);
                                root.updateRecent(modelData);
                            }
                        }
                    }
                }
            }
        }

        // Bottom Bar: Categories + ABC Switch
        RowLayout {
            id: bottomBar
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            Layout.margins: 4
            property int activeCategory: 0

            OskKey {
                baseWidth: root.baseWidth
                baseHeight: 55
                widthMultiplierOverride: 1.5
                keyData: ({ "keytype": "normal", "label": "ABC", "isLayoutSwitch": true, "switchTarget": "Phone" })
                onLayoutSwitchRequested: (target) => root.layoutSwitchRequested(target)
            }
            
            ListView {
                id: catList
                Layout.fillWidth: true
                Layout.preferredHeight: 55
                orientation: ListView.Horizontal
                model: (EmojiData && EmojiData.categories) ? EmojiData.categories : []
                spacing: 4
                clip: true
                
                delegate: Item {
                    width: root.baseWidth
                    height: 55
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 20
                        color: (bottomBar.activeCategory === index) ? Qt.alpha(Colours.palette.m3primary, 0.2) : "transparent"
                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.icon || ""
                            font.family: "Material Symbols Rounded"
                            textPixelSize: 22
                            color: (bottomBar.activeCategory === index) ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.6)
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            bottomBar.activeCategory = index;
                            if (root.searchText) {
                                root.searchText = "";
                            }
                            mainScroll.positionViewAtIndex(index, ListView.Beginning);
                        }
                    }
                }
            }
            
            OskKey {
                baseWidth: root.baseWidth
                baseHeight: 55
                widthMultiplierOverride: 1.5
                keyData: ({ "keytype": "normal", "label": "backspace", "keycode": 14, "isIcon": true })
                wordEngine: root.wordEngine
            }
        }
    }
}
