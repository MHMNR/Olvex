import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.components.effects
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

    // Unicode Emoji_Modifier_Base pattern (UTS #51)
    readonly property var baseModifierPatternStr: "[\\u{261D}\\u{26F9}\\u{270A}-\\u{270D}\\u{1F385}\\u{1F3C2}-\\u{1F3C4}\\u{1F3C7}\\u{1F3CA}-\\u{1F3CC}\\u{1F442}\\u{1F443}\\u{1F446}-\\u{1F450}\\u{1F466}-\\u{1F469}\\u{1F46E}\\u{1F470}-\\u{1F478}\\u{1F47C}\\u{1F481}-\\u{1F483}\\u{1F485}-\\u{1F487}\\u{1F48F}\\u{1F491}\\u{1F4AA}\\u{1F574}\\u{1F575}\\u{1F57A}\\u{1F590}\\u{1F595}\\u{1F596}\\u{1F645}-\\u{1F647}\\u{1F64B}-\\u{1F64F}\\u{1F6A3}\\u{1F6B4}-\\u{1F6B6}\\u{1F6C0}\\u{1F6CC}\\u{1F90C}\\u{1F90F}\\u{1F918}-\\u{1F91F}\\u{1F926}\\u{1F930}-\\u{1F939}\\u{1F93D}\\u{1F93E}\\u{1F977}\\u{1F9B5}\\u{1F9B6}\\u{1F9B8}\\u{1F9B9}\\u{1F9BB}\\u{1F9CD}-\\u{1F9CF}\\u{1F9D1}-\\u{1F9DD}\\u{1FAC3}-\\u{1FAC5}\\u{1FAF0}-\\u{1FAF8}]"
    readonly property var modifierPatternStr: "(\\u200D\\u{1F91D}(?:\\uFE0F)?\\u200D)|((" + baseModifierPatternStr + ")(?:\\uFE0F)?)"
    readonly property var modifierRegex: new RegExp(baseModifierPatternStr, "u")
    readonly property var modifierGlobalRegex: new RegExp(modifierPatternStr, "ug")
    readonly property var familyExcludeRegex: /(?:👨‍👩|👨‍👨|👩‍👩|🧑‍🧑|👨‍👦|👨‍👧|👩‍👦|👩‍👧|🧑‍🧒|👪|👤|👥|🫂|🗣️)/

    function isToneable(emoji) {
        if (!emoji || familyExcludeRegex.test(emoji)) return false;
        return modifierRegex.test(emoji);
    }

    function applySkinTone(emoji) {
        if (!emoji) return "";
        let clean = emoji.replace(/[\u{1F3FB}-\u{1F3FF}]/ug, "");
        if (!currentSkinTone || familyExcludeRegex.test(clean) || !modifierRegex.test(clean)) {
            return clean;
        }
        return clean.replace(modifierGlobalRegex, function(match, zwjHandshake, personWithFe0f, personBase) {
            if (zwjHandshake) return zwjHandshake;
            return personBase + currentSkinTone;
        });
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
        Quickshell.execDetached(["sh", "-c", "if command -v wtype >/dev/null; then wtype \"$1\"; else notify-send 'Missing Dependency' 'Please install wtype to type emojis.'; fi", "--", emojiText]);
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
        let query = searchText.toLowerCase().trim();
        let keywords = (typeof EmojiData !== "undefined" && EmojiData.emojiKeywords) ? EmojiData.emojiKeywords : {};
        let cats = (typeof EmojiData !== "undefined" && EmojiData.categories) ? EmojiData.categories : [];
        for (let i = 0; i < cats.length; i++) {
            let cat = cats[i];
            if (cat.name === "Recent") continue;
            let catMatches = cat.name.toLowerCase().indexOf(query) !== -1;
            for (let j = 0; j < cat.emojis.length; j++) {
                let em = cat.emojis[j];
                let name = (keywords[em] || "").toLowerCase();
                if (catMatches || name.indexOf(query) !== -1) {
                    results.push(em);
                }
            }
        }
        return results.slice(0, 160);
    }

    // Returns index of first row for catIdx
    function firstRowForCat(catIdx) {
        for (let i = 0; i < rowModel.length; i++) {
            if (rowModel[i].catIdx === catIdx) return i;
        }
        return 0;
    }

    // Returns exact Y coordinate for first row of catIdx for smooth category navigation
    function yPositionForCat(catIdx) {
        let y = 0;
        for (let i = 0; i < rowModel.length; i++) {
            let row = rowModel[i];
            if (row.catIdx === catIdx) return y;
            y += (row.type === "header" ? 28 : root.baseHeight);
        }
        return 0;
    }

    // Exact height of all items in rowModel, preventing Qt ListView uninstantiated estimate errors and bottom void space
    readonly property real exactContentHeight: {
        let total = 0;
        let m = root.rowModel;
        for (let i = 0; i < m.length; i++) {
            total += (m[i].type === "header" ? 28 : root.baseHeight);
        }
        return total;
    }

    // Backdrop to dismiss on outside click and block scrolling/interactions
    MouseArea {
        id: popupBackdrop
        anchors.fill: parent
        z: 90
        visible: tonePopup.visible
        enabled: tonePopup.visible
        preventStealing: true
        hoverEnabled: true
        onClicked: tonePopup.visible = false
        onWheel: (wheel) => { wheel.accepted = true; }
    }

    // Skin tone popup
    Item {
        id: tonePopup
        visible: false
        z: 100
        width: 240
        height: 48

        // Solid container
        StyledRect {
            id: popupBg
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(Colours.palette.m3surfaceContainerHigh.r, Colours.palette.m3surfaceContainerHigh.g, Colours.palette.m3surfaceContainerHigh.b, 1.0)
            border.width: 0

            Elevation {
                anchors.fill: parent
                level: 3
                z: -1
                radius: parent.radius
            }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: root.skinTones
                    delegate: Item {
                        width: 32
                        height: 32

                        readonly property bool isSelected: root.currentSkinTone === modelData
                        readonly property color toneColor: index === 0 ? "#FFD43F" : ["#FADCBC", "#E0BB95", "#BF8F68", "#9B643D", "#5A3825"][index - 1]

                        // Selection indicator background (no border)
                        Rectangle {
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            radius: 16
                            color: isSelected ? Qt.alpha(Colours.palette.m3primary, 0.2) : "transparent"
                            border.width: 0
                            scale: isSelected ? 1.0 : 0.8
                            opacity: isSelected ? 1.0 : 0.0

                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        // Swatch circle
                        Rectangle {
                            id: swatchCircle
                            anchors.centerIn: parent
                            width: isSelected ? 22 : 26
                            height: isSelected ? 22 : 26
                            radius: width / 2
                            color: toneColor
                            border.width: 0

                            scale: swatchArea.pressed ? 0.9 : (swatchArea.containsMouse ? 1.08 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: swatchArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentSkinTone = modelData;
                                tonePopup.visible = false;
                            }
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
            flickDeceleration: 2500
            maximumFlickVelocity: 3000
            cacheBuffer: 500
            interactive: !tonePopup.visible

            NumberAnimation {
                id: mainSmoothScrollAnim
                target: mainList
                property: "contentY"
                duration: 280
                easing.type: Easing.OutCubic
            }

            onMovementStarted: mainSmoothScrollAnim.stop()
            onFlickStarted: mainSmoothScrollAnim.stop()

            function clampScrollY(y) {
                let maxScroll = Math.max(0, root.exactContentHeight - mainList.height);
                return Math.max(0, Math.min(maxScroll, y));
            }

            function applyScrollDelta(deltaPx, animMs) {
                let base = mainSmoothScrollAnim.running ? mainSmoothScrollAnim.to : mainList.contentY;
                let targetY = clampScrollY(base + deltaPx);
                if (Math.abs(targetY - mainList.contentY) < 0.5 && !mainSmoothScrollAnim.running)
                    return;
                mainSmoothScrollAnim.stop();
                mainSmoothScrollAnim.duration = animMs || 280;
                mainSmoothScrollAnim.from = mainList.contentY;
                mainSmoothScrollAnim.to = targetY;
                mainSmoothScrollAnim.start();
            }

            function scrollToY(targetY, animMs) {
                let clamped = clampScrollY(targetY);
                mainSmoothScrollAnim.stop();
                mainSmoothScrollAnim.duration = animMs || 320;
                mainSmoothScrollAnim.from = mainList.contentY;
                mainSmoothScrollAnim.to = clamped;
                mainSmoothScrollAnim.start();
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    let isTouchPad = event.device && event.device.type === PointerDevice.TouchPad;
                    if (isTouchPad && event.pixelDelta.y !== 0) {
                        mainList.applyScrollDelta(-event.pixelDelta.y, 120);
                        event.accepted = true;
                        return;
                    }
                    let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    if (delta === 0) return;
                    let notchPx = -(delta / 120) * 140;
                    mainList.applyScrollDelta(notchPx, isTouchPad ? 120 : 280);
                    event.accepted = true;
                }
            }

            // Sync active category tab while scrolling & prevent overscroll void space
            onContentYChanged: {
                let maxScroll = Math.max(0, root.exactContentHeight - height);
                if (contentY > maxScroll + 0.5) {
                    contentY = maxScroll;
                } else if (contentY < -0.5) {
                    contentY = 0;
                }
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
            flickDeceleration: 2500
            maximumFlickVelocity: 3000
            cacheBuffer: 500
            interactive: !tonePopup.visible

            readonly property real exactContentHeight: (searchList.model ? searchList.model.length : 0) * root.baseHeight

            NumberAnimation {
                id: searchSmoothScrollAnim
                target: searchList
                property: "contentY"
                duration: 280
                easing.type: Easing.OutCubic
            }

            onMovementStarted: searchSmoothScrollAnim.stop()
            onFlickStarted: searchSmoothScrollAnim.stop()

            function clampScrollY(y) {
                let maxScroll = Math.max(0, searchList.exactContentHeight - searchList.height);
                return Math.max(0, Math.min(maxScroll, y));
            }

            function applyScrollDelta(deltaPx, animMs) {
                let base = searchSmoothScrollAnim.running ? searchSmoothScrollAnim.to : searchList.contentY;
                let targetY = clampScrollY(base + deltaPx);
                if (Math.abs(targetY - searchList.contentY) < 0.5 && !searchSmoothScrollAnim.running)
                    return;
                searchSmoothScrollAnim.stop();
                searchSmoothScrollAnim.duration = animMs || 280;
                searchSmoothScrollAnim.from = searchList.contentY;
                searchSmoothScrollAnim.to = targetY;
                searchSmoothScrollAnim.start();
            }

            onContentYChanged: {
                let maxScroll = Math.max(0, searchList.exactContentHeight - height);
                if (contentY > maxScroll + 0.5) {
                    contentY = maxScroll;
                } else if (contentY < -0.5) {
                    contentY = 0;
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    let isTouchPad = event.device && event.device.type === PointerDevice.TouchPad;
                    if (isTouchPad && event.pixelDelta.y !== 0) {
                        searchList.applyScrollDelta(-event.pixelDelta.y, 120);
                        event.accepted = true;
                        return;
                    }
                    let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    if (delta === 0) return;
                    let notchPx = -(delta / 120) * 140;
                    searchList.applyScrollDelta(notchPx, isTouchPad ? 120 : 280);
                    event.accepted = true;
                }
            }

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

            onActiveCategoryChanged: {
                catTabs.scrollTabIntoView(activeCategory);
            }

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

                NumberAnimation {
                    id: catSmoothScrollAnim
                    target: catTabs
                    property: "contentX"
                    duration: 240
                    easing.type: Easing.OutCubic
                }

                onMovementStarted: catSmoothScrollAnim.stop()
                onFlickStarted: catSmoothScrollAnim.stop()

                function clampScrollX(x) {
                    let maxScroll = Math.max(0, catTabs.contentWidth - catTabs.width);
                    return Math.max(0, Math.min(maxScroll, x));
                }

                function applyScrollDelta(deltaPx, animMs) {
                    let base = catSmoothScrollAnim.running ? catSmoothScrollAnim.to : catTabs.contentX;
                    let targetX = clampScrollX(base + deltaPx);
                    if (Math.abs(targetX - catTabs.contentX) < 0.5 && !catSmoothScrollAnim.running)
                        return;
                    catSmoothScrollAnim.stop();
                    catSmoothScrollAnim.duration = animMs || 240;
                    catSmoothScrollAnim.from = catTabs.contentX;
                    catSmoothScrollAnim.to = targetX;
                    catSmoothScrollAnim.start();
                }

                function scrollToX(targetX, animMs) {
                    let clamped = clampScrollX(targetX);
                    catSmoothScrollAnim.stop();
                    catSmoothScrollAnim.duration = animMs || 250;
                    catSmoothScrollAnim.from = catTabs.contentX;
                    catSmoothScrollAnim.to = clamped;
                    catSmoothScrollAnim.start();
                }

                onContentXChanged: {
                    let maxScroll = Math.max(0, catTabs.contentWidth - width);
                    if (contentX > maxScroll + 0.5) {
                        contentX = maxScroll;
                    } else if (contentX < -0.5) {
                        contentX = 0;
                    }
                }

                function scrollTabIntoView(tabIdx) {
                    let tabWidth = root.baseWidth - 4;
                    let spacing = 2;
                    let tabLeft = tabIdx * (tabWidth + spacing);
                    let tabRight = tabLeft + tabWidth;
                    let currentLeft = catTabs.contentX;
                    let currentRight = currentLeft + catTabs.width;

                    if (tabLeft < currentLeft) {
                        scrollToX(tabLeft - 8, 220);
                    } else if (tabRight > currentRight) {
                        scrollToX(tabRight - catTabs.width + 8, 220);
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    orientation: Qt.Vertical | Qt.Horizontal
                    onWheel: (event) => {
                        let isTouchPad = event.device && event.device.type === PointerDevice.TouchPad;
                        if (isTouchPad && event.pixelDelta.x !== 0) {
                            catTabs.applyScrollDelta(-event.pixelDelta.x, 120);
                            event.accepted = true;
                            return;
                        }
                        let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        if (delta === 0) return;
                        let notchPx = -(delta / 120) * 100;
                        catTabs.applyScrollDelta(notchPx, isTouchPad ? 120 : 240);
                        event.accepted = true;
                    }
                }

                delegate: Item {
                    required property var modelData
                    required property int index

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
                            text: (modelData && modelData.icon) ? modelData.icon : ""
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
                            let targetY = root.yPositionForCat(index);
                            mainList.scrollToY(targetY, 320);
                        }
                        onWheel: (wheel) => {
                            let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                            if (delta !== 0) {
                                let notchPx = -(delta / 120) * 100;
                                catTabs.applyScrollDelta(notchPx, 240);
                            }
                            wheel.accepted = true;
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
            required property var modelData
            required property int index

            width: ListView.view ? ListView.view.width : root.width
            height: (modelData && modelData.type === "header") ? 28 : root.baseHeight

            // Header part
            Item {
                anchors.centerIn: parent
                width: 10 * root.baseWidth
                height: 28
                visible: modelData && modelData.type === "header"

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    text: (modelData && modelData.name) ? modelData.name : ""
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
                visible: modelData && modelData.type === "row"

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Repeater {
                        model: (modelData && modelData.type === "row") ? modelData.emojis : []
                        delegate: Item {
                            required property var modelData
                            required property int index

                            width: root.baseWidth
                            height: root.baseHeight

                            readonly property string emojiStr: modelData || ""
                            readonly property string emojiDisplayed: root.applySkinTone(emojiStr)

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

                                onWheel: (wheel) => {
                                    let isTouchPad = wheel.device && wheel.device.type === PointerDevice.TouchPad;
                                    if (isTouchPad && wheel.pixelDelta.y !== 0) {
                                        if (root.searchText) searchList.applyScrollDelta(-wheel.pixelDelta.y, 120);
                                        else mainList.applyScrollDelta(-wheel.pixelDelta.y, 120);
                                        wheel.accepted = true;
                                        return;
                                    }
                                    let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                                    if (delta !== 0) {
                                        let notchPx = -(delta / 120) * 140;
                                        if (root.searchText) searchList.applyScrollDelta(notchPx, isTouchPad ? 120 : 280);
                                        else mainList.applyScrollDelta(notchPx, isTouchPad ? 120 : 280);
                                    }
                                    wheel.accepted = true;
                                }

                                onPressAndHold: {
                                    if (root.isToneable(parent.emojiStr)) {
                                        let pos = parent.mapToItem(root, 0, 0);
                                        let targetX = pos.x + (parent.width - tonePopup.width) / 2;
                                        tonePopup.x = Math.max(8, Math.min(targetX, root.width - tonePopup.width - 8));
                                        if (pos.y - tonePopup.height - 8 < 0) {
                                            tonePopup.y = pos.y + parent.height + 6;
                                        } else {
                                            tonePopup.y = pos.y - tonePopup.height - 6;
                                        }
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
