import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "emojis.js" as EmojiData

Window {
    id: win

    width: 640
    height: 480
    minimumWidth: 520
    minimumHeight: 380
    visible: true
    title: qsTr("Olvex Emoji")
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowCloseButtonHint
    color: tok.palette.stage

    onVisibleChanged: {
        if (!visible)
            Qt.quit()
    }

    // ── M3 Palette Tokens from SystemAccent ──────────────────────────────
    readonly property QtObject tok: QtObject {
        readonly property QtObject palette: QtObject {
            readonly property color primary: SystemAccent.primary
            readonly property color fgPrimary: SystemAccent.fgPrimary
            readonly property color primaryContainer: SystemAccent.primaryContainer
            readonly property color fgPrimaryContainer: SystemAccent.fgPrimaryContainer
            readonly property color secondaryContainer: SystemAccent.secondaryContainer
            readonly property color fgSecondaryContainer: SystemAccent.fgSecondaryContainer
            readonly property color surface: SystemAccent.surface
            readonly property color fgSurface: SystemAccent.fgSurface
            readonly property color fgMuted: SystemAccent.fgMuted
            readonly property color stage: SystemAccent.stage
            readonly property color stageHigh: SystemAccent.stageHigh
            readonly property color stageContent: SystemAccent.stageContent
            readonly property color outline: SystemAccent.outline
            readonly property color outlineVariant: SystemAccent.outlineVariant
        }
    }

    // ── Skin Tone Configuration & Logic (UTS #51) ────────────────────────
    readonly property var skinTones: ["", "🏻", "🏼", "🏽", "🏾", "🏿"]
    property string currentSkinTone: EmojiBackend.skinTone || ""
    onCurrentSkinToneChanged: {
        if (EmojiBackend.skinTone !== currentSkinTone)
            EmojiBackend.saveSkinTone(currentSkinTone)
    }

    readonly property var baseModifierPatternStr: "[\\u{261D}\\u{26F9}\\u{270A}-\\u{270D}\\u{1F385}\\u{1F3C2}-\\u{1F3C4}\\u{1F3C7}\\u{1F3CA}-\\u{1F3CC}\\u{1F442}\\u{1F443}\\u{1F446}-\\u{1F450}\\u{1F466}-\\u{1F469}\\u{1F46E}\\u{1F470}-\\u{1F478}\\u{1F47C}\\u{1F481}-\\u{1F483}\\u{1F485}-\\u{1F487}\\u{1F48F}\\u{1F491}\\u{1F4AA}\\u{1F574}\\u{1F575}\\u{1F57A}\\u{1F590}\\u{1F595}\\u{1F596}\\u{1F645}-\\u{1F647}\\u{1F64B}-\\u{1F64F}\\u{1F6A3}\\u{1F6B4}-\\u{1F6B6}\\u{1F6C0}\\u{1F6CC}\\u{1F90C}\\u{1F90F}\\u{1F918}-\\u{1F91F}\\u{1F926}\\u{1F930}-\\u{1F939}\\u{1F93D}\\u{1F93E}\\u{1F977}\\u{1F9B5}\\u{1F9B6}\\u{1F9B8}\\u{1F9B9}\\u{1F9BB}\\u{1F9CD}-\\u{1F9CF}\\u{1F9D1}-\\u{1F9DD}\\u{1FAC3}-\\u{1FAC5}\\u{1FAF0}-\\u{1FAF8}]"
    readonly property var modifierPatternStr: "(\\u200D\\u{1F91D}(?:\\uFE0F)?\\u200D)|((" + baseModifierPatternStr + ")(?:\\uFE0F)?)"
    readonly property var modifierRegex: new RegExp(baseModifierPatternStr, "u")
    readonly property var modifierGlobalRegex: new RegExp(modifierPatternStr, "ug")
    readonly property var familyExcludeRegex: /(?:👨‍👩|👨‍👨|👩‍👩|🧑‍🧑|👨‍👦|👨‍👧|👩‍👦|👩‍👧|🧑‍🧒|👪|👤|👥|🫂|🗣️)/

    function isToneable(emoji) {
        if (!emoji || familyExcludeRegex.test(emoji))
            return false
        return modifierRegex.test(emoji)
    }

    function applySkinTone(emoji) {
        if (!emoji)
            return ""
        let clean = emoji.replace(/[\u{1F3FB}-\u{1F3FF}]/ug, "")
        if (!currentSkinTone || familyExcludeRegex.test(clean) || !modifierRegex.test(clean))
            return clean
        return clean.replace(modifierGlobalRegex, function(match, zwjHandshake, personWithFe0f, personBase) {
            if (zwjHandshake)
                return zwjHandshake
            return personBase + currentSkinTone
        })
    }

    // ── Layout Geometry & Metrics ────────────────────────────────────────
    property real baseWidth: 60
    property real baseHeight: 50
    property string searchText: ""

    // ── Row-based Model for Category View ────────────────────────────────
    property var rowModel: {
        const COLS = 10
        let rows = []
        let cats = (EmojiBackend.categories && EmojiBackend.categories.length > 0) 
                   ? EmojiBackend.categories 
                   : ((typeof EmojiData !== "undefined" && EmojiData.categories) ? EmojiData.categories : [])
        for (let i = 0; i < cats.length; i++) {
            let cat = cats[i]
            let list = (cat.name === "Recent") ? EmojiBackend.recentEmojis : cat.emojis
            if (list.length === 0 && cat.name === "Recent")
                continue
            rows.push({ type: "header", name: cat.name, icon: cat.icon || "", catIdx: i })
            for (let j = 0; j < list.length; j += COLS) {
                rows.push({ type: "row", emojis: list.slice(j, j + COLS), catIdx: i })
            }
        }
        return rows
    }

    // ── Search Results Model (Ranked Match) ──────────────────────────────
    property var searchResults: {
        if (!searchText)
            return []
        let query = searchText.toLowerCase().trim()
        if (!query)
            return []
        let keywords = (EmojiBackend.keywords && Object.keys(EmojiBackend.keywords).length > 0) 
                       ? EmojiBackend.keywords 
                       : ((typeof EmojiData !== "undefined" && EmojiData.emojiKeywords) ? EmojiData.emojiKeywords : {})

        let exactWordMatches = []
        let prefixWordMatches = []
        let substringMatches = []
        let seen = {}

        for (let em in keywords) {
            let kw = keywords[em]
            if (!kw)
                continue
            let lowerKw = kw.toLowerCase()
            let words = lowerKw.split(/\s+/)
            let exactWord = false
            let prefixWord = false
            for (let w = 0; w < words.length; w++) {
                if (words[w] === query) {
                    exactWord = true
                    break
                }
                if (words[w].startsWith(query)) {
                    prefixWord = true
                }
            }

            if (exactWord) {
                if (!seen[em]) { seen[em] = true; exactWordMatches.push(em); }
            } else if (prefixWord) {
                if (!seen[em]) { seen[em] = true; prefixWordMatches.push(em); }
            } else if (lowerKw.indexOf(query) !== -1) {
                if (!seen[em]) { seen[em] = true; substringMatches.push(em); }
            }
        }

        let sorted = exactWordMatches.concat(prefixWordMatches).concat(substringMatches)
        return sorted.slice(0, 160)
    }

    function yPositionForCat(catIdx) {
        let y = 0
        for (let i = 0; i < rowModel.length; i++) {
            let row = rowModel[i]
            if (row.catIdx === catIdx)
                return y
            y += (row.type === "header" ? 28 : win.baseHeight)
        }
        return 0
    }

    readonly property real exactContentHeight: {
        let total = 0
        let m = win.rowModel
        for (let i = 0; i < m.length; i++) {
            total += (m[i].type === "header" ? 28 : win.baseHeight)
        }
        return total
    }

    // ── Key Handling ─────────────────────────────────────────────────────
    function handleKey(event) {
        if (!event)
            return
        if (event.key === Qt.Key_Escape) {
            if (tonePopup.isOpen || tonePopup.opacity > 0.01) {
                tonePopup.close()
                event.accepted = true
                return
            }
            if (searchInput.text.length > 0) {
                searchInput.text = ""
                event.accepted = true
                return
            }
            win.close()
            event.accepted = true
            return
        }
    }

    // ── Root Focus & Entrance Animation ──────────────────────────────────
    FocusScope {
        id: rootFocus
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) { win.handleKey(event) }

        Item {
            id: shell
            anchors.fill: parent
            scale: win.shellScale
            opacity: win.shellOpacity
            transformOrigin: Item.Center

            Behavior on scale {
                NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            // ── Main Layout Column ───────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── Top Header: Search Field, Tone Swatch & Close Button ─────
                Item {
                    id: headerContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Layout.topMargin: 8

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        // ── Search Field Container ───────────────────────────
                        Rectangle {
                            id: searchBox
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: 19
                            color: searchInput.activeFocus
                                ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.primary, 0.08))
                                : tok.palette.stageHigh
                            border.width: 0

                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    font.family: "Material Symbols Rounded"
                                    text: "search"
                                    font.pixelSize: 18
                                    color: searchInput.activeFocus ? tok.palette.primary : tok.palette.fgMuted
                                    Layout.alignment: Qt.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    TextInput {
                                        id: searchInput
                                        anchors.fill: parent
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 14
                                        color: tok.palette.fgSurface
                                        selectionColor: Qt.alpha(tok.palette.primary, 0.35)
                                        selectedTextColor: tok.palette.fgSurface
                                        selectByMouse: true
                                        clip: true

                                        onTextChanged: {
                                            win.searchText = text
                                            if (text)
                                                searchList.contentY = 0
                                        }

                                        Keys.onEscapePressed: function(event) {
                                            win.handleKey(event)
                                        }

                                        Component.onCompleted: {
                                            forceActiveFocus()
                                        }
                                    }

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: qsTr("Search emojis…")
                                        font.pixelSize: 14
                                        color: Qt.alpha(tok.palette.fgSurface, 0.4)
                                        visible: searchInput.text.length === 0 && !searchInput.inputMethodComposing
                                    }
                                }

                                // Clear Button
                                Rectangle {
                                    id: clearBtn
                                    visible: searchInput.text.length > 0
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: 13
                                    color: clearBtnMa.pressed ? Qt.alpha(tok.palette.fgSurface, 0.15)
                                         : clearBtnMa.containsMouse ? Qt.alpha(tok.palette.fgSurface, 0.08) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: "Material Symbols Rounded"
                                        text: "close"
                                        font.pixelSize: 14
                                        color: tok.palette.fgMuted
                                    }

                                    MouseArea {
                                        id: clearBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            searchInput.text = ""
                                            searchInput.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }

                        // ── Skin Tone Selector Pill in Header ────────────────
                        Rectangle {
                            id: toneSelectorBtn
                            implicitWidth: 38
                            implicitHeight: 38
                            radius: 19
                            color: toneBtnMa.pressed ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.fgSurface, 0.12))
                                 : toneBtnMa.containsMouse ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.fgSurface, 0.08))
                                 : tok.palette.stageHigh

                            Behavior on color { ColorAnimation { duration: 100 } }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 22
                                height: 22
                                radius: 11
                                color: {
                                    let idx = win.skinTones.indexOf(win.currentSkinTone)
                                    if (idx <= 0) return "#FFD43F"
                                    return ["#FADCBC", "#E0BB95", "#BF8F68", "#9B643D", "#5A3825"][idx - 1]
                                }
                                border.color: Qt.alpha(tok.palette.fgSurface, 0.2)
                                border.width: 1
                            }

                            MouseArea {
                                id: toneBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    tonePopup.toggle(toneSelectorBtn)
                                }
                            }
                        }

                        // ── Rebuild Database Button ──────────────────────────
                        Rectangle {
                            id: rebuildBtn
                            implicitWidth: 38
                            implicitHeight: 38
                            radius: 19
                            color: rebuildBtnMa.pressed ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.fgSurface, 0.12))
                                 : rebuildBtnMa.containsMouse ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.fgSurface, 0.08))
                                 : tok.palette.stageHigh

                            Behavior on color { ColorAnimation { duration: 100 } }
                            clip: true

                            Text {
                                id: rebuildIcon
                                anchors.centerIn: parent
                                font.family: "Material Symbols Rounded"
                                text: EmojiBackend.isUpdating ? "progress_activity" : "refresh"
                                font.pixelSize: 18
                                color: tok.palette.fgSurface
                                transformOrigin: Item.Center
                                
                                RotationAnimation on rotation {
                                    running: EmojiBackend.isUpdating
                                    from: 0; to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                }
                            }

                            MouseArea {
                                id: rebuildBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: EmojiBackend.isUpdating ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: EmojiBackend.rebuildDatabase()
                            }
                        }

                        // ── Close Window Button ──────────────────────────────
                        Rectangle {
                            id: closeBtn
                            implicitWidth: 38
                            implicitHeight: 38
                            radius: 19
                            color: closeBtnMa.pressed ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.fgSurface, 0.12))
                                 : closeBtnMa.containsMouse ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.fgSurface, 0.08))
                                 : tok.palette.stageHigh

                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                font.family: "Material Symbols Rounded"
                                text: "close"
                                font.pixelSize: 18
                                color: tok.palette.fgSurface
                            }

                            MouseArea {
                                id: closeBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.close()
                            }
                        }
                    }
                }

                // ── Main Category Emoji List ─────────────────────────────────
                ListView {
                    id: mainList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    visible: !win.searchText
                    model: win.rowModel
                    spacing: 0
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 2500
                    maximumFlickVelocity: 3000
                    cacheBuffer: 600
                    interactive: !tonePopup.isOpen

                    NumberAnimation {
                        id: mainSmoothScrollAnim
                        target: mainList
                        property: "contentY"
                        duration: 260
                        easing.type: Easing.OutCubic
                    }

                    onMovementStarted: mainSmoothScrollAnim.stop()
                    onFlickStarted: mainSmoothScrollAnim.stop()

                    function clampScrollY(y) {
                        let maxScroll = Math.max(0, win.exactContentHeight - mainList.height)
                        return Math.max(0, Math.min(maxScroll, y))
                    }

                    function applyScrollDelta(deltaPx, animMs) {
                        let base = mainSmoothScrollAnim.running ? mainSmoothScrollAnim.to : mainList.contentY
                        let targetY = clampScrollY(base + deltaPx)
                        if (Math.abs(targetY - mainList.contentY) < 0.5 && !mainSmoothScrollAnim.running)
                            return
                        mainSmoothScrollAnim.stop()
                        mainSmoothScrollAnim.duration = animMs || 260
                        mainSmoothScrollAnim.from = mainList.contentY
                        mainSmoothScrollAnim.to = targetY
                        mainSmoothScrollAnim.start()
                    }

                    function scrollToY(targetY, animMs) {
                        let clamped = clampScrollY(targetY)
                        mainSmoothScrollAnim.stop()
                        mainSmoothScrollAnim.duration = animMs || 300
                        mainSmoothScrollAnim.from = mainList.contentY
                        mainSmoothScrollAnim.to = clamped
                        mainSmoothScrollAnim.start()
                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            let isTouchPad = event.device && event.device.type === PointerDevice.TouchPad
                            if (isTouchPad && event.pixelDelta.y !== 0) {
                                mainList.applyScrollDelta(-event.pixelDelta.y, 120)
                                event.accepted = true
                                return
                            }
                            let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                            if (delta === 0)
                                return
                            let notchPx = -(delta / 120) * 140
                            mainList.applyScrollDelta(notchPx, isTouchPad ? 120 : 260)
                            event.accepted = true
                        }
                    }

                    onContentYChanged: {
                        let maxScroll = Math.max(0, win.exactContentHeight - height)
                        if (contentY > maxScroll + 0.5)
                            contentY = maxScroll
                        else if (contentY < -0.5)
                            contentY = 0

                        let idx = indexAt(10, contentY + 12)
                        if (idx >= 0 && idx < win.rowModel.length) {
                            bottomBar.activeCategory = win.rowModel[idx].catIdx
                        }
                    }

                    delegate: unifiedDelegate
                }

                // ── Search Results List ──────────────────────────────────────
                ListView {
                    id: searchList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !!win.searchText
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 2500
                    maximumFlickVelocity: 3000
                    cacheBuffer: 600
                    interactive: !tonePopup.isOpen && (exactContentHeight > height)

                    readonly property real exactContentHeight: (searchList.model ? searchList.model.length : 0) * win.baseHeight

                    NumberAnimation {
                        id: searchSmoothScrollAnim
                        target: searchList
                        property: "contentY"
                        duration: 260
                        easing.type: Easing.OutCubic
                    }

                    onMovementStarted: searchSmoothScrollAnim.stop()
                    onFlickStarted: searchSmoothScrollAnim.stop()

                    function clampScrollY(y) {
                        let maxScroll = Math.max(0, searchList.exactContentHeight - searchList.height)
                        return Math.max(0, Math.min(maxScroll, y))
                    }

                    function applyScrollDelta(deltaPx, animMs) {
                        let base = searchSmoothScrollAnim.running ? searchSmoothScrollAnim.to : searchList.contentY
                        let targetY = clampScrollY(base + deltaPx)
                        if (Math.abs(targetY - searchList.contentY) < 0.5 && !searchSmoothScrollAnim.running)
                            return
                        searchSmoothScrollAnim.stop()
                        searchSmoothScrollAnim.duration = animMs || 260
                        searchSmoothScrollAnim.from = searchList.contentY
                        searchSmoothScrollAnim.to = targetY
                        searchSmoothScrollAnim.start()
                    }

                    onContentYChanged: {
                        let maxScroll = Math.max(0, searchList.exactContentHeight - height)
                        if (contentY > maxScroll + 0.5)
                            contentY = maxScroll
                        else if (contentY < -0.5)
                            contentY = 0
                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            let isTouchPad = event.device && event.device.type === PointerDevice.TouchPad
                            if (isTouchPad && event.pixelDelta.y !== 0) {
                                searchList.applyScrollDelta(-event.pixelDelta.y, 120)
                                event.accepted = true
                                return
                            }
                            let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                            if (delta === 0)
                                return
                            let notchPx = -(delta / 120) * 140
                            searchList.applyScrollDelta(notchPx, isTouchPad ? 120 : 260)
                            event.accepted = true
                        }
                    }

                    model: {
                        const COLS = 10
                        let chunks = []
                        let sr = win.searchResults
                        for (let i = 0; i < sr.length; i += COLS) {
                            chunks.push({ type: "row", emojis: sr.slice(i, i + COLS), catIdx: -1 })
                        }
                        return chunks
                    }

                    delegate: unifiedDelegate
                }

                // ── Bottom Bar: Category Tabs ────────────────────────────────
                Item {
                    id: bottomBarContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 6

                    RowLayout {
                        id: bottomBar
                        anchors.fill: parent
                        spacing: 2

                        property int activeCategory: 0
                        onActiveCategoryChanged: {
                            catTabs.scrollTabIntoView(activeCategory)
                        }

                        ListView {
                            id: catTabs
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
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
                                duration: 220
                                easing.type: Easing.OutCubic
                            }

                            onMovementStarted: catSmoothScrollAnim.stop()
                            onFlickStarted: catSmoothScrollAnim.stop()

                            function clampScrollX(x) {
                                let maxScroll = Math.max(0, catTabs.contentWidth - catTabs.width)
                                return Math.max(0, Math.min(maxScroll, x))
                            }

                            function applyScrollDelta(deltaPx, animMs) {
                                let base = catSmoothScrollAnim.running ? catSmoothScrollAnim.to : catTabs.contentX
                                let targetX = clampScrollX(base + deltaPx)
                                if (Math.abs(targetX - catTabs.contentX) < 0.5 && !catSmoothScrollAnim.running)
                                    return
                                catSmoothScrollAnim.stop()
                                catSmoothScrollAnim.duration = animMs || 220
                                catSmoothScrollAnim.from = catTabs.contentX
                                catSmoothScrollAnim.to = targetX
                                catSmoothScrollAnim.start()
                            }

                            function scrollToX(targetX, animMs) {
                                let clamped = clampScrollX(targetX)
                                catSmoothScrollAnim.stop()
                                catSmoothScrollAnim.duration = animMs || 240
                                catSmoothScrollAnim.from = catTabs.contentX
                                catSmoothScrollAnim.to = clamped
                                catSmoothScrollAnim.start()
                            }

                            function scrollTabIntoView(tabIdx) {
                                let tabWidth = win.baseWidth - 4
                                let spacing = 2
                                let tabLeft = tabIdx * (tabWidth + spacing)
                                let tabRight = tabLeft + tabWidth
                                let currentLeft = catTabs.contentX
                                let currentRight = currentLeft + catTabs.width

                                if (tabLeft < currentLeft)
                                    scrollToX(tabLeft - 8, 200)
                                else if (tabRight > currentRight)
                                    scrollToX(tabRight - catTabs.width + 8, 200)
                            }

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                orientation: Qt.Vertical | Qt.Horizontal
                                onWheel: function(event) {
                                    let isTouchPad = event.device && event.device.type === PointerDevice.TouchPad
                                    if (isTouchPad && event.pixelDelta.x !== 0) {
                                        catTabs.applyScrollDelta(-event.pixelDelta.x, 120)
                                        event.accepted = true
                                        return
                                    }
                                    let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                                    if (delta === 0)
                                        return
                                    let notchPx = -(delta / 120) * 100
                                    catTabs.applyScrollDelta(notchPx, isTouchPad ? 120 : 220)
                                    event.accepted = true
                                }
                            }

                            delegate: Item {
                                required property var modelData
                                required property int index

                                width: win.baseWidth - 4
                                height: 44

                                readonly property bool isActive: bottomBar.activeCategory === index

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 10
                                    color: parent.isActive
                                        ? Qt.alpha(tok.palette.primary, 0.16)
                                        : (tabMouseArea.containsMouse ? Qt.alpha(tok.palette.fgSurface, 0.08) : "transparent")

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -1
                                        text: (modelData && modelData.icon) ? modelData.icon : ""
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 20
                                        color: parent.parent.isActive
                                            ? tok.palette.primary
                                            : Qt.alpha(tok.palette.fgSurface, 0.55)
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    // Active underline
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 2
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.parent.isActive ? 16 : 0
                                        height: 2
                                        radius: 1
                                        color: tok.palette.primary
                                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    }
                                }

                                MouseArea {
                                    id: tabMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (win.searchText)
                                            searchInput.text = ""
                                        bottomBar.activeCategory = index
                                        let targetY = win.yPositionForCat(index)
                                        mainList.scrollToY(targetY, 300)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Floating Skin Tone Popup with Container Morph Animation ─────
            Item {
                id: tonePopupContainer
                anchors.fill: parent
                z: 100
                visible: tonePopup.opacity > 0.001

                MouseArea {
                    id: toneDismissArea
                    anchors.fill: parent
                    enabled: tonePopup.isOpen
                    onPressed: tonePopup.close()
                }

                Rectangle {
                    id: tonePopup
                    property bool isOpen: false
                    property var currentSourceItem: null

                    property real originX: 0
                    property real originY: 0
                    property real originWidth: 38
                    property real originHeight: 38
                    property real originRadius: 19

                    property real targetX: 0
                    property real targetY: 0
                    property real targetWidth: 246
                    property real targetHeight: 46
                    property real targetRadius: 23

                    x: originX
                    y: originY
                    width: originWidth
                    height: originHeight
                    radius: originRadius
                    opacity: 0.0
                    clip: true

                    color: tok.palette.stageContent
                    border.color: Qt.alpha(tok.palette.fgSurface, 0.14)
                    border.width: 1

                    function getSourceRect() {
                        let src = currentSourceItem || toneSelectorBtn
                        if (!src) return { x: shell.width / 2, y: 50, width: 38, height: 38, radius: 19 }
                        let pos = src.mapToItem(shell, 0, 0)
                        return {
                            x: pos.x,
                            y: pos.y,
                            width: src.width || 38,
                            height: src.height || 38,
                            radius: (typeof src.radius !== "undefined") ? src.radius : (src.height ? src.height / 2 : 19)
                        }
                    }

                    function getTargetRect() {
                        let srcRect = getSourceRect()
                        let targetW = 246
                        let targetH = 46
                        let targetR = 23
                        let targetX = Math.max(12, Math.min(srcRect.x + (srcRect.width - targetW) / 2, shell.width - targetW - 12))
                        let targetY
                        if (srcRect.y + srcRect.height + targetH + 8 > shell.height) {
                            targetY = srcRect.y - targetH - 6
                        } else {
                            targetY = srcRect.y + srcRect.height + 6
                        }
                        return {
                            x: targetX,
                            y: targetY,
                            width: targetW,
                            height: targetH,
                            radius: targetR
                        }
                    }

                    function open(sourceItem) {
                        currentSourceItem = sourceItem || toneSelectorBtn
                        let src = getSourceRect()
                        let tgt = getTargetRect()

                        originX = src.x
                        originY = src.y
                        originWidth = src.width
                        originHeight = src.height
                        originRadius = src.radius

                        targetX = tgt.x
                        targetY = tgt.y
                        targetWidth = tgt.width
                        targetHeight = tgt.height
                        targetRadius = tgt.radius

                        closeMorphAnim.stop()
                        openMorphAnim.stop()

                        x = originX
                        y = originY
                        width = originWidth
                        height = originHeight
                        radius = originRadius
                        opacity = 0.2
                        tonePopupContent.opacity = 0.0
                        tonePopupContent.scale = 0.65

                        isOpen = true
                        openMorphAnim.start()
                    }

                    function close() {
                        if (!isOpen && !openMorphAnim.running)
                            return
                        openMorphAnim.stop()
                        closeMorphAnim.stop()
                        closeMorphAnim.start()
                    }

                    function toggle(sourceItem) {
                        if (isOpen || openMorphAnim.running)
                            close()
                        else
                            open(sourceItem)
                    }

                    ParallelAnimation {
                        id: openMorphAnim
                        NumberAnimation {
                            target: tonePopup
                            property: "x"
                            from: tonePopup.originX
                            to: tonePopup.targetX
                            duration: 250
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.12
                        }
                        NumberAnimation {
                            target: tonePopup
                            property: "y"
                            from: tonePopup.originY
                            to: tonePopup.targetY
                            duration: 250
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.12
                        }
                        NumberAnimation {
                            target: tonePopup
                            property: "width"
                            from: tonePopup.originWidth
                            to: tonePopup.targetWidth
                            duration: 250
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.15
                        }
                        NumberAnimation {
                            target: tonePopup
                            property: "height"
                            from: tonePopup.originHeight
                            to: tonePopup.targetHeight
                            duration: 230
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: tonePopup
                            property: "radius"
                            from: tonePopup.originRadius
                            to: tonePopup.targetRadius
                            duration: 230
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: tonePopup
                            property: "opacity"
                            from: 0.2
                            to: 1.0
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: tonePopupContent
                            property: "opacity"
                            from: 0.0
                            to: 1.0
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: tonePopupContent
                            property: "scale"
                            from: 0.65
                            to: 1.0
                            duration: 250
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.15
                        }
                    }

                    ParallelAnimation {
                        id: closeMorphAnim
                        onFinished: {
                            tonePopup.isOpen = false
                        }
                        NumberAnimation {
                            target: tonePopup
                            property: "x"
                            to: tonePopup.originX
                            duration: 180
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: tonePopup
                            property: "y"
                            to: tonePopup.originY
                            duration: 180
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: tonePopup
                            property: "width"
                            to: tonePopup.originWidth
                            duration: 180
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: tonePopup
                            property: "height"
                            to: tonePopup.originHeight
                            duration: 160
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: tonePopup
                            property: "radius"
                            to: tonePopup.originRadius
                            duration: 160
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: tonePopup
                            property: "opacity"
                            to: 0.0
                            duration: 160
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: tonePopupContent
                            property: "opacity"
                            to: 0.0
                            duration: 90
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: tonePopupContent
                            property: "scale"
                            to: 0.65
                            duration: 160
                            easing.type: Easing.InCubic
                        }
                    }

                    Item {
                        id: tonePopupContent
                        anchors.fill: parent

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Repeater {
                                model: win.skinTones
                                delegate: Item {
                                    width: 32
                                    height: 32

                                    readonly property bool isSelected: win.currentSkinTone === modelData
                                    readonly property color toneColor: index === 0 ? "#FFD43F" : ["#FADCBC", "#E0BB95", "#BF8F68", "#9B643D", "#5A3825"][index - 1]

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: isSelected ? Qt.alpha(tok.palette.primary, 0.25) : "transparent"
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: isSelected ? 22 : 26
                                        height: isSelected ? 22 : 26
                                        radius: width / 2
                                        color: toneColor
                                        border.color: Qt.alpha(tok.palette.fgSurface, 0.2)
                                        border.width: 1
                                        scale: swatchArea.pressed ? 0.9 : (swatchArea.containsMouse ? 1.1 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                    }

                                    MouseArea {
                                        id: swatchArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            win.currentSkinTone = modelData
                                            EmojiBackend.saveSkinTone(modelData)
                                            tonePopup.close()
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

    // ── Unified Delegate for Category & Search Lists ─────────────────────
    Component {
        id: unifiedDelegate
        Item {
            required property var modelData
            required property int index

            width: ListView.view ? ListView.view.width : win.width
            height: (modelData && modelData.type === "header") ? 28 : win.baseHeight

            // Category Header Section
            Item {
                anchors.centerIn: parent
                width: 10 * win.baseWidth
                height: 28
                visible: modelData && modelData.type === "header"

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    text: (modelData && modelData.name) ? modelData.name : ""
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Qt.alpha(tok.palette.fgSurface, 0.55)
                    font.letterSpacing: 0.5
                }
            }

            // Category Row of Emojis (10 Columns)
            Item {
                anchors.centerIn: parent
                width: 10 * win.baseWidth
                height: win.baseHeight
                visible: modelData && modelData.type === "row"

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Repeater {
                        model: (modelData && modelData.type === "row") ? modelData.emojis : []
                        delegate: Item {
                            id: emojiCell
                            required property var modelData
                            required property int index

                            width: win.baseWidth
                            height: win.baseHeight

                            readonly property string emojiStr: modelData || ""
                            readonly property string emojiDisplayed: win.applySkinTone(emojiStr)

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: 8
                                color: emojiArea.pressed ? Qt.alpha(tok.palette.fgSurface, 0.18)
                                     : emojiArea.containsMouse ? Qt.alpha(tok.palette.fgSurface, 0.08) : "transparent"
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: emojiCell.emojiDisplayed
                                font.pixelSize: 32
                            }

                            MouseArea {
                                id: emojiArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                pressAndHoldInterval: 320
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onClicked: function(mouse) {
                                    let targetDisplayed = emojiCell.emojiDisplayed
                                    let targetBase = emojiCell.emojiStr

                                    if (mouse.button === Qt.RightButton && win.isToneable(targetBase)) {
                                        showTonePopup(emojiCell)
                                        return
                                    }

                                    // Copy to clipboard, save to recents, and exit
                                    EmojiBackend.copyEmoji(targetDisplayed, targetBase)
                                }

                                onPressAndHold: {
                                    if (win.isToneable(emojiCell.emojiStr)) {
                                        showTonePopup(emojiCell)
                                    }
                                }

                                function showTonePopup(sourceItem) {
                                    tonePopup.open(sourceItem)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Entrance Animation Trigger ───────────────────────────────────────
    property real shellOpacity: 0
    property real shellScale: 0.95

    Component.onCompleted: {
        shellScale = 1.0
        shellOpacity = 1.0
    }
}
