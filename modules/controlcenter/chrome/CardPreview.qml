pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Olvex.Config
import qs.components
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
    readonly property int inset: Tokens.spacing.normal + 4 // ~14–16
    clip: true

    // Always layer-smooth — scale stays crisp (no hover enable pop)
    layer.enabled: true
    layer.smooth: true

    // Shared motion helpers
    readonly property var spatial: Anim.DefaultSpatial
    readonly property int staggerMs: 28

    // Pool for filmstrip / carousel — current first, then catalog (cap by max)
    function wallpaperPreviewPaths(maxCount: int): var {
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
            push(statics[i]?.path);
        const lives = Wallpapers.liveEntryObjects || Wallpapers.liveEntries || [];
        for (let i = 0; i < lives.length && out.length < limit; i++)
            push(lives[i]?.path);
        const all = Wallpapers.entries || [];
        for (let i = 0; i < all.length && out.length < limit; i++)
            push(all[i]?.path);
        return out;
    }

    function wallpaperImageSource(path: string): string {
        const p = Wallpapers.displayPathFor(path);
        if (!p)
            return "";
        return p.startsWith("file:") ? p : ("file://" + p);
    }

    // Fisher–Yates shuffle copy for random slideshow order
    function shufflePaths(arr: var): var {
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
        active: root.kind !== "" && root.width > 8
        asynchronous: true
        layer.enabled: true
        layer.smooth: true
        sourceComponent: {
            switch (root.kind) {
            case "appearance":
                return cAppearance;
            case "wallpaper":
                return cWallpaper;
            case "sound":
                return cSound;
            case "network":
                return cNetwork;
            case "notifications":
                return cNotifs;
            case "bar":
                return cBar;
            case "panels":
                return cPanels;
            case "power":
                return cPower;
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
        property color bg: Qt.alpha(root.accent, 0.16)
        property int maxLabelW: 72
        property int stagger: 0
        // Cap to parent width when available so dual rows never overflow
        property real maxWidth: parent && parent.width > 0 ? parent.width : 200

        readonly property real contentW: row.implicitWidth + Tokens.padding.normal * 2
        implicitWidth: Math.min(contentW, maxWidth, maxLabelW + (icon !== "" ? 22 : 0) + Tokens.padding.normal * 2)
        implicitHeight: 22
        radius: height / 2
        color: root.hovered ? Qt.alpha(pill.fg, 0.22) : pill.bg
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
                color: pill.fg
                iconPointSize: Tokens.font.size.smaller
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                color: pill.fg
                font.weight: Font.Normal
                font.letterSpacing: 0.1
                textPointSize: Tokens.font.size.small
                elide: Text.ElideRight
                width: Math.min(implicitWidth, pill.maxLabelW)
            }
        }
    }

    Component {
        id: cAppearance

        // Dense palette stage — fills tall narrow hero, not empty void
        Item {
            // Soft overlapping color orbs (alive mid-stage)
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -6
                width: Math.min(parent.width * 0.92, 120)
                height: width * 0.72

                Repeater {
                    model: [{
                            c: Colours.palette.m3primary,
                            x: 0.08,
                            y: 0.12,
                            s: 0.55
                        }, {
                            c: Colours.palette.m3tertiary,
                            x: 0.42,
                            y: 0.0,
                            s: 0.48
                        }, {
                            c: Colours.palette.m3secondary,
                            x: 0.28,
                            y: 0.38,
                            s: 0.5
                        }, {
                            c: Colours.palette.m3primaryContainer,
                            x: 0.55,
                            y: 0.35,
                            s: 0.42
                        }]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        x: parent.width * modelData.x
                        y: parent.height * modelData.y + (root.hovered ? -3 - index : 0)
                        width: parent.width * modelData.s
                        height: width
                        radius: width / 2
                        color: modelData.c
                        opacity: root.hovered ? 0.95 : 0.82
                        antialiasing: true
                        layer.enabled: true
                        layer.smooth: true

                        Behavior on y {
                            Anim {
                                type: Anim.DefaultSpatial
                                duration: Tokens.anim.durations.expressiveDefaultSpatial + index * root.staggerMs
                            }
                        }
                        Behavior on opacity {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }
                    }
                }
            }

            PreviewPill {
                anchors.right: parent.right
                anchors.top: parent.top
                // Stay inside inset — no negative y (was clipping on hover)
                anchors.topMargin: 0
                icon: Colours.light ? "light_mode" : "dark_mode"
                label: Colours.light ? qsTr("Light") : qsTr("Dark")
                fg: root.accent
                bg: Qt.alpha(root.accent, 0.18)
                maxLabelW: 40
                maxWidth: Math.max(48, parent.width - 2)
            }

            // Type sample + swatch row — bottom density
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 8

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Aa"
                    font.family: Tokens.font.family.sans
                    font.weight: Font.Medium
                    color: Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.extraLarge
                    opacity: 0.85
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    Repeater {
                        model: [Colours.palette.m3primary, Colours.palette.m3tertiary, Colours.palette.m3secondary, Colours.palette.m3primaryContainer]

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: 16
                            height: 16
                            radius: width / 2
                            color: modelData
                            border.width: index === 0 ? 1.5 : 0
                            border.color: Colours.palette.m3onSurface
                            antialiasing: true

                            transform: Translate {
                                y: root.hovered ? -2 - index * 0.5 : 0

                                Behavior on y {
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
                running: true
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

            function rebuildCarousel(): void {
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

            function ensureThumbs(): void {
                for (let i = 0; i < carouselPaths.length; i++) {
                    if (Wallpapers.isVideoPath(carouselPaths[i]))
                        Wallpapers.queueThumbnail(carouselPaths[i], i === slideIndex);
                }
            }

            function advanceRandom(): void {
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
                function onThumbnailUpdateCountChanged(): void {
                    wpRoot.ensureThumbs();
                }
                function onActualCurrentChanged(): void {
                    wpRoot.rebuildCarousel();
                }
            }

            // Rebuild when catalog grows (paths binding may change)
            onCatalogPathsChanged: rebuildCarousel()

            // Auto slideshow — random next wall every few seconds
            Timer {
                id: slideTimer
                interval: root.hovered ? 5000 : 3200
                running: wpRoot.slideCount > 1
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

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            height: parent.height

            Repeater {
                model: [0.4, 0.75, 0.5, 0.95, 0.65, 0.85, 0.55]

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: root.hovered ? 6 : 5
                    radius: width / 2
                    // Hover: bars pump taller with slight stagger
                    // Cap height so bars never clip top of short tile preview
                    height: modelData * Math.min(parent.height * 0.65, 32)
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.accent
                    opacity: root.hovered ? (0.55 + modelData * 0.45) : (0.4 + modelData * 0.4)

                    Behavior on height {
                        Anim {
                            type: Anim.DefaultSpatial
                            duration: Tokens.anim.durations.expressiveDefaultSpatial + index * 18
                        }
                    }
                    Behavior on width {
                        Anim {
                            type: Anim.DefaultSpatial
                        }
                    }
                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cNetwork

        // Signal arcs + status pill
        Item {
            // Signal strength bars
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.top: parent.top
                anchors.topMargin: 2
                spacing: 3
                height: 22

                Repeater {
                    model: [0.35, 0.55, 0.75, 1.0]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: 4
                        radius: 2
                        height: parent.height * modelData
                        anchors.bottom: parent.bottom
                        color: root.accent
                        opacity: root.hovered ? (0.45 + modelData * 0.55) : (0.3 + modelData * 0.45)

                        Behavior on opacity {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }
                        Behavior on height {
                            Anim {
                                type: Anim.DefaultSpatial
                                duration: Tokens.anim.durations.expressiveDefaultSpatial + index * root.staggerMs
                            }
                        }
                    }
                }
            }

            PreviewPill {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                icon: "wifi"
                label: qsTr("Wi‑Fi")
                fg: root.accent
                bg: Qt.alpha(root.accent, 0.16)
                maxLabelW: 40
                maxWidth: parent.width
            }
        }
    }

    Component {
        id: cNotifs

        Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.hovered ? 7 : 5

            Behavior on spacing {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            Repeater {
                model: 2

                delegate: Rectangle {
                    required property int index

                    width: Math.min(parent.width > 0 ? parent.width : 88, 88)
                    height: 20
                    radius: Tokens.rounding.small
                    color: Qt.alpha(Colours.palette.m3onSurface, index === 0 ? (root.hovered ? 0.14 : 0.1) : (root.hovered ? 0.1 : 0.07))
                    opacity: 1
                    // No y-lift — clips against CardPreview top
                    Behavior on color {
                        CAnim {}
                    }
                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.hovered ? 11 : 10
                            height: width
                            radius: width / 2
                            color: root.accent
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Rectangle {
                                width: 48
                                height: 3
                                radius: 1.5
                                color: Qt.alpha(Colours.palette.m3onSurface, 0.45)
                            }
                            Rectangle {
                                width: 32
                                height: 3
                                radius: 1.5
                                color: Qt.alpha(Colours.palette.m3onSurface, 0.25)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cBar

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(parent.width, 100)
            height: 28
            radius: height / 2
            color: Qt.alpha(Colours.palette.m3onSurface, root.hovered ? 0.12 : 0.08)
            // Lift only
            transform: Translate {
                y: root.hovered ? -2 : 0

                Behavior on y {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
            }

            Behavior on color {
                CAnim {}
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Repeater {
                    model: 3

                    delegate: Rectangle {
                        required property int index

                        width: 10
                        height: 10
                        radius: 5
                        color: index === 0 ? root.accent : Qt.alpha(Colours.palette.m3onSurface, 0.3)
                        opacity: root.hovered && index === 0 ? 1 : (index === 0 ? 0.95 : 0.85)

                        Behavior on opacity {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 10
                radius: 5
                color: Qt.alpha(root.accent, root.hovered ? 0.65 : 0.45)

                Behavior on color {
                    CAnim {}
                }
            }
        }
    }

    Component {
        id: cPanels

        Grid {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            columns: 2
            columnSpacing: root.hovered ? 7 : 5
            rowSpacing: root.hovered ? 7 : 5

            Behavior on columnSpacing {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            Behavior on rowSpacing {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            Repeater {
                model: [{
                        i: "apps",
                        a: true
                    }, {
                        i: "dashboard",
                        a: false
                    }, {
                        i: "view_sidebar",
                        a: false
                    }, {
                        i: "tune",
                        a: false
                    }]

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: root.hovered ? 28 : 26
                    height: width
                    radius: Tokens.rounding.small
                    color: modelData.a ? Qt.alpha(root.accent, root.hovered ? 0.32 : 0.2) : Qt.alpha(Colours.palette.m3onSurface, 0.08)
                    transformOrigin: Item.Center
                    antialiasing: true
                    // Lift active cell only
                    transform: Translate {
                        y: root.hovered && modelData.a ? -2 : 0

                        Behavior on y {
                            Anim {
                                type: Anim.DefaultSpatial
                                duration: Tokens.anim.durations.expressiveDefaultSpatial + index * root.staggerMs
                            }
                        }
                    }

                    Behavior on width {
                        Anim {
                            type: Anim.DefaultSpatial
                            duration: Tokens.anim.durations.expressiveDefaultSpatial + index * root.staggerMs
                        }
                    }
                    Behavior on color {
                        CAnim {}
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: modelData.i
                        fill: modelData.a ? 1 : 0
                        color: modelData.a ? root.accent : Colours.palette.m3onSurfaceVariant
                        iconPointSize: Tokens.font.size.smaller
                        antialiasing: true
                    }
                }
            }
        }
    }

    Component {
        id: cPower

        Item {
            Item {
                id: ring

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                readonly property real pct: root.hovered ? 0.86 : 0.72
                // No scale on ring — animate fill only (crisp + no clip)

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: root.hovered ? 4.5 : 4
                        strokeColor: Qt.alpha(Colours.palette.m3onSurface, 0.12)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 22
                            centerY: 22
                            radiusX: 17
                            radiusY: 17
                            startAngle: -90
                            sweepAngle: 360
                        }
                    }
                    ShapePath {
                        strokeWidth: root.hovered ? 4.5 : 4
                        strokeColor: root.accent
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 22
                            centerY: 22
                            radiusX: 17
                            radiusY: 17
                            startAngle: -90
                            sweepAngle: 360 * ring.pct

                            Behavior on sweepAngle {
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: Math.round(ring.pct * 100) + "%"
                    font.family: Tokens.font.family.mono
                    font.weight: Font.Normal
                    textPointSize: Tokens.font.size.smaller
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
                    icon: "computer"
                    label: {
                        const n = SysInfo.osName || qsTr("Linux");
                        if (n.length > 10)
                            return n.split(" ")[0] || n;
                        return n;
                    }
                    fg: Colours.palette.m3onSurfaceVariant
                    bg: Qt.alpha(Colours.palette.m3onSurface, 0.1)
                    maxLabelW: 72
                    maxWidth: parent.width
                }

                PreviewPill {
                    anchors.right: parent.right
                    icon: "desktop_windows"
                    label: SysInfo.wm || "Hyprland"
                    fg: Colours.palette.m3onSurfaceVariant
                    bg: Qt.alpha(Colours.palette.m3onSurface, 0.1)
                    maxLabelW: 72
                    maxWidth: parent.width
                }
            }
        }
    }

    Component {
        id: cSystem

        // Compact meters — no width growth / no thumb overflow (was top-clipping on hover)
        Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            width: Math.min(parent.width, 80)

            Repeater {
                model: [0.7, 0.4, 0.85]

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 8

                    readonly property real fill: root.hovered ? Math.min(1, modelData + 0.1) : modelData

                    // Track
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.12)

                        Rectangle {
                            width: parent.width * parent.parent.fill
                            height: parent.height
                            radius: parent.radius
                            color: root.accent

                            Behavior on width {
                                Anim {
                                    type: Anim.DefaultSpatial
                                    duration: Tokens.anim.durations.expressiveDefaultSpatial + index * root.staggerMs
                                }
                            }
                        }
                    }

                    // Thumb stays inside parent height (8) — no 10px circle overflow
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width, parent.width * parent.fill - width / 2))
                        width: 8
                        height: 8
                        radius: 4
                        color: root.accent
                        border.width: 1.5
                        border.color: Colours.palette.m3surfaceContainer

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
