pragma ComponentBehavior: Bound

import "../../components"
import "../../components/controls"
import "../../components/containers"
import ".."
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

    readonly property bool initialOpeningComplete: true
    readonly property Session session: Session {
        id: session
        rootItem: root
    }

    signal close

    // Floating default size: spacious bento (1160x880)
    implicitWidth: root.floating ? 1160 : screen.height * Tokens.sizes.settings.heightMult * Tokens.sizes.settings.ratio
    implicitHeight: root.floating ? 880 : screen.height * Tokens.sizes.settings.heightMult

    // ── surface: opaque palette (not tPalette glass) ───────────────────
    StyledRect {
        anchors.fill: parent
        radius: 0
        color: Colours.palette.m3surface

        // ── top bar ─────────────────────────────────────────────────────
        Item {
            id: topbar

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 76
            z: 10

            RowLayout {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.large * 2
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

            // search (Lockscreen cardstyle input field)
            Rectangle {
                id: search

                anchors.centerIn: parent
                implicitWidth: 380
                implicitHeight: 46
                radius: height / 2
                color: searchInput.activeFocus 
                    ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                    : (searchHover.containsMouse ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 1) : Colours.palette.m3surfaceContainerHigh)

                border.color: searchInput.activeFocus
                    ? Colours.palette.m3primary
                    : (searchHover.containsMouse ? Qt.alpha(Colours.palette.m3outline, 0.6) : Qt.alpha(Colours.palette.m3outlineVariant, 0.35))
                border.width: searchInput.activeFocus ? 2 : 1

                scale: 1.0

                Behavior on color { CAnim {} }
                Behavior on border.color { ColorAnimation { duration: 200 } }
                Behavior on border.width { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                HoverHandler {
                    id: searchHover
                    cursorShape: Qt.IBeamCursor
                }

                TapHandler {
                    onTapped: {
                        searchInput.forceActiveFocus();
                        search.scale = 0.98;
                        pulseTimer.restart();
                    }
                }

                Timer {
                    id: pulseTimer
                    interval: 120
                    onTriggered: search.scale = 1.0
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 10
                    spacing: Tokens.spacing.normal

                    MaterialIcon {
                        id: searchIcon
                        Layout.alignment: Qt.AlignVCenter
                        text: "search"
                        color: searchInput.activeFocus ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        iconPointSize: Tokens.font.size.large
                        verticalAlignment: Text.AlignVCenter

                        Behavior on color { CAnim {} }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

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
                            onTextChanged: session.query = text

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

                    StyledRect {
                        id: clearBtn
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
                        visible: searchInput.text.length > 0
                        opacity: searchInput.text.length > 0 ? 1 : 0
                        Behavior on opacity { Anim { type: Anim.FastEffects } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            color: Colours.palette.m3onSurfaceVariant
                            iconPointSize: 14
                            verticalAlignment: Text.AlignVCenter
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3primary
                            onClicked: {
                                searchInput.text = "";
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // light/dark toggle + close
            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Tokens.padding.large * 2
                spacing: Tokens.spacing.normal

                StyledRect {
                    implicitWidth: modeRow.implicitWidth + Tokens.padding.large * 2
                    implicitHeight: 46
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3surfaceContainerHigh

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

                StyledRect {
                    implicitWidth: 46
                    implicitHeight: 46
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3surfaceContainerHigh
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
            readonly property color containerColor: Colours.palette.m3surfaceContainer

            function mapRange(t: real, start: real, end: real): real {
                if (end <= start)
                    return t >= end ? 1 : 0;
                if (t <= start)
                    return 0;
                if (t >= end)
                    return 1;
                return (t - start) / (end - start);
            }

            function lerp(a: real, b: real, t: real): real {
                return a + (b - a) * t;
            }

            // M3 shapeMaskProgressThresholds (0.0 → 0.75 on enter, 0.20 → 0.90 on return)
            readonly property real shapeT: returning
                ? mapRange(transformProgress, 0.20, 0.90)
                : mapRange(transformProgress, 0.0, 0.75)

            // M3 Container Transform fadeProgressThresholds:
            // Enter: 0.10 → 0.40 progress fade in
            // Return: 0.45 → 0.85 progress fade out
            readonly property real pageContentOpacity: returning
                ? mapRange(transformProgress, 0.45, 0.85)
                : mapRange(transformProgress, 0.10, 0.40)

            readonly property bool showPageContent: pageContentOpacity > 0.001

            // Origin bento tile: hide only while morph shell covers it.
            // On return, reveal tile UNDER morph before anim ends (no empty pop-in).
            readonly property real originCoverThreshold: 0.14
            readonly property bool morphCoversOrigin: (transformProgress ?? 0) > originCoverThreshold

            function captureStartRect(): void {
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

            function expandToPage(): void {
                stack.returning = false;
                stack.captureStartRect();
                transformAnim.stop();
                // Snap to card bounds, start immediately — no deferred frame
                stack.transformProgress = 0;
                transformAnim.from = 0;
                transformAnim.to = 1;
                transformAnim.start();
            }

            function collapseToHome(): void {
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
                function onCurrentIdChanged(): void {
                    if (session.currentId !== "")
                        stack.expandToPage();
                    else
                        stack.collapseToHome();
                }
            }

            Flickable {
                id: home

                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: (session.query === "" ? bento.height : resultsCol.height) + Tokens.padding.large * 3
                boundsBehavior: Flickable.StopAtBounds
                interactive: !stack.transformActive && !stack.pageOpen
                // No layer.enable — first-frame layer capture was open hitch/delay
                layer.enabled: false
                // Keep home painted under morph (card-sized shell covers origin)
                visible: true
                opacity: 1

                Item {
                    id: bento

                    visible: session.query === ""
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

                Column {
                    id: resultsCol

                    visible: session.query !== ""
                    x: Tokens.padding.large * 2
                    y: Tokens.padding.large * 1.2
                    width: parent.width - Tokens.padding.large * 4
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: PaneRegistry.categories.filter(c => session.matches(c))

                        delegate: StyledRect {
                            id: resultRow

                            required property var modelData

                            width: resultsCol.width
                            implicitHeight: 66
                            radius: Tokens.rounding.normal
                            color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                            StyledRect {
                                id: rIcon

                                anchors.left: parent.left
                                anchors.leftMargin: Tokens.padding.large
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: 44
                                implicitHeight: 44
                                radius: Tokens.rounding.normal
                                color: Qt.alpha(PaneRegistry.accentFor(resultRow.modelData), 0.2)

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: resultRow.modelData.icon
                                    fill: 1
                                    color: PaneRegistry.accentFor(resultRow.modelData)
                                    iconPointSize: Tokens.font.size.large
                                }
                            }

                            Column {
                                anchors.left: rIcon.right
                                anchors.leftMargin: Tokens.spacing.normal
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                StyledText {
                                    text: resultRow.modelData.title
                                    font.weight: Font.Normal
                                    font.letterSpacing: -0.05
                                    color: Colours.palette.m3onSurface
                                    textPointSize: Tokens.font.size.larger
                                }
                                StyledText {
                                    text: resultRow.modelData.sub
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.Normal
                                    font.letterSpacing: 0.1
                                    textPointSize: Tokens.font.size.small
                                }
                            }

                            MaterialIcon {
                                anchors.right: parent.right
                                anchors.rightMargin: Tokens.padding.large
                                anchors.verticalCenter: parent.verticalCenter
                                text: "chevron_right"
                                color: Colours.palette.m3onSurfaceVariant
                                iconPointSize: Tokens.font.size.large
                            }

                            StateLayer {
                                radius: parent.radius
                                color: PaneRegistry.accentFor(resultRow.modelData)
                                onClicked: {
                                    session.openFrom(resultRow, resultRow.modelData.id, stack);
                                    searchInput.text = "";
                                }
                            }
                        }
                    }

                    Item {
                        visible: PaneRegistry.categories.filter(c => session.matches(c)).length === 0
                        width: parent.width
                        height: 200

                        Column {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.normal

                            MaterialIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "search_off"
                                color: Colours.palette.m3outlineVariant
                                iconPointSize: Tokens.font.size.extraLarge
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("No settings match \"%1\"").arg(session.query)
                                color: Colours.palette.m3onSurfaceVariant
                                font.weight: Font.Normal
                                font.letterSpacing: 0.05
                                textPointSize: Tokens.font.size.larger
                            }
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
                color: stack.containerColor
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
                    enabled: stack.pageOpen && !stack.returning

                    function loadPage(id: string): void {
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
                        setSource(url, {
                            "session": session
                        });
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
                        function onPageIdChanged(): void {
                            pageLoader.loadPage(session.pageId);
                        }
                    }

                    Component.onCompleted: {
                        if (session.pageId)
                            loadPage(session.pageId);
                    }
                }
            }
        }
    }

    focus: true

    Keys.onEscapePressed: event => {
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
            if (session.currentId !== "")
                session.goHome();
            else
                root.close();
        }
    }

    Component.onCompleted: {
        // Deep-link from bar popout / active prop
        if (session.active && session.active !== "") {
            const cat = PaneRegistry.getById(session.active) || PaneRegistry.getByLabel(session.active);
            if (cat)
                session.open(cat.id);
        }
    }
}
