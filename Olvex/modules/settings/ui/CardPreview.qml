
import ".."
import "."
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Olvex.Config
import qs.services
import qs.utils

// Domain mini-preview for BentoCard.
// Hover: premium micro-motion (scale / lift / stagger) — transform-only, stays in inset.
// Layer-smooth while hovering so scale doesn't look pixelated.
Item {
    id: root

    property string kind: ""
    property color accent: Colours.palette.m3primary
    property bool hovered: false

    // Safe inset — pills/thumbs never kiss card radius (clip lives here)
    readonly property int inset: 4
    clip: true

    // Shared motion helpers
    readonly property var spatial: Anim.DefaultSpatial
    readonly property int staggerMs: 28

    // Pool for filmstrip / carousel — current first, then catalog (cap by max)
    function wallpaperPreviewPaths(maxCount) {
        const limit = maxCount > 0 ? maxCount : 3;
        const _ = Wallpapers.thumbnailUpdateCount;
        Wallpapers.ensureCatalog();
        const out = [];
        const seen = {};
        const push = p => {
            if (!p || seen[p] || out.length >= limit)
                return;
            seen[p] = true;
            out.push(p);
        };
        push(Wallpapers.actualCurrent);
        const statics = Wallpapers.staticEntryObjects || Wallpapers.staticEntries || [];
        for (let i = 0; i < statics.length && out.length < limit; i++)
            push(statics[i] ? statics[i].path : "");
        const lives = Wallpapers.liveEntryObjects || Wallpapers.liveEntries || [];
        for (let i = 0; i < lives.length && out.length < limit; i++)
            push(lives[i] ? lives[i].path : "");
        const all = Wallpapers.entries || [];
        for (let i = 0; i < all.length && out.length < limit; i++)
            push(all[i] ? all[i].path : "");
        return out;
    }

    function wallpaperImageSource(path) {
        const p = Wallpapers.displayPathFor(path);
        if (!p)
            return "";
        return p.startsWith("file:") ? p : ("file://" + p);
    }

    // Fisher–Yates shuffle copy for random slideshow order
    function shufflePaths(arr) {
        const a = arr.slice();
        for (let i = a.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const t = a[i];
            a[i] = a[j];
            a[j] = t;
        }
        return a;
    }

    Loader {
        id: previewLoader

        anchors.fill: parent
        anchors.margins: root.inset
        active: root.kind !== "" && root.kind !== "sound" && root.kind !== "power" && root.width > 8
        asynchronous: true
        sourceComponent: {
            switch (root.kind) {
            case "appearance":
                return cAppearance;
            case "display":
                return cDisplay;
            case "wallpaper":
                return cWallpaper;
            case "network":
                return cNetwork;
            case "notifications":
            case "notifs":
                return cNotifs;
            case "bar":
            case "taskbar":
                return cBar;
            case "panels":
                return cPanels;
            case "lock":
                return cLock;
            case "about":
                return cAbout;
            case "system":
                return cSystem;
            default:
                return null;
            }
        }
    }

    // Shared pill — no hover lift (lift clipped top/side of CardPreview)
    component PreviewPill: Rectangle {
        id: pill

        property string icon: ""
        property string label: ""
        property color fg: root.accent
        property color bg: Qt.alpha(pill.fg, 0.10)
        property int maxLabelW: 72
        property int stagger: 0
        // Cap to parent width when available so dual rows never overflow
        property real maxWidth: parent && parent.width > 0 ? parent.width : 200
        readonly property color effectiveFg: root.hovered ? Colours.palette.m3onPrimary : pill.fg

        readonly property real contentW: row.implicitWidth + Tokens.padding.normal * 2
        implicitWidth: Math.min(contentW, maxWidth, maxLabelW + (icon !== "" ? 22 : 0) + Tokens.padding.normal * 2)
        implicitHeight: 22
        radius: height / 2
        color: root.hovered ? Qt.alpha(Colours.palette.m3onPrimary, 0.18) : pill.bg
        clip: false
        antialiasing: true
        smooth: true
        opacity: 1

        Behavior on color {
            CAnim {}
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 4

            MaterialIcon {
                visible: pill.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: pill.icon
                fill: 1
                color: pill.effectiveFg
                iconPointSize: Tokens.font.size.smaller

                Behavior on color {
                    CAnim {}
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                color: pill.effectiveFg
                font.weight: Font.Normal
                font.letterSpacing: 0.1
                textPointSize: Tokens.font.size.small
                elide: Text.ElideRight
                width: Math.min(implicitWidth, pill.maxLabelW)

                Behavior on color {
                    CAnim {}
                }
            }
        }
    }

    Component {
        id: cAppearance

        Item {
            anchors.fill: parent

            // Upper-right overlapping color circles (Image 1)
            Item {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 2
                width: 150
                height: 150

                // Circle 1: cyan
                Rectangle {
                    x: 6
                    y: 20
                    width: 90
                    height: 90
                    radius: 45
                    color: "#74b9cc"
                    opacity: root.hovered ? 0.85 : 0.70
                    antialiasing: true
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                }

                // Circle 2: lavender
                Rectangle {
                    x: 48
                    y: 6
                    width: 84
                    height: 84
                    radius: 42
                    color: "#b09ccc"
                    opacity: root.hovered ? 0.85 : 0.70
                    antialiasing: true
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                }

                // Circle 3: deep teal
                Rectangle {
                    x: 74
                    y: 56
                    width: 68
                    height: 68
                    radius: 34
                    color: "#1c5c68"
                    opacity: root.hovered ? 0.90 : 0.80
                    antialiasing: true
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                }

                // Circle 4: grey / slate overlay
                Rectangle {
                    x: 30
                    y: 68
                    width: 70
                    height: 70
                    radius: 35
                    color: "#a4b8bf"
                    opacity: root.hovered ? 0.90 : 0.80
                    antialiasing: true
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                }
            }

            // Bottom-right standalone "Aa"
            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.bottom: parent.bottom
                text: "Aa"
                font.family: Tokens.font.family.sans
                font.weight: Font.Normal
                color: root.hovered ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                textPointSize: 34

                Behavior on color {
                    CAnim {}
                }
            }
        }
    }

    Component {
        id: cWallpaper

        Item {
            id: wpRoot

            // Carousel pool — up to 10 walls, shuffled order for random slideshow
            readonly property var catalogPaths: root.wallpaperPreviewPaths(10)
            property var carouselPaths: []
            property int slideIndex: 0

            readonly property string heroPath: {
                if (carouselPaths.length === 0)
                    return "";
                return carouselPaths[slideIndex % carouselPaths.length] || "";
            }
            readonly property string heroSrc: heroPath ? root.wallpaperImageSource(heroPath) : ""
            readonly property bool heroLive: heroPath ? Wallpapers.isVideoPath(heroPath) : false
            readonly property string heroName: {
                if (!heroPath)
                    return "";
                const parts = heroPath.split("/");
                const name = parts[parts.length - 1] || "";
                return name.replace(/\.[^.]+$/, "");
            }
            readonly property int slideCount: carouselPaths.length

            // Soft breath for ambient chrome only
            property real breath: 0

            SequentialAnimation on breath {
                loops: Animation.Infinite
                running: root.visible
                NumberAnimation {
                    from: 0
                    to: 1
                    duration: 2800
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 1
                    to: 0
                    duration: 2800
                    easing.type: Easing.InOutSine
                }
            }

            function rebuildCarousel() {
                const pool = root.wallpaperPreviewPaths(10);
                if (pool.length === 0) {
                    carouselPaths = [];
                    slideIndex = 0;
                    return;
                }
                // Keep current wallpaper first, shuffle the rest for random feel
                const cur = Wallpapers.actualCurrent;
                const rest = pool.filter(p => p !== cur);
                const shuffled = root.shufflePaths(rest);
                carouselPaths = (cur && pool.indexOf(cur) >= 0) ? [cur].concat(shuffled) : shuffled.length ? shuffled : pool.slice();
                // Prefer current as start
                if (cur) {
                    const idx = carouselPaths.indexOf(cur);
                    slideIndex = idx >= 0 ? idx : 0;
                } else {
                    slideIndex = 0;
                }
                ensureThumbs();
            }

            function ensureThumbs() {
                for (let i = 0; i < carouselPaths.length; i++) {
                    if (Wallpapers.isVideoPath(carouselPaths[i]))
                        Wallpapers.queueThumbnail(carouselPaths[i], i === slideIndex);
                }
            }

            function advanceRandom() {
                const n = carouselPaths.length;
                if (n <= 1)
                    return;
                // Random next ≠ current
                let next = Math.floor(Math.random() * n);
                if (next === slideIndex)
                    next = (slideIndex + 1 + Math.floor(Math.random() * (n - 1))) % n;
                slideIndex = next;
                // Prefetch neighbors
                const prev = (slideIndex - 1 + n) % n;
                const aft = (slideIndex + 1) % n;
                [prev, slideIndex, aft].forEach(i => {
                    const p = carouselPaths[i];
                    if (p && Wallpapers.isVideoPath(p))
                        Wallpapers.queueThumbnail(p, i === slideIndex);
                });
            }

            Component.onCompleted: {
                Wallpapers.ensureCatalog();
                rebuildCarousel();
            }

            Connections {
                target: Wallpapers
                function onThumbnailUpdateCountChanged() {
                    wpRoot.ensureThumbs();
                }
                function onActualCurrentChanged() {
                    wpRoot.rebuildCarousel();
                }
            }

            // Rebuild when catalog grows (paths binding may change)
            onCatalogPathsChanged: rebuildCarousel()

            // Auto slideshow — random next wall every few seconds
            Timer {
                id: slideTimer
                interval: root.hovered ? 5000 : 3200
                running: wpRoot.slideCount > 1 && root.visible
                repeat: true
                onTriggered: wpRoot.advanceRandom()
            }

            // ── Carousel stage (no grey underlay — image only) ──
            StyledClippingRect {
                id: heroFrame

                z: 1
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: dotsRow.top
                anchors.bottomMargin: 8
                radius: Tokens.rounding.large
                color: "transparent"
                scale: root.hovered ? 1.015 : 1
                transformOrigin: Item.Center

                Behavior on scale {
                    SpringAnimation {
                        spring: 4.2
                        damping: 0.72
                        mass: 1
                        epsilon: 0.001
                    }
                }

                // Horizontal path carousel — center card large, sides peek
                PathView {
                    id: carousel

                    anchors.fill: parent
                    model: wpRoot.carouselPaths
                    pathItemCount: Math.min(3, Math.max(1, wpRoot.slideCount))
                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    snapMode: PathView.SnapToItem
                    interactive: wpRoot.slideCount > 1
                    highlightMoveDuration: Tokens.anim.durations.expressiveDefaultSpatial
                    // Sync from slideIndex (timer / dots); swipe writes back on settle
                    currentIndex: wpRoot.slideIndex
                    onMovementEnded: {
                        if (currentIndex !== wpRoot.slideIndex)
                            wpRoot.slideIndex = currentIndex;
                        slideTimer.restart();
                    }

                    path: Path {
                        // Left peek
                        startX: -carousel.width * 0.28
                        startY: carousel.height / 2
                        PathAttribute {
                            name: "cardScale"
                            value: 0.78
                        }
                        PathAttribute {
                            name: "cardOpacity"
                            value: 0.35
                        }
                        PathAttribute {
                            name: "cardZ"
                            value: 0
                        }
                        // Center hero
                        PathLine {
                            x: carousel.width / 2
                            y: carousel.height / 2
                        }
                        PathAttribute {
                            name: "cardScale"
                            value: 1.0
                        }
                        PathAttribute {
                            name: "cardOpacity"
                            value: 1.0
                        }
                        PathAttribute {
                            name: "cardZ"
                            value: 2
                        }
                        // Right peek
                        PathLine {
                            x: carousel.width * 1.28
                            y: carousel.height / 2
                        }
                        PathAttribute {
                            name: "cardScale"
                            value: 0.78
                        }
                        PathAttribute {
                            name: "cardOpacity"
                            value: 0.35
                        }
                        PathAttribute {
                            name: "cardZ"
                            value: 0
                        }
                    }

                    delegate: Item {
                        id: card

                        required property var modelData
                        required property int index

                        // Fill stage — no inset grey mat around the image
                        width: carousel.width
                        height: carousel.height
                        scale: PathView.cardScale ?? 1
                        opacity: PathView.cardOpacity ?? 1
                        z: PathView.cardZ ?? 0

                        readonly property string wallPath: modelData || ""
                        readonly property string imgSrc: wallPath ? root.wallpaperImageSource(wallPath) : ""
                        readonly property bool isLive: wallPath ? Wallpapers.isVideoPath(wallPath) : false
                        readonly property bool isCenter: PathView.isCurrentItem

                        StyledClippingRect {
                            anchors.fill: parent
                            radius: Tokens.rounding.large
                            color: "transparent"

                            Image {
                                anchors.fill: parent
                                source: card.imgSrc
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                mipmap: true
                                antialiasing: true
                                sourceSize: Qt.size(Math.round(Math.max(width, 1) * 1.5), Math.round(Math.max(height, 1) * 1.5))
                                opacity: status === Image.Ready ? 1 : 0

                                Behavior on opacity {
                                    Anim {
                                        type: Anim.FastEffects
                                    }
                                }
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: !card.imgSrc
                                text: card.isLive ? "movie" : "image"
                                color: Colours.palette.m3outline
                                iconPointSize: Tokens.font.size.large
                            }
                        }
                    }
                }

                // Filename chip
                Rectangle {
                    z: 4
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    visible: !!wpRoot.heroSrc && wpRoot.heroName.length > 0
                    implicitWidth: Math.min(nameRow.implicitWidth + 16, parent.width * 0.7)
                    implicitHeight: 22
                    radius: height / 2
                    color: Qt.alpha("#000000", 0.45)

                    Row {
                        id: nameRow
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        width: parent.width - 12
                        clip: true

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "wallpaper"
                            fill: 1
                            color: "#ffffff"
                            iconPointSize: Tokens.font.size.smaller
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width - 18)
                            text: wpRoot.heroName
                            color: "#ffffff"
                            elide: Text.ElideRight
                            font.weight: Font.Medium
                            textPointSize: Tokens.font.size.small
                        }
                    }
                }

                // Live pill
                Rectangle {
                    z: 4
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    visible: wpRoot.heroLive && !!wpRoot.heroSrc
                    implicitWidth: liveRow.implicitWidth + 14
                    implicitHeight: 22
                    radius: height / 2
                    color: Qt.alpha("#000000", 0.48)

                    Row {
                        id: liveRow
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: Colours.palette.m3error
                            opacity: 0.55 + wpRoot.breath * 0.45
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Live")
                            color: "#ffffff"
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.small
                        }
                    }
                }

                // Empty catalog
                MaterialIcon {
                    anchors.centerIn: parent
                    z: 4
                    visible: wpRoot.slideCount === 0
                    text: "wallpaper"
                    color: Colours.palette.m3outline
                    iconPointSize: Tokens.font.size.extraLarge
                    opacity: 0.7 + wpRoot.breath * 0.3
                }
            }

            // ── Dot indicators (carousel position) ──
            Row {
                id: dotsRow

                z: 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                spacing: 5
                height: 10
                visible: wpRoot.slideCount > 1

                Repeater {
                    model: Math.min(wpRoot.slideCount, 8)

                    delegate: Rectangle {
                        required property int index
                        width: index === (wpRoot.slideIndex % Math.min(wpRoot.slideCount, 8)) ? 14 : 6
                        height: 6
                        radius: 3
                        color: index === (wpRoot.slideIndex % Math.min(wpRoot.slideCount, 8))
                            ? root.accent
                            : Qt.alpha(root.accent, 0.28)

                        Behavior on width {
                            Anim {
                                type: Anim.FastSpatial
                            }
                        }
                        Behavior on color {
                            CAnim {}
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wpRoot.slideIndex = index;
                                slideTimer.restart();
                            }
                        }
                    }
                }
            }
        }
    }


    Component {
        id: cSound

        Item {
            anchors.fill: parent

            Item {
                anchors.left: parent.left
                anchors.top: parent.top
                width: 38
                height: 38

                CircularProgress {
                    anchors.fill: parent
                    value: (typeof Audio !== "undefined" && Audio.volume !== undefined) ? Audio.volume : 0.65
                    strokeWidth: 4
                    fgColour: root.accent
                    bgColour: Qt.alpha(root.accent, 0.20)
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "volume_up"
                    fill: 1
                    iconPointSize: 16
                    color: Colours.palette.m3onSurface
                }
            }
        }
    }

    Component {
        id: cNetwork

        Item {
            anchors.fill: parent

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: [14, 22, 30, 40]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        anchors.bottom: parent ? parent.bottom : undefined
                        width: 5
                        height: modelData
                        radius: 2.5
                        color: index < 3
                            ? (root.hovered ? Colours.palette.m3onPrimary : root.accent)
                            : Qt.alpha(root.hovered ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface, root.hovered ? 0.30 : 0.16)
                        opacity: root.hovered ? 1.0 : (index < 3 ? 0.90 : 1.0)

                        Behavior on color { CAnim {} }
                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                    }
                }
            }
        }
    }

    Component {
        id: cNotifs

        Item {
            anchors.fill: parent

            // Stacked floating toast notifications (Reference 2nd Pic)
            Item {
                anchors.right: parent.right
                anchors.top: parent.top
                width: 92
                height: 38

                // Background dimmed toast
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 74
                    height: 26
                    radius: 9
                    color: Qt.alpha(root.hovered ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface, 0.12)

                    Behavior on color { CAnim {} }
                }

                // Foreground active toast card
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    width: 84
                    height: 30
                    radius: 10
                    color: root.hovered ? Qt.alpha(Colours.palette.m3onPrimary, 0.22) : Qt.alpha(root.accent, 0.25)

                    Behavior on color { CAnim {} }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 6

                        // Avatar / icon dot
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            height: 14
                            radius: 7
                            color: Qt.alpha(root.hovered ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface, 0.65)

                            Behavior on color { CAnim {} }
                        }

                        // Message lines
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Rectangle {
                                width: 40
                                height: 3.5
                                radius: 1.75
                                color: Qt.alpha(root.hovered ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface, 0.85)

                                Behavior on color { CAnim {} }
                            }

                            Rectangle {
                                width: 24
                                height: 3
                                radius: 1.5
                                color: Qt.alpha(root.hovered ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface, 0.45)

                                Behavior on color { CAnim {} }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cBar

        Item {
            anchors.fill: parent

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 36
                width: 158
                radius: 18
                color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, root.hovered ? 0.78 : 0.58)

                Behavior on color { CAnim {} }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: ["#74b9cc", "#b09ccc", "#9fb0b6", "#445a61", "#445a61"]

                        delegate: Rectangle {
                            required property var modelData
                            width: 22
                            height: 22
                            radius: 6
                            color: modelData
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cPanels

        Item {
            anchors.fill: parent

            Grid {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 2
                columns: 2
                spacing: 4

                Repeater {
                    model: 4

                    delegate: Rectangle {
                        required property int index
                        readonly property color fg: root.hovered ? Colours.palette.m3onPrimary : root.accent

                        width: 15
                        height: 15
                        radius: 4.5
                        color: index === 0 ? fg : Qt.alpha(fg, 0.35)

                        Behavior on color { CAnim {} }
                    }
                }
            }
        }
    }

    Component {
        id: cPower

        Item {
            anchors.fill: parent

            Item {
                anchors.left: parent.left
                anchors.top: parent.top
                width: 38
                height: 38

                CircularProgress {
                    anchors.fill: parent
                    value: (typeof Battery !== "undefined" && Battery.percent !== undefined) ? (Battery.percent / 100.0) : 0.72
                    strokeWidth: 4
                    fgColour: root.accent
                    bgColour: Qt.alpha(root.accent, 0.20)
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "battery_charging_full"
                    fill: 1
                    iconPointSize: 16
                    color: Colours.palette.m3onSurface
                }
            }
        }
    }

    Component {
        id: cLock

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small

            PreviewPill {
                anchors.verticalCenter: parent.verticalCenter
                label: qsTr("Card")
                fg: root.accent
                bg: Qt.alpha(root.accent, 0.16)
                maxLabelW: 36
                maxWidth: 72
            }

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: root.hovered ? "lock_open" : "lock"
                fill: 1
                color: root.accent
                iconPointSize: Tokens.font.size.large
                // Translate only — no scale (sharp + no edge clip)
                transform: Translate {
                    y: root.hovered ? -2 : 0

                    Behavior on y {
                        Anim {
                            type: Anim.DefaultSpatial
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cAbout

        Item {
            // Two pills only — short tile can't fit 3×24 without top clip glitch
            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                width: parent.width

                PreviewPill {
                    anchors.right: parent.right
                    icon: ""
                    label: {
                        const n = SysInfo.osName || qsTr("Arch Linux");
                        if (n.length > 14)
                            return n.split(" ")[0] || n;
                        return n;
                    }
                    fg: Colours.palette.m3onSurfaceVariant
                    bg: Qt.alpha(Colours.palette.m3onSurface, 0.10)
                    maxLabelW: 110
                    maxWidth: parent.width
                }

                PreviewPill {
                    anchors.right: parent.right
                    icon: ""
                    label: SysInfo.wm || "Hyprland"
                    fg: Colours.palette.m3onSurfaceVariant
                    bg: Qt.alpha(Colours.palette.m3onSurface, 0.10)
                    maxLabelW: 110
                    maxWidth: parent.width
                }
            }
        }
    }

    Component {
        id: cDisplay

        Item {
            anchors.fill: parent

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: DisplayManager.monitors.length > 0 ? DisplayManager.monitors : [ { name: "eDP-1", refreshRate: 144 } ]

                    delegate: StyledRect {
                        required property var modelData
                        required property int index

                        implicitWidth: index === 0 ? 54 : 44
                        implicitHeight: index === 0 ? 36 : 30
                        radius: Tokens.rounding.small
                        color: index === 0 ? Qt.alpha(root.accent, 0.22) : Qt.alpha(Colours.palette.m3onSurface, 0.1)
                        border.width: index === 0 ? 1.5 : 1
                        border.color: index === 0 ? root.accent : Qt.alpha(Colours.palette.m3outlineVariant, 0.5)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: parent.parent.modelData.name || "DP-1"
                                textPointSize: Tokens.font.size.smaller - 3
                                font.weight: Font.Bold
                                color: parent.parent.index === 0 ? root.accent : Colours.palette.m3onSurface
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: `${Math.round(parent.parent.modelData.refreshRate || 60)}Hz`
                                textPointSize: Tokens.font.size.smaller - 4
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cSystem

        Item {
            anchors.fill: parent

            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                width: 148

                Repeater {
                    model: [0.70, 0.45, 0.85]

                    delegate: Item {
                        required property var modelData
                        required property int index

                        width: parent.width
                        height: 14

                        readonly property real fill: root.hovered ? Math.min(1, modelData + 0.05) : modelData

                        // Track background
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Qt.alpha(root.hovered ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface, root.hovered ? 0.26 : 0.14)

                            Behavior on color { CAnim {} }

                            // Active filled track
                            Rectangle {
                                width: parent.width * parent.parent.fill
                                height: parent.height
                                radius: parent.radius
                                color: root.hovered ? Colours.palette.m3onPrimary : root.accent

                                Behavior on color { CAnim {} }

                                Behavior on width {
                                    Anim {
                                        type: Anim.DefaultSpatial
                                        duration: Tokens.anim.durations.expressiveDefaultSpatial + index * root.staggerMs
                                    }
                                }
                            }
                        }

                        // Circular slider thumb dot
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, parent.width * parent.fill - width / 2))
                            width: 12
                            height: 12
                            radius: 6
                            color: root.hovered ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

                            Behavior on color { CAnim {} }

                            Behavior on x {
                                Anim {
                                    type: Anim.DefaultSpatial
                                    duration: Tokens.anim.durations.expressiveDefaultSpatial + index * root.staggerMs
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
