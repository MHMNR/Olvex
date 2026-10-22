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

    // ── Search Results Model (C++ Search Engine) ─────────────────────────
    property var searchResults: {
        if (!searchText)
            return []
        let query = searchText.trim()
        if (!query)
            return []
        if (typeof EmojiBackend !== "undefined" && EmojiBackend.search)
            return EmojiBackend.search(query, 160)
        return []
    }

    property var searchRowModel: {
        const COLS = 10
        let chunks = []
        let sr = searchResults || []
        for (let i = 0; i < sr.length; i += COLS) {
            chunks.push({ type: "row", emojis: sr.slice(i, i + COLS), catIdx: -1 })
        }
        return chunks
    }

    onSearchRowModelChanged: {
        if (win.searchText) {
            selectedRowIndex = 0
            selectedColIndex = 0
            searchList.contentY = 0
        }
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

    // ── Keyboard Navigation & Selection State ──
    property int selectedRowIndex: 1
    property int selectedColIndex: 0
    property bool keyboardNavActive: false
    property int hoveredRowIndex: -1
    property int hoveredColIndex: -1
    property bool mouseHoverActive: false

    onRowModelChanged: {
        if (!win.searchText) {
            let m = rowModel || []
            if (selectedRowIndex < 0 || selectedRowIndex >= m.length || (m[selectedRowIndex] && m[selectedRowIndex].type !== "row")) {
                for (let i = 0; i < m.length; i++) {
                    if (m[i].type === "row") {
                        selectedRowIndex = i
                        break
                    }
                }
            }
        }
    }

    function currentEmojiList() {
        if (win.searchText) {
            return win.searchResults || []
        }
        let list = []
        let rows = win.rowModel || []
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].type === "row" && rows[i].emojis) {
                for (let j = 0; j < rows[i].emojis.length; j++) {
                    list.push(rows[i].emojis[j])
                }
            }
        }
        return list
    }

    function selectCurrentEmoji() {
        let activeList = (win.searchText ? searchList : mainList)
        let model = activeList.model || []
        if (selectedRowIndex >= 0 && selectedRowIndex < model.length) {
            let row = model[selectedRowIndex]
            if (row && row.type === "row" && row.emojis && selectedColIndex >= 0 && selectedColIndex < row.emojis.length) {
                let base = row.emojis[selectedColIndex]
                let displayed = win.applySkinTone(base)
                EmojiBackend.copyEmoji(displayed, base)
            }
        }
    }

    function scrollCurrentSelectionIntoView() {
        let activeList = (win.searchText ? searchList : mainList)
        let rowY = 0
        let model = activeList.model || []
        for (let i = 0; i < selectedRowIndex && i < model.length; i++) {
            rowY += (model[i].type === "header" ? 28 : win.baseHeight)
        }
        let rowH = (model[selectedRowIndex] && model[selectedRowIndex].type === "header") ? 28 : win.baseHeight
        let visTop = activeList.contentY
        let visBot = visTop + activeList.height
        let maxScroll = Math.max(0, (activeList.exactContentHeight || 0) - activeList.height)

        let target = -1
        if (rowY < visTop) {
            target = Math.max(0, rowY - 18)
        } else if (rowY + rowH > visBot) {
            target = Math.min(maxScroll, (rowY + rowH) - activeList.height + 18)
        }
        if (target >= 0) {
            if (win.searchText) {
                searchSmoothScrollAnim.stop()
                searchSmoothScrollAnim.duration = 220
                searchSmoothScrollAnim.from = searchList.contentY
                searchSmoothScrollAnim.to = target
                searchSmoothScrollAnim.start()
            } else {
                bounceBackSpring.stop()
                mainSmoothScrollAnim.stop()
                mainSmoothScrollAnim.duration = 220
                mainSmoothScrollAnim.from = mainList.contentY
                mainSmoothScrollAnim.to = target
                mainSmoothScrollAnim.start()
            }
        }
    }

    function navMove(dRow, dCol) {
        let activeList = (win.searchText ? searchList : mainList)
        let model = activeList.model || []
        if (model.length === 0) return

        if (!keyboardNavActive) {
            // First activation: find first visible row at or near contentY
            let curY = activeList.contentY
            let accY = 0
            let targetRow = -1
            for (let i = 0; i < model.length; i++) {
                let h = (model[i].type === "header" ? 28 : win.baseHeight)
                if (model[i].type === "row" && (accY + h > curY || targetRow === -1)) {
                    targetRow = i
                    if (accY + h > curY) break
                }
                accY += h
            }
            if (targetRow >= 0) {
                selectedRowIndex = targetRow
            }
            selectedColIndex = 0
            keyboardNavActive = true
            scrollCurrentSelectionIntoView()
            return
        }

        let r = selectedRowIndex
        let c = selectedColIndex

        if (dRow !== 0) {
            let step = dRow > 0 ? 1 : -1
            let nr = r + step
            while (nr >= 0 && nr < model.length && model[nr].type !== "row") {
                nr += step
            }
            if (nr >= 0 && nr < model.length && model[nr].type === "row") {
                r = nr
                let maxCols = model[r].emojis ? model[r].emojis.length : 10
                c = Math.min(c, maxCols - 1)
            }
        }

        if (dCol !== 0) {
            let rowItem = model[r]
            let maxCols = (rowItem && rowItem.emojis) ? rowItem.emojis.length : 10
            let nc = c + dCol
            if (nc >= 0 && nc < maxCols) {
                c = nc
            } else if (nc >= maxCols) {
                let nr = r + 1
                while (nr < model.length && model[nr].type !== "row") nr++
                if (nr < model.length) {
                    r = nr
                    c = 0
                }
            } else if (nc < 0) {
                let nr = r - 1
                while (nr >= 0 && model[nr].type !== "row") nr--
                if (nr >= 0) {
                    r = nr
                    let prevCols = model[r].emojis ? model[r].emojis.length : 10
                    c = Math.max(0, prevCols - 1)
                }
            }
        }

        selectedRowIndex = r
        selectedColIndex = c
        scrollCurrentSelectionIntoView()
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
            if (searchPill.searchActive) {
                searchPill.closeSearch()
                event.accepted = true
                return
            }
            win.close()
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Up) {
            navMove(-1, 0)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Down) {
            navMove(1, 0)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Left) {
            navMove(0, -1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Right) {
            navMove(0, 1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            selectCurrentEmoji()
            event.accepted = true
            return
        }
    }

    // ── Root Focus & Entrance Animation ──────────────────────────────────
    FocusScope {
        id: rootFocus
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                win.handleKey(event)
                return
            }

            if (event.text && event.text.length > 0
                && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                && event.text.charCodeAt(0) >= 32
                && event.key !== Qt.Key_Tab
                && event.key !== Qt.Key_Backtab
                && event.key !== Qt.Key_Delete
                && event.key !== Qt.Key_Backspace) {

                if (!searchPill.searchActive) {
                    if (event.text.trim().length > 0) {
                        searchPill.searchExpanded = true
                        searchInput.forceActiveFocus()
                        searchInput.text = event.text
                        searchInput.cursorPosition = searchInput.text.length
                        event.accepted = true
                        return
                    }
                } else if (!searchInput.activeFocus) {
                    searchInput.forceActiveFocus()
                    searchInput.insert(searchInput.cursorPosition, event.text)
                    event.accepted = true
                    return
                }
            } else if (event.key === Qt.Key_Backspace && searchPill.searchActive && !searchInput.activeFocus) {
                searchInput.forceActiveFocus()
                if (searchInput.cursorPosition > 0) {
                    searchInput.remove(searchInput.cursorPosition - 1, searchInput.cursorPosition)
                }
                event.accepted = true
                return
            }

            win.handleKey(event)
        }

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
                    z: 50
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Layout.topMargin: 8

                    // Header empty space dismiss
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        enabled: searchPill.searchActive
                        onPressed: searchPill.closeSearch()
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        // ── Window Title on Left ──────────────────────────────
                        Text {
                            id: windowTitle
                            text: qsTr("Emoji")
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: tok.palette.fgSurface
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: 4
                            opacity: searchPill.searchActive ? 0.0 : 1.0
                            visible: opacity > 0.01

                            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // ── Expandable Search Pill (Circle 38px → 320px input field) ──
                        Rectangle {
                            id: searchPill

                            property bool searchExpanded: false
                            readonly property bool searchActive: searchExpanded || (searchInput && (searchInput.text.length > 0 || searchInput.activeFocus))

                            function closeSearch() {
                                searchExpanded = false
                                if (searchInput) {
                                    searchInput.text = ""
                                    searchInput.focus = false
                                }
                                win.searchText = ""
                                rootFocus.forceActiveFocus()
                            }

                            implicitWidth: searchActive ? Math.min(320, headerContainer.width - 150) : 38
                            implicitHeight: 38
                            radius: 19
                            clip: true

                            color: searchInput.activeFocus
                                ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.primary, 0.08))
                                : (searchHover.containsMouse ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.fgSurface, 0.08)) : tok.palette.stageHigh)

                            Behavior on implicitWidth { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler {
                                id: searchHover
                                cursorShape: searchPill.searchActive ? Qt.IBeamCursor : Qt.PointingHandCursor
                            }

                            // Collapsed Click-to-Expand Trigger
                            MouseArea {
                                anchors.fill: parent
                                visible: !searchPill.searchActive
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchPill.searchExpanded = true
                                    Qt.callLater(() => searchInput.forceActiveFocus())
                                }
                            }

                            // Single Persistent Search Icon (Smoothly transitions position & tint)
                            Item {
                                id: searchIconBox
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: searchPill.searchActive ? 12 : 10
                                width: 18
                                height: 18

                                Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                Text {
                                    anchors.centerIn: parent
                                    font.family: "Material Symbols Rounded"
                                    text: "search"
                                    font.pixelSize: 18
                                    color: searchInput.activeFocus ? tok.palette.primary : (searchPill.searchActive ? tok.palette.fgMuted : tok.palette.fgSurface)
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }

                            // Text Input & Placeholder Holder
                            Item {
                                id: inputHolder
                                anchors.left: searchIconBox.right
                                anchors.leftMargin: 8
                                anchors.right: clearBtn.left
                                anchors.rightMargin: 4
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                clip: true
                                opacity: searchPill.searchActive ? 1.0 : 0.0
                                visible: searchPill.searchActive || opacity > 0.01

                                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

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
                                    cursorVisible: activeFocus

                                    onTextChanged: {
                                        win.searchText = text
                                        win.keyboardNavActive = false
                                        win.selectedRowIndex = 0
                                        win.selectedColIndex = 0
                                        if (text)
                                            searchList.contentY = 0
                                    }

                                    Keys.priority: Keys.BeforeItem
                                    Keys.onUpPressed: function(event) {
                                        win.navMove(-1, 0)
                                        event.accepted = true
                                    }
                                    Keys.onDownPressed: function(event) {
                                        win.navMove(1, 0)
                                        event.accepted = true
                                    }
                                    Keys.onLeftPressed: function(event) {
                                        win.navMove(0, -1)
                                        event.accepted = true
                                    }
                                    Keys.onRightPressed: function(event) {
                                        win.navMove(0, 1)
                                        event.accepted = true
                                    }
                                    Keys.onReturnPressed: function(event) {
                                        win.selectCurrentEmoji()
                                        event.accepted = true
                                    }
                                    Keys.onEnterPressed: function(event) {
                                        win.selectCurrentEmoji()
                                        event.accepted = true
                                    }

                                    Keys.onEscapePressed: function(event) {
                                        if (text.length > 0) {
                                            text = ""
                                            event.accepted = true
                                        } else {
                                            searchPill.closeSearch()
                                            event.accepted = true
                                        }
                                    }
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: qsTr("Search emojis…")
                                    font.pixelSize: 14
                                    color: Qt.alpha(tok.palette.fgSurface, 0.4)
                                    visible: searchInput.text.length === 0 && !searchInput.inputMethodComposing
                                    opacity: searchInput.text.length === 0 ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }
                            }

                            // Clear / Close 'x' Button
                            Rectangle {
                                id: clearBtn
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 13
                                color: clearBtnMa.pressed ? Qt.alpha(tok.palette.fgSurface, 0.15)
                                     : clearBtnMa.containsMouse ? Qt.alpha(tok.palette.fgSurface, 0.08) : "transparent"
                                opacity: (searchPill.searchActive && searchInput.text.length > 0) ? 1.0 : 0.0
                                visible: opacity > 0.01

                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    font.family: "Material Symbols Rounded"
                                    text: "close"
                                    font.pixelSize: 16
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

                        // ── Skin Tone Selector Pill in Header ────────────────
                        Rectangle {
                            id: toneSelectorBtn

                            readonly property bool isExpanded: toneBtnMa.containsMouse || tonePopup.isOpen

                            implicitWidth: isExpanded ? (toneBtnText.implicitWidth + 46) : 38
                            implicitHeight: 38
                            radius: 19
                            color: toneBtnMa.pressed ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.fgSurface, 0.12))
                                 : toneBtnMa.containsMouse ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.fgSurface, 0.08))
                                 : tok.palette.stageHigh

                            Behavior on color { ColorAnimation { duration: 100 } }
                            Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                            clip: true

                            Item {
                                anchors.fill: parent

                                Rectangle {
                                    id: toneSwatchBox
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
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

                                Text {
                                    id: toneBtnText
                                    anchors.left: toneSwatchBox.right
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Tone")
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: tok.palette.fgSurface
                                    opacity: toneSelectorBtn.isExpanded ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                            }

                            MouseArea {
                                id: toneBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (searchPill.searchActive)
                                        searchPill.closeSearch()
                                    tonePopup.toggle(toneSelectorBtn)
                                }
                            }
                        }

                        // ── Rebuild Database Button ──────────────────────────
                        Rectangle {
                            id: rebuildBtn

                            readonly property bool isExpanded: rebuildBtnMa.containsMouse || EmojiBackend.isUpdating || (EmojiBackend.updateStatus !== "")

                            implicitWidth: isExpanded ? (rebuildBtnText.implicitWidth + 46) : 38
                            implicitHeight: 38
                            radius: 19
                            color: rebuildBtnMa.pressed ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.fgSurface, 0.12))
                                 : rebuildBtnMa.containsMouse ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.fgSurface, 0.08))
                                 : tok.palette.stageHigh

                            Behavior on color { ColorAnimation { duration: 100 } }
                            Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                            clip: true

                            Item {
                                anchors.fill: parent

                                Item {
                                    id: rebuildIconBox
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18
                                    height: 18

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
                                }

                                Text {
                                    id: rebuildBtnText
                                    anchors.left: rebuildIconBox.right
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: EmojiBackend.updateStatus ? EmojiBackend.updateStatus : (EmojiBackend.isUpdating ? qsTr("Updating…") : qsTr("Rebuild"))
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: tok.palette.fgSurface
                                    opacity: rebuildBtn.isExpanded ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                            }

                            MouseArea {
                                id: rebuildBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: EmojiBackend.isUpdating ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: {
                                    if (!EmojiBackend.isUpdating)
                                        EmojiBackend.rebuildDatabase()
                                }
                            }
                        }

                        // ── Close Window Button ──────────────────────────────
                        Rectangle {
                            id: closeBtn

                            readonly property bool isExpanded: closeBtnMa.containsMouse

                            implicitWidth: isExpanded ? (closeBtnText.implicitWidth + 46) : 38
                            implicitHeight: 38
                            radius: 19
                            color: closeBtnMa.pressed ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.fgSurface, 0.12))
                                 : closeBtnMa.containsMouse ? Qt.tint(tok.palette.stageHigh, Qt.alpha(tok.palette.fgSurface, 0.08))
                                 : tok.palette.stageHigh

                            Behavior on color { ColorAnimation { duration: 100 } }
                            Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                            clip: true

                            Item {
                                anchors.fill: parent

                                Item {
                                    id: closeIconBox
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18
                                    height: 18

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: "Material Symbols Rounded"
                                        text: "close"
                                        font.pixelSize: 18
                                        color: tok.palette.fgSurface
                                    }
                                }

                                Text {
                                    id: closeBtnText
                                    anchors.left: closeIconBox.right
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Close")
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: tok.palette.fgSurface
                                    opacity: closeBtn.isExpanded ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
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

                // ── Emoji List Viewport Area ─────────────────────────────────
                Item {
                    id: listArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    // Dismiss search when clicking empty space in list area
                    MouseArea {
                        id: listAreaSearchDismiss
                        anchors.fill: parent
                        z: -1
                        enabled: searchPill.searchActive
                        cursorShape: Qt.ArrowCursor
                        onPressed: function(mouse) {
                            searchPill.closeSearch()
                        }
                    }

                    ListView {
                        id: mainList
                        anchors.fill: parent
                        clip: true
                        visible: !win.searchText
                        model: win.rowModel
                        spacing: 0
                        boundsBehavior: Flickable.StopAtBounds
                        flickDeceleration: 2500
                        maximumFlickVelocity: 3000
                        cacheBuffer: 600
                        interactive: !tonePopup.isOpen

                        readonly property real exactContentHeight: win.exactContentHeight

                    property bool isProgrammaticScroll: false

                    function clampScrollY(y) {
                        let maxScroll = Math.max(0, win.exactContentHeight - mainList.height)
                        return Math.max(0, Math.min(maxScroll, y))
                    }

                    function scrollToY(targetY, animMs) {
                        let clamped = clampScrollY(targetY)
                        isProgrammaticScroll = true
                        mainSmoothScrollAnim.stop()
                        bounceBackSpring.stop()
                        touchpadReleaseTimer.stop()
                        mainSmoothScrollAnim.duration = animMs || 300
                        mainSmoothScrollAnim.from = mainList.contentY
                        mainSmoothScrollAnim.to = clamped
                        mainSmoothScrollAnim.start()
                    }

                    NumberAnimation {
                        id: mainSmoothScrollAnim
                        target: mainList
                        property: "contentY"
                        duration: 260
                        easing.type: Easing.OutCubic
                        onStopped: {
                            mainList.isProgrammaticScroll = false
                            mainList.checkOverscrollBounds()
                        }
                    }

                    SpringAnimation {
                        id: bounceBackSpring
                        target: mainList
                        property: "contentY"
                        spring: 4.8
                        damping: 0.70
                        epsilon: 0.15
                    }

                    Timer {
                        id: touchpadReleaseTimer
                        interval: 85
                        repeat: false
                        onTriggered: mainList.checkOverscrollBounds()
                    }

                    function checkOverscrollBounds() {
                        let maxScroll = Math.max(0, win.exactContentHeight - mainList.height)
                        if (mainList.contentY < 0) {
                            mainSmoothScrollAnim.stop()
                            bounceBackSpring.stop()
                            bounceBackSpring.from = mainList.contentY
                            bounceBackSpring.to = 0
                            bounceBackSpring.start()
                        } else if (mainList.contentY > maxScroll) {
                            mainSmoothScrollAnim.stop()
                            bounceBackSpring.stop()
                            bounceBackSpring.from = mainList.contentY
                            bounceBackSpring.to = maxScroll
                            bounceBackSpring.start()
                        }
                    }

                    onMovementStarted: {
                        isProgrammaticScroll = false
                        if (searchPill.searchActive) searchPill.closeSearch()
                        mainSmoothScrollAnim.stop()
                        bounceBackSpring.stop()
                    }
                    onFlickStarted: {
                        isProgrammaticScroll = false
                        if (searchPill.searchActive) searchPill.closeSearch()
                        mainSmoothScrollAnim.stop()
                        bounceBackSpring.stop()
                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            mainList.isProgrammaticScroll = false
                            let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                            if (!delta) return

                            let maxScroll = Math.max(0, win.exactContentHeight - mainList.height)
                            let isDiscrete = Math.abs(delta) >= 120
                            let direction = delta > 0 ? -1 : 1

                            if (isDiscrete) {
                                bounceBackSpring.stop()
                                touchpadReleaseTimer.stop()

                                let step = win.baseHeight * 2
                                let base = mainSmoothScrollAnim.running ? mainSmoothScrollAnim.to : mainList.contentY
                                let nextTarget = base + direction * step

                                const maxOvershoot = 36
                                if (nextTarget < -maxOvershoot) {
                                    nextTarget = -maxOvershoot
                                } else if (nextTarget > maxScroll + maxOvershoot) {
                                    nextTarget = maxScroll + maxOvershoot
                                }

                                mainSmoothScrollAnim.stop()
                                mainSmoothScrollAnim.from = mainList.contentY
                                mainSmoothScrollAnim.to = nextTarget
                                mainSmoothScrollAnim.start()
                            } else {
                                mainSmoothScrollAnim.stop()
                                bounceBackSpring.stop()

                                let dy = -delta * 0.65
                                let newY = mainList.contentY + dy

                                if (newY < 0) {
                                    newY = mainList.contentY + dy * 0.35
                                } else if (newY > maxScroll) {
                                    newY = mainList.contentY + dy * 0.35
                                }

                                mainList.contentY = newY
                                touchpadReleaseTimer.restart()
                            }
                            event.accepted = true
                        }
                    }

                    onContentYChanged: {
                        if (!isProgrammaticScroll) {
                            let idx = indexAt(10, Math.max(0, contentY) + 12)
                            if (idx >= 0 && idx < win.rowModel.length) {
                                bottomBar.activeCategory = win.rowModel[idx].catIdx
                            }
                        }
                    }

                    delegate: unifiedDelegate
                }

                // ── Search Results List ──────────────────────────────────────
                ListView {
                    id: searchList
                    z: 45
                    anchors.fill: parent
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
                        onStopped: searchList.checkOverscrollBounds()
                    }

                    SpringAnimation {
                        id: searchBounceBackSpring
                        target: searchList
                        property: "contentY"
                        spring: 4.8
                        damping: 0.70
                        epsilon: 0.15
                    }

                    Timer {
                        id: searchTouchpadReleaseTimer
                        interval: 85
                        repeat: false
                        onTriggered: searchList.checkOverscrollBounds()
                    }

                    function checkOverscrollBounds() {
                        let maxScroll = Math.max(0, searchList.exactContentHeight - searchList.height)
                        if (searchList.contentY < 0) {
                            searchSmoothScrollAnim.stop()
                            searchBounceBackSpring.stop()
                            searchBounceBackSpring.from = searchList.contentY
                            searchBounceBackSpring.to = 0
                            searchBounceBackSpring.start()
                        } else if (searchList.contentY > maxScroll) {
                            searchSmoothScrollAnim.stop()
                            searchBounceBackSpring.stop()
                            searchBounceBackSpring.from = searchList.contentY
                            searchBounceBackSpring.to = maxScroll
                            searchBounceBackSpring.start()
                        }
                    }

                    onMovementStarted: {
                        searchSmoothScrollAnim.stop()
                        searchBounceBackSpring.stop()
                    }
                    onFlickStarted: {
                        searchSmoothScrollAnim.stop()
                        searchBounceBackSpring.stop()
                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                            if (!delta) return

                            let maxScroll = Math.max(0, searchList.exactContentHeight - searchList.height)
                            let isDiscrete = Math.abs(delta) >= 120
                            let direction = delta > 0 ? -1 : 1

                            if (isDiscrete) {
                                searchBounceBackSpring.stop()
                                searchTouchpadReleaseTimer.stop()

                                let step = win.baseHeight * 2
                                let base = searchSmoothScrollAnim.running ? searchSmoothScrollAnim.to : searchList.contentY
                                let nextTarget = base + direction * step

                                const maxOvershoot = 36
                                if (nextTarget < -maxOvershoot) {
                                    nextTarget = -maxOvershoot
                                } else if (nextTarget > maxScroll + maxOvershoot) {
                                    nextTarget = maxScroll + maxOvershoot
                                }

                                searchSmoothScrollAnim.stop()
                                searchSmoothScrollAnim.from = searchList.contentY
                                searchSmoothScrollAnim.to = nextTarget
                                searchSmoothScrollAnim.start()
                            } else {
                                searchSmoothScrollAnim.stop()
                                searchBounceBackSpring.stop()

                                let dy = -delta * 0.65
                                let newY = searchList.contentY + dy

                                if (newY < 0) {
                                    newY = searchList.contentY + dy * 0.35
                                } else if (newY > maxScroll) {
                                    newY = searchList.contentY + dy * 0.35
                                }

                                searchList.contentY = newY
                                searchTouchpadReleaseTimer.restart()
                            }
                            event.accepted = true
                        }
                    }

                    model: win.searchRowModel

                    delegate: unifiedDelegate
                }

                // ── Sliding Spring Focus Highlight Marker (Launcher style) ─
                Rectangle {
                    id: emojiFocusMarker
                    z: 10
                    width: win.baseWidth - 6
                    height: win.baseHeight - 6
                    radius: 8
                    color: Qt.alpha(tok.palette.primary, 0.28)
                    border.width: 0

                    property bool springEnabled: false

                    readonly property var activeList: win.searchText ? searchList : mainList
                    readonly property real startX: (listArea.width - 10 * win.baseWidth) / 2 + 3

                    readonly property real calcTargetY: {
                        let y = 0
                        let m = activeList.model || []
                        let targetIdx = win.selectedRowIndex
                        if (targetIdx < 0) targetIdx = 0
                        if (targetIdx >= m.length) targetIdx = m.length - 1

                        for (let i = 0; i < targetIdx && i < m.length; i++) {
                            y += (m[i].type === "header" ? 28 : win.baseHeight)
                        }
                        return y - activeList.contentY + 3
                    }
                    readonly property real calcTargetX: startX + win.selectedColIndex * win.baseWidth

                    property real markerX: calcTargetX
                    property real markerY: calcTargetY

                    x: markerX
                    y: markerY
                    opacity: win.keyboardNavActive ? 1 : 0
                    visible: opacity > 0.01

                    function retarget(animate) {
                        springEnabled = animate && win.keyboardNavActive && opacity > 0.05
                        markerX = calcTargetX
                        markerY = calcTargetY
                        if (win.keyboardNavActive) {
                            Qt.callLater(() => {
                                emojiFocusMarker.springEnabled = true
                            })
                        }
                    }

                    onCalcTargetXChanged: retarget(win.keyboardNavActive && opacity > 0.05)
                    onCalcTargetYChanged: retarget(win.keyboardNavActive && opacity > 0.05)

                    Connections {
                        target: win
                        function onKeyboardNavActiveChanged() {
                            if (win.keyboardNavActive) {
                                emojiFocusMarker.springEnabled = false
                                emojiFocusMarker.markerX = emojiFocusMarker.calcTargetX
                                emojiFocusMarker.markerY = emojiFocusMarker.calcTargetY
                                Qt.callLater(() => {
                                    emojiFocusMarker.springEnabled = true
                                })
                            } else {
                                emojiFocusMarker.springEnabled = false
                            }
                        }
                    }

                    Connections {
                        target: emojiFocusMarker.activeList
                        function onContentYChanged() {
                            if (win.keyboardNavActive) {
                                emojiFocusMarker.retarget(true)
                            }
                        }
                    }

                    Behavior on markerX {
                        enabled: emojiFocusMarker.springEnabled
                        SpringAnimation {
                            spring: 4.8
                            damping: 0.72
                            mass: 1.0
                            epsilon: 0.005
                        }
                    }
                    Behavior on markerY {
                        enabled: emojiFocusMarker.springEnabled
                        SpringAnimation {
                            spring: 4.8
                            damping: 0.72
                            mass: 1.0
                            epsilon: 0.005
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }

                Timer {
                    id: emojiHoverClearTimer
                    interval: 40
                    repeat: false
                    onTriggered: {
                        win.hoveredRowIndex = -1
                        win.hoveredColIndex = -1
                        win.mouseHoverActive = false
                    }
                }

                // ── Sliding Spring Hover Highlight Marker for Emojis ─────
                Rectangle {
                    id: emojiHoverMarker
                    z: 9
                    width: win.baseWidth - 6
                    height: win.baseHeight - 6
                    radius: 8
                    color: Qt.alpha(tok.palette.fgSurface, 0.08)
                    border.width: 0

                    property bool springEnabled: false

                    readonly property var activeList: win.searchText ? searchList : mainList
                    readonly property real startX: (listArea.width - 10 * win.baseWidth) / 2 + 3

                    readonly property real calcTargetY: {
                        let y = 0
                        let m = activeList.model || []
                        let targetIdx = win.hoveredRowIndex
                        if (targetIdx < 0) return 0
                        if (targetIdx >= m.length) targetIdx = m.length - 1

                        for (let i = 0; i < targetIdx && i < m.length; i++) {
                            y += (m[i].type === "header" ? 28 : win.baseHeight)
                        }
                        return y - activeList.contentY + 3
                    }
                    readonly property real calcTargetX: startX + win.hoveredColIndex * win.baseWidth

                    property real markerX: calcTargetX
                    property real markerY: calcTargetY

                    x: markerX
                    y: markerY
                    opacity: win.mouseHoverActive && !win.keyboardNavActive && win.hoveredRowIndex >= 0 ? 1 : 0
                    visible: opacity > 0.01

                    function retarget(animate) {
                        springEnabled = animate && opacity > 0.05
                        markerX = calcTargetX
                        markerY = calcTargetY
                        if (win.mouseHoverActive) {
                            Qt.callLater(() => {
                                emojiHoverMarker.springEnabled = true
                            })
                        }
                    }

                    onCalcTargetXChanged: retarget(opacity > 0.05)
                    onCalcTargetYChanged: retarget(opacity > 0.05)

                    Connections {
                        target: win
                        function onMouseHoverActiveChanged() {
                            if (win.mouseHoverActive && win.hoveredRowIndex >= 0) {
                                if (emojiHoverMarker.opacity <= 0.05) {
                                    emojiHoverMarker.springEnabled = false
                                    emojiHoverMarker.markerX = emojiHoverMarker.calcTargetX
                                    emojiHoverMarker.markerY = emojiHoverMarker.calcTargetY
                                }
                                Qt.callLater(() => {
                                    emojiHoverMarker.springEnabled = true
                                })
                            }
                        }
                    }

                    Connections {
                        target: emojiHoverMarker.activeList
                        function onContentYChanged() {
                            if (win.mouseHoverActive) {
                                emojiHoverMarker.retarget(true)
                            }
                        }
                    }

                    Behavior on markerX {
                        enabled: emojiHoverMarker.springEnabled
                        SpringAnimation {
                            spring: 4.8
                            damping: 0.72
                            mass: 1.0
                            epsilon: 0.005
                        }
                    }
                    Behavior on markerY {
                        enabled: emojiHoverMarker.springEnabled
                        SpringAnimation {
                            spring: 4.8
                            damping: 0.72
                            mass: 1.0
                            epsilon: 0.005
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }
            }



                // ── Bottom Bar: Category Tabs ────────────────────────────────
                Item {
                    id: bottomBarContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 6

                    // Dismiss search on bottom bar click when search active
                    MouseArea {
                        anchors.fill: parent
                        z: 99
                        enabled: searchPill.searchActive
                        cursorShape: Qt.ArrowCursor
                        onPressed: function(mouse) {
                            searchPill.closeSearch()
                        }
                    }

                    RowLayout {
                        id: bottomBar
                        anchors.fill: parent
                        spacing: 2

                        property int activeCategory: 0
                        property int hoveredCategory: -1

                        onActiveCategoryChanged: {
                            catTabs.scrollTabIntoView(activeCategory)
                        }

                        Timer {
                            id: catHoverClearTimer
                            interval: 40
                            repeat: false
                            onTriggered: bottomBar.hoveredCategory = -1
                        }

                        ListView {
                            id: catTabs
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            orientation: ListView.Horizontal
                            model: (EmojiBackend.categories && EmojiBackend.categories.length > 0) ? EmojiBackend.categories : EmojiData.categories
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

                            // ── Sliding Spring Hover Indicator ───────
                            Rectangle {
                                id: catHoverIndicator
                                parent: catTabs.contentItem
                                z: 0
                                y: 2
                                width: win.baseWidth - 8
                                height: 40
                                radius: 10
                                color: Qt.alpha(tok.palette.fgSurface, 0.08)
                                opacity: (bottomBar.hoveredCategory >= 0 && bottomBar.hoveredCategory !== bottomBar.activeCategory) ? 1 : 0
                                visible: opacity > 0.01

                                property real targetX: bottomBar.hoveredCategory >= 0 ? (bottomBar.hoveredCategory * (win.baseWidth - 2) + 2) : markerX
                                property real markerX: targetX
                                property bool springEnabled: false

                                x: markerX

                                onTargetXChanged: {
                                    if (bottomBar.hoveredCategory >= 0)
                                        markerX = targetX
                                }

                                Behavior on markerX {
                                    enabled: catHoverIndicator.springEnabled
                                    SpringAnimation {
                                        spring: 4.8
                                        damping: 0.72
                                        mass: 1.0
                                        epsilon: 0.005
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                }
                            }

                            // ── Sliding Spring Active Indicator ──────
                            Rectangle {
                                id: catIndicator
                                parent: catTabs.contentItem
                                z: 0
                                y: 2
                                width: win.baseWidth - 8
                                height: 40
                                radius: 10
                                color: tok.palette.primary

                                readonly property real targetX: bottomBar.activeCategory * (win.baseWidth - 2) + 2
                                property real markerX: targetX
                                property bool springEnabled: false

                                x: markerX

                                onTargetXChanged: {
                                    markerX = targetX
                                }

                                Component.onCompleted: {
                                    markerX = targetX
                                    Qt.callLater(() => {
                                        springEnabled = true
                                    })
                                }

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Behavior on markerX {
                                    enabled: catIndicator.springEnabled
                                    SpringAnimation {
                                        spring: 4.8
                                        damping: 0.72
                                        mass: 1.0
                                        epsilon: 0.005
                                    }
                                }
                            }

                            delegate: Item {
                                id: tabDelegate
                                required property var modelData
                                required property int index

                                width: win.baseWidth - 4
                                height: 44
                                z: 1

                                readonly property bool isActive: bottomBar.activeCategory === index

                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -1
                                    text: (modelData && modelData.icon) ? modelData.icon : ""
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 20
                                    color: tabDelegate.isActive
                                        ? tok.palette.fgPrimary
                                        : (bottomBar.hoveredCategory === index ? tok.palette.fgSurface : Qt.alpha(tok.palette.fgSurface, 0.55))
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: tabMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onEntered: {
                                        catHoverClearTimer.stop()
                                        if (catHoverIndicator.opacity <= 0.05) {
                                            catHoverIndicator.springEnabled = false
                                            catHoverIndicator.markerX = index * (win.baseWidth - 2) + 2
                                        }
                                        bottomBar.hoveredCategory = index
                                        Qt.callLater(() => {
                                            catHoverIndicator.springEnabled = true
                                        })
                                    }

                                    onExited: {
                                        catHoverClearTimer.restart()
                                    }

                                    onClicked: {
                                        if (searchPill.searchActive)
                                            searchPill.closeSearch()
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
            id: rowItem
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

                            readonly property bool isKeyboardSelected: win.keyboardNavActive &&
                                                                       (rowItem.index === win.selectedRowIndex) &&
                                                                       (emojiCell.index === win.selectedColIndex)

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: 8
                                color: emojiArea.pressed ? Qt.alpha(tok.palette.fgSurface, 0.18) : "transparent"

                                Behavior on color { ColorAnimation { duration: 120 } }
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

                                onEntered: {
                                    emojiHoverClearTimer.stop()
                                    if (!win.keyboardNavActive) {
                                        win.hoveredRowIndex = rowItem.index
                                        win.hoveredColIndex = emojiCell.index
                                        win.mouseHoverActive = true
                                    }
                                }

                                onExited: {
                                    if (win.hoveredRowIndex === rowItem.index && win.hoveredColIndex === emojiCell.index) {
                                        emojiHoverClearTimer.restart()
                                    }
                                }

                                onClicked: function(mouse) {
                                    let targetDisplayed = emojiCell.emojiDisplayed
                                    let targetBase = emojiCell.emojiStr

                                    if (!targetDisplayed || targetDisplayed.length === 0)
                                        return

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
