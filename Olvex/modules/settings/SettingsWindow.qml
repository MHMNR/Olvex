import "../../components"
import "../../components/controls"
import "../../components/containers"
import ".."
import "network"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.settings
import "ui" as Chrome

Item {
    id: root

    required property ShellScreen screen
    readonly property int rounding: Tokens.rounding.large

    property alias floating: session.floating
    property alias active: session.active
    property alias navExpanded: session.navExpanded
    property alias currentId: session.currentId
    property alias activeSection: session.activeSection

    readonly property bool initialOpeningComplete: true
    readonly property Session session: Session {
        id: session
        rootItem: root
    }
    // Exposed so deep children (like SettingRow) can reliably access the session via dynamic scoping
    // without relying on fragile parent visual tree traversal through Loaders/Flickables.
    readonly property Session globalSettingsSession: session

    signal close

    function activateSearchResult(item) {
        if (!item)
            return;
        const queryText = (searchInput ? searchInput.text : "") || (item.searchQuery || "");
        const rowTitle = item.rowTitle || item.title || "";
        const targetToken = (item.id || "") + " " + (item.title || "") + " " + rowTitle + " " + (item.sectionId || "") + " " + (item.keywords || "") + " " + queryText;
        session.openPageAndSection(item.pageId, item.sectionId, targetToken, queryText, rowTitle, item.id);
        if (searchInput)
            searchInput.text = "";
        session.query = "";
        searchPill.searchExpanded = false;
        if (searchInput)
            searchInput.focus = false;
    }

    // Floating default size: spacious bento (1160x880)
    implicitWidth: root.floating ? 1160 : screen.height * Tokens.sizes.settings.heightMult * Tokens.sizes.settings.ratio
    implicitHeight: root.floating ? 880 : screen.height * Tokens.sizes.settings.heightMult

    // ── surface: glass transparency seamlessly clipped by Hyprland window rounding ──
    StyledRect {
        anchors.fill: parent
        radius: 0
        color: Qt.alpha(Colours.palette.m3surface, Colours.transparencyEnabled ? Math.max(0.72, Math.min(Colours.transparencyBase + 0.16, 0.82)) : (Colours.light ? 0.80 : 0.76))
        border.width: 0

        // ── Subtle ambient depth wash over background blur ─────────────────
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.015 : 0.02)
            Behavior on color { CAnim {} }
        }

        // Ambient depth gradient wash using M3 primary & secondary
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.02 : 0.03) }
                GradientStop { position: 0.40; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.alpha(Colours.palette.m3secondary, Colours.light ? 0.01 : 0.015) }
            }
        }

        // ── top bar ─────────────────────────────────────────────────────
        Item {
            id: topbar

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 76
            z: 130

            readonly property var activeCat: PaneRegistry.getById(session.currentId || session.pageId)
            readonly property color activeAccent: activeCat ? PaneRegistry.accentFor(activeCat) : Colours.palette.m3primary
            readonly property bool inSubpage: session.currentId !== "" || (session.pageId !== "" && !stack.returning)

            // Home Header (Settings icon + Title)
            Item {
                id: homeHeader
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.large * 2
                implicitWidth: homeHeaderRow.implicitWidth
                implicitHeight: homeHeaderRow.implicitHeight
                opacity: !topbar.inSubpage ? 1.0 : 0.0
                visible: opacity > 0.001
                enabled: !topbar.inSubpage

                Behavior on opacity { Anim { type: Anim.FastEffects } }

                RowLayout {
                    id: homeHeaderRow
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.normal

                    MaterialIcon {
                        text: "settings"
                        fill: 1
                        color: Colours.palette.m3primary
                        iconPointSize: Tokens.font.size.large
                    }

                    // title-large shell chrome — regular face
                    StyledText {
                        text: qsTr("Settings")
                        font.weight: Font.Normal
                        font.letterSpacing: -0.15
                        color: Colours.palette.m3onSurface
                        textPointSize: Tokens.font.size.large
                    }
                }
            }

            // Page Sub-Header (Clean Back Button + Category Title)
            Item {
                id: pageHeader
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.large * 2
                implicitWidth: pageHeaderRow.implicitWidth
                implicitHeight: pageHeaderRow.implicitHeight
                opacity: topbar.inSubpage ? 1.0 : 0.0
                visible: opacity > 0.001
                enabled: topbar.inSubpage

                Behavior on opacity { Anim { type: Anim.FastEffects } }

                RowLayout {
                    id: pageHeaderRow
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.normal

                    // Back Button (M3 Circle Button with StateLayer)
                    StyledRect {
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: Tokens.rounding.full
                        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                        border.width: 1
                        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.22)

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "arrow_back"
                            color: Colours.palette.m3onSurface
                            iconPointSize: Tokens.font.size.large
                        }

                        StateLayer {
                            radius: parent.radius
                            onClicked: session.goHome()
                        }
                    }

                    // Category Title
                    StyledText {
                        text: topbar.activeCat ? topbar.activeCat.title : ""
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.2
                        color: Colours.palette.m3onSurface
                        textPointSize: Tokens.font.size.large
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            // right controls: expandable search pill + light/dark toggle + close
            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Tokens.padding.large * 2
                spacing: Tokens.spacing.normal

                // ── Expandable Search Pill (Circle 46px → 320px input field) ──
                StyledRect {
                    id: searchPill

                    property bool searchExpanded: false
                    property int selectedIndex: 0
                    readonly property bool searchActive: searchExpanded || (searchInput && (searchInput.text.length > 0 || searchInput.activeFocus))

                    implicitWidth: searchActive ? 320 : 46
                    implicitHeight: 46
                    radius: Tokens.rounding.full
                    clip: true

                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.22)

                    Behavior on implicitWidth { Anim { type: Anim.DefaultSpatial } }
                    Behavior on color { CAnim {} }

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
                            searchPill.searchExpanded = true;
                            Qt.callLater(() => searchInput.forceActiveFocus());
                        }
                    }

                    // Single Persistent Search Icon (Smoothly transitions position & tint)
                    MaterialIcon {
                        id: searchIcon
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: searchPill.searchActive ? 14 : Math.round((46 - searchIcon.implicitWidth) / 2)
                        text: "search"
                        fill: 1
                        iconPointSize: searchPill.searchActive ? Tokens.font.size.large : Tokens.font.size.larger
                        color: searchInput.activeFocus ? Colours.palette.m3primary : (searchPill.searchActive ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface)

                        Behavior on anchors.leftMargin { Anim { type: Anim.DefaultSpatial } }
                        Behavior on color { CAnim {} }
                    }

                    // Text Input & Placeholder Holder
                    Item {
                        id: inputHolder
                        anchors.left: searchIcon.right
                        anchors.leftMargin: 8
                        anchors.right: clearBtn.left
                        anchors.rightMargin: 4
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        clip: true
                        opacity: searchPill.searchActive ? 1.0 : 0.0
                        visible: opacity > 0.01

                        Behavior on opacity { Anim { type: Anim.FastEffects } }

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colours.palette.m3onSurface
                            selectionColor: Qt.alpha(Colours.palette.m3primary, 0.3)
                            selectedTextColor: Colours.palette.m3onSurface
                            font.family: Tokens.font.family.sans
                            font.pixelSize: Math.max(12, Math.round(Tokens.font.size.normal * 96 / 72))
                            selectByMouse: true
                            cursorVisible: activeFocus

                            onTextChanged: {
                                session.query = text;
                                searchPill.selectedIndex = 0;
                            }

                            Keys.onDownPressed: event => {
                                if (searchFlyout.visible && searchFlyout.resultsCount > 0) {
                                    searchPill.selectedIndex = (searchPill.selectedIndex + 1) % searchFlyout.resultsCount;
                                    searchFlyout.ensureVisible(searchPill.selectedIndex);
                                    event.accepted = true;
                                }
                            }

                            Keys.onUpPressed: event => {
                                if (searchFlyout.visible && searchFlyout.resultsCount > 0) {
                                    searchPill.selectedIndex = (searchPill.selectedIndex - 1 + searchFlyout.resultsCount) % searchFlyout.resultsCount;
                                    searchFlyout.ensureVisible(searchPill.selectedIndex);
                                    event.accepted = true;
                                }
                            }

                            Keys.onReturnPressed: event => {
                                if (searchFlyout.visible && searchFlyout.resultsCount > 0) {
                                    const item = searchFlyout.results[searchPill.selectedIndex] || searchFlyout.results[0];
                                    if (item) {
                                        root.activateSearchResult(item);
                                        event.accepted = true;
                                    }
                                }
                            }

                            Keys.onEnterPressed: event => {
                                if (searchFlyout.visible && searchFlyout.resultsCount > 0) {
                                    const item = searchFlyout.results[searchPill.selectedIndex] || searchFlyout.results[0];
                                    if (item) {
                                        root.activateSearchResult(item);
                                        event.accepted = true;
                                    }
                                }
                            }

                            Keys.onEscapePressed: event => {
                                if (text.length > 0) {
                                    text = "";
                                    event.accepted = true;
                                } else {
                                    searchPill.searchExpanded = false;
                                    focus = false;
                                    event.accepted = true;
                                }
                            }

                            cursorDelegate: Rectangle {
                                width: 2
                                height: searchInput.font.pixelSize * 1.2
                                radius: 1
                                color: Colours.palette.m3primary
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: searchInput.activeFocus
                                    NumberAnimation { to: 1.0; duration: 80 }
                                    PauseAnimation   { duration: 520 }
                                    NumberAnimation { to: 0.0; duration: 80 }
                                    PauseAnimation   { duration: 380 }
                                }
                            }
                        }

                        StyledText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: qsTr("Search settings…")
                            color: Colours.palette.m3outline
                            font.family: Tokens.font.family.sans
                            font.pixelSize: Math.max(12, Math.round(Tokens.font.size.normal * 96 / 72))
                            visible: searchInput.text.length === 0 && !searchInput.inputMethodComposing
                            opacity: searchInput.text.length === 0 ? 0.75 : 0
                            Behavior on opacity { Anim { type: Anim.FastEffects } }
                        }
                    }

                    // Clear / Close Button
                    StyledRect {
                        id: clearBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: Tokens.rounding.full
                        color: clearBtnMa.pressed ? Qt.alpha(Colours.palette.m3onSurface, 0.12) :
                               clearBtnMa.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : "transparent"
                        opacity: searchPill.searchActive ? 1.0 : 0.0
                        visible: opacity > 0.01

                        Behavior on color { CAnim {} }
                        Behavior on opacity { Anim { type: Anim.FastEffects } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            color: Colours.palette.m3onSurfaceVariant
                            iconPointSize: 16
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            id: clearBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (searchInput.text.length > 0) {
                                    searchInput.text = "";
                                    searchInput.forceActiveFocus();
                                } else {
                                    searchPill.searchExpanded = false;
                                    searchInput.focus = false;
                                }
                            }
                        }
                    }
                }

                // 2. Light/Dark Toggle
                StyledRect {
                    implicitWidth: modeRow.implicitWidth + Tokens.padding.large * 2
                    implicitHeight: 46
                    radius: Tokens.rounding.full
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.22)

                    Row {
                        id: modeRow

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Colours.light ? "light_mode" : "dark_mode"
                            fill: 1
                            color: Colours.palette.m3primary
                            iconPointSize: Tokens.font.size.larger
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Colours.light ? qsTr("Light") : qsTr("Dark")
                            font.weight: Font.Normal
                            font.letterSpacing: 0.15
                            color: Colours.palette.m3onSurface
                            textPointSize: Tokens.font.size.small
                        }
                    }

                    StateLayer {
                        radius: parent.radius
                        color: Colours.palette.m3primary
                        onClicked: {
                            const next = Colours.light ? "dark" : "light";
                            GlobalConfig.appearance.themeMode = next;
                            GlobalConfig.save();
                            Colours.setMode(next);
                        }
                    }
                }

                // 3. Close Button
                StyledRect {
                    implicitWidth: 46
                    implicitHeight: 46
                    radius: Tokens.rounding.full
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.22)
                    visible: root.floating

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "close"
                        iconPointSize: Tokens.font.size.larger
                    }

                    StateLayer {
                        radius: parent.radius
                        onClicked: root.close()
                    }
                }
            }
        }

        // ── content stack: M3 Container Transform (card ⇄ page) ─────────
        // Seamless + smooth (NOT sped-up):
        //  · DefaultSpatial ~500ms curve — calm morph, not FastSpatial
        //  · Explicit NumberAnimation, no callLater dead frames
        //  · Morph visible at progress 0 covering card (seamless handoff)
        //  · pageId clear when anim finishes (no close hole / no extra timer)
        Item {
            id: stack

            anchors.top: topbar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            // 0 = home, 1 = page
            property real transformProgress: 0
            readonly property bool transformActive: transformAnim.running
            readonly property bool pageOpen: transformProgress >= 0.999 && !transformAnim.running
            property bool returning: false

            // Frozen start bounds
            property real startX: 0
            property real startY: 0
            property real startW: 1
            property real startH: 1
            property real startRadius: Tokens.rounding.large
            readonly property real endRadius: 0
            // Match bento card fill so progress=0 handoff is invisible
            readonly property color containerColor: Colours.layer(Colours.palette.m3surfaceContainer, 2)

            function mapRange(t, start, end) {
                if (end <= start)
                    return t >= end ? 1 : 0;
                if (t <= start)
                    return 0;
                if (t >= end)
                    return 1;
                return (t - start) / (end - start);
            }

            function lerp(a, b, t) {
                return a + (b - a) * t;
            }

            // M3 shapeMaskProgressThresholds (0.0 → 0.75 on enter, 0.20 → 0.90 on return)
            readonly property real shapeT: returning
                ? mapRange(transformProgress, 0.20, 0.90)
                : mapRange(transformProgress, 0.0, 0.75)

            // M3 Container Transform fadeProgressThresholds:
            // Enter: 0.18 → 0.55 page content smoothly fades in
            // Return: 0.35 → 0.80 page content smoothly fades out
            readonly property real pageContentOpacity: returning
                ? mapRange(transformProgress, 0.35, 0.80)
                : mapRange(transformProgress, 0.18, 0.55)

            readonly property bool showPageContent: pageContentOpacity > 0.001

            // Morph background alpha (cross-fades morph container into the subpage cards + glass window surface)
            // Enter: 0.25 → 0.75 morph container fill gently dissolves into the subpage
            // Return: 0.20 → 0.70 morph container fill gently reforms as subpage collapses
            readonly property real morphBgAlpha: returning
                ? (1.0 - mapRange(transformProgress, 0.20, 0.70))
                : (1.0 - mapRange(transformProgress, 0.25, 0.75))

            // Home (bento grid) fadeProgressThresholds:
            // Enter: 0.00 → 0.18 progress fade out (home grid quickly dissolves so expanding translucent page has clean background)
            // Return: 0.18 → 0.65 progress fade in (home grid smoothly reappears as page collapses back into the tile)
            readonly property real homeOpacity: returning
                ? (1.0 - mapRange(transformProgress, 0.18, 0.65))
                : (1.0 - mapRange(transformProgress, 0.00, 0.18))

            // Origin bento tile: hide only while morph shell covers it.
            // On return, reveal tile UNDER morph before anim ends (no empty pop-in).
            readonly property real originCoverThreshold: 0.14
            readonly property bool morphCoversOrigin: (transformProgress ?? 0) > originCoverThreshold

            function captureStartRect() {
                let r = session.srcRect;
                if (r.width < 8 || r.height < 8) {
                    const w = Math.min(160, stack.width * 0.25);
                    const h = Math.min(100, stack.height * 0.2);
                    r = Qt.rect((stack.width - w) / 2, (stack.height - h) / 2, w, h);
                    session.srcRect = r;
                }
                stack.startX = r.x;
                stack.startY = r.y;
                stack.startW = Math.max(r.width, 1);
                stack.startH = Math.max(r.height, 1);
            }

            // Explicit anim — seamless start (no callLater), full DefaultSpatial ease (not Fast)
            NumberAnimation {
                id: transformAnim

                target: stack
                property: "transformProgress"
                // ~500ms expressive default spatial — smooth, not sped-up
                duration: Tokens.anim.durations.expressiveDefaultSpatial
                easing: Tokens.anim.expressiveDefaultSpatial

                onFinished: {
                    if (stack.transformProgress <= 0.001 && session.currentId === "") {
                        // Tile already visible under morph (progress < cover threshold);
                        // drop shell — no extra timer so elements don't wait
                        session.pageId = "";
                        stack.returning = false;
                    }
                }
            }

            function expandToPage() {
                stack.returning = false;
                stack.captureStartRect();
                transformAnim.stop();
                // Snap to card bounds, start immediately — no deferred frame
                stack.transformProgress = 0;
                transformAnim.from = 0;
                transformAnim.to = 1;
                transformAnim.start();
            }

            function collapseToHome() {
                stack.returning = true;
                // Keep frozen start rect from open (don't re-capture mid-layout)
                transformAnim.stop();
                transformAnim.from = Math.max(stack.transformProgress, 0.001);
                transformAnim.to = 0;
                transformAnim.start();
            }

            Connections {
                target: session
                // Expand first, before heavy page work — seamless click response
                function onCurrentIdChanged() {
                    if (session.currentId !== "")
                        stack.expandToPage();
                    else
                        stack.collapseToHome();
                }
            }

            Component.onCompleted: {
                if (session.currentId !== "" || session.pageId !== "" || (session.active && session.active !== "")) {
                    stack.transformProgress = 1;
                }
            }

            StyledFlickable {
                id: home

                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: bento.height + Tokens.padding.large * 3
                interactive: !stack.transformActive && !stack.pageOpen
                layer.enabled: false
                visible: stack.homeOpacity > 0.001
                opacity: stack.homeOpacity

                Item {
                    id: bento

                    visible: true
                    x: Tokens.padding.large * 2
                    y: Tokens.padding.large * 1.2
                    width: parent.width - Tokens.padding.large * 4
                    readonly property real gap: Tokens.spacing.large
                    // Short tile height — room for icon (36) + gap + title/subtitle without overlap
                    readonly property real rowH: 126
                    readonly property real u: (width - 5 * gap) / 6
                    height: 5 * rowH + 4 * gap

                    Repeater {
                        model: PaneRegistry.categories

                        delegate: Chrome.BentoCard {
                            id: bcard

                            required property var modelData
                            required property int index

                            x: modelData.c * (bento.u + bento.gap)
                            y: modelData.r * (bento.rowH + bento.gap)
                            width: modelData.w * bento.u + (modelData.w - 1) * bento.gap
                            height: modelData.h * bento.rowH + (modelData.h - 1) * bento.gap
                            index: index
                            icon: modelData.icon
                            title: modelData.title
                            subtitle: modelData.sub
                            accent: PaneRegistry.accentFor(modelData)
                            kind: modelData.kind ?? ""
                            tall: (modelData.h ?? 1) >= 2
                            containerHidden: session.pageId === modelData.id
                            animsFrozen: session.pageId === modelData.id
                            onClicked: session.openFrom(bcard, modelData.id, stack)
                        }
                    }
                }
            }

            // ── Transforming container ──────────────────────────────────
            // At progress 0: sits on card bounds — seamless replace of origin tile.
            Rectangle {
                id: morph

                x: stack.lerp(stack.startX, 0, stack.transformProgress)
                y: stack.lerp(stack.startY, 0, stack.transformProgress)
                width: stack.lerp(stack.startW, stack.width, stack.transformProgress)
                height: stack.lerp(stack.startH, stack.height, stack.transformProgress)
                radius: stack.lerp(stack.startRadius, stack.endRadius, stack.shapeT)
                color: Qt.alpha(stack.containerColor, (stack.containerColor.a ?? 1.0) * stack.morphBgAlpha)
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.15 * stack.morphBgAlpha)
                clip: stack.transformActive || stack.transformProgress < 0.999
                // Visible whole time page is open OR mid-transform — includes progress=0
                // (old progress>0.001 hid morph on first frames = dead delay after card hide)
                visible: session.pageId !== ""
                z: 10
                layer.enabled: false

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    // Swallows all clicks/scrolls so they don't hit the bento grid underneath
                }

                Loader {
                    id: pageLoader

                    width: stack.width
                    height: stack.height
                    x: 0
                    y: 0
                    active: session.pageId !== ""
                    // Async: never block expand first frames on page QML compile
                    asynchronous: true
                    opacity: stack.pageContentOpacity
                    visible: stack.showPageContent && status === Loader.Ready

                    function loadPage(id) {
                        if (!id) {
                            source = "";
                            return;
                        }
                        const cat = PaneRegistry.getById(id);
                        if (!cat) {
                            source = "";
                            return;
                        }
                        const url = Qt.resolvedUrl(cat.component);
                        if (source === url && item)
                            return;
                        const pageProps = {
                            "session": session
                        };
                        if (session.activeSection) {
                            pageProps["activeSection"] = session.activeSection;
                        }
                        setSource(url, pageProps);
                    }

                    onLoaded: {
                        if (!item)
                            return;
                        item.anchors.fill = pageLoader;
                        if (item.back !== undefined) {
                            try {
                                item.back.disconnect(session.goHome);
                            } catch (e) {}
                            item.back.connect(session.goHome);
                        }
                    }

                    Connections {
                        target: session
                        function onPageIdChanged() {
                            pageLoader.loadPage(session.pageId);
                        }
                    }

                    Component.onCompleted: {
                        if (session.pageId)
                            loadPage(session.pageId);
                    }
                }

                // Transparent transition shield — blocks clicks mid-animation without falsifying QML child enabled states
                MouseArea {
                    anchors.fill: parent
                    visible: !stack.pageOpen || stack.returning || stack.transformActive
                    hoverEnabled: true
                    preventStealing: true
                    z: 999
                }
            }
        }

        // ── Search Flyout Backdrop (closes flyout on outside click) ─────
        MouseArea {
            id: searchBackdrop
            anchors.fill: parent
            z: 110
            hoverEnabled: true
            visible: (searchFlyout.visible && searchFlyout.opacity > 0.01) || (searchPill && searchPill.searchActive)
            onClicked: {
                if (searchInput)
                    searchInput.text = "";
                session.query = "";
                searchPill.searchExpanded = false;
                if (searchInput)
                    searchInput.focus = false;
            }
        }

        // ── Floating Dropdown Search Flyout ─────────────────────────────
        Chrome.SettingsSearchFlyout {
            id: searchFlyout
            session: root.session
            query: searchInput ? searchInput.text : ""
            selectedIndex: searchPill.selectedIndex
            anchors.top: topbar.bottom
            anchors.topMargin: -8
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.large * 2
            z: 120
            visible: opacity > 0.001
            opacity: (searchInput && searchInput.text.trim().length > 0 && searchPill.searchActive) ? 1.0 : 0.0

            onItemActivated: item => {
                root.activateSearchResult(item);
            }
        }
    }

    focus: true

    Keys.onEscapePressed: event => {
        if (session.modalActive) {
            session.requestCloseModal();
            event.accepted = true;
            return;
        }
        if (wifiConfigMenuRoot && wifiConfigMenuRoot.active) {
            wifiConfigMenuRoot.close();
            event.accepted = true;
            return;
        }
        if (session.currentId !== "") {
            session.goHome();
            event.accepted = true;
        } else {
            root.close();
            event.accepted = true;
        }
    }

    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (session.modalActive) {
                session.requestCloseModal();
                return;
            }
            if (wifiConfigMenuRoot && wifiConfigMenuRoot.active) {
                wifiConfigMenuRoot.close();
                return;
            }
            if (session.currentId !== "")
                session.goHome();
            else
                root.close();
        }
    }

    WifiConfigMenu {
        id: wifiConfigMenuRoot
        session: root.session
        // anchors.fill already set inside WifiConfigMenu via anchors.fill: parent
        // but we need it filling THIS item (the SettingsWindow root), not NetworkDetails
        // Override parent anchor to fill the top-level SettingsWindow item
        parent: root
    }

    Component.onCompleted: {
        // Expose the overlay to session so NetworkWifi can call openFor()
        session.wifiConfigMenu = wifiConfigMenuRoot;
        // Deep-link from bar popout / active prop
        if (session.active && session.active !== "") {
            const cat = PaneRegistry.getById(session.active) || PaneRegistry.getByLabel(session.active);
            if (cat) {
                session.open(cat.id);
                stack.transformProgress = 1;
            }
        }
    }
}
