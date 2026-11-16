pragma Singleton

import QtQuick

QtObject {
    readonly property var styles: [
        { id: "classic", name: qsTr("Classic"), variants: [qsTr("Tonal Pill"), qsTr("Minimal Typo")] },
        { id: "olvex-signature", name: qsTr("Morphing Hybrid"), variants: [qsTr("Morph Dial"), qsTr("Hero Card")] },
        { id: "scalloped", name: qsTr("Scalloped"), variants: [qsTr("Cookie + Squircle"), qsTr("Tonal Cookie")] },
        { id: "chunky", name: qsTr("Chunky Overlap"), variants: [qsTr("Solid Fill"), qsTr("Outline")] },
        { id: "bold-analog", name: qsTr("Bold 0-3-6-9"), variants: [qsTr("Filled Ticks"), qsTr("Hollow Ticks"), qsTr("Light Dial"), qsTr("Deep Tonal")] },
        { id: "stacked-2x2", name: qsTr("Stacked 2×2"), variants: [qsTr("Contour"), qsTr("Duo-Tone")] },
        { id: "wide-radial", name: qsTr("Wide Radial"), variants: [qsTr("12-Ray"), qsTr("60-Tick + Date")] },
        { id: "chrono-digital", name: qsTr("Chrono Digital"), variants: [qsTr("Dual Labels"), qsTr("Minimal")] },
        { id: "clustered-giant", name: qsTr("Clustered Giant"), variants: [qsTr("Solid Numerals"), qsTr("Wireframe")] },
        { id: "square-swiss", name: qsTr("Square Swiss"), variants: [qsTr("Dark Dial"), qsTr("Accent Dial")] },
        { id: "tall-split", name: qsTr("Tall Split"), variants: [qsTr("Card"), qsTr("Frameless")] },
        { id: "expressive-flower", name: qsTr("Expressive Petal"), variants: [qsTr("Soft Burst"), qsTr("Tonal Flower"), qsTr("Clover")] },
        { id: "editorial-serif", name: qsTr("Editorial Serif"), variants: [qsTr("Stacked"), qsTr("Asymmetric Split")] },
        { id: "orbit-ring", name: qsTr("Orbit Ring"), variants: [qsTr("Orbit Arc"), qsTr("Dual Track")] },
        { id: "bento-cards", name: qsTr("M3 Bento Trio"), variants: [qsTr("Tonal Trio"), qsTr("Surface Stack")] },
        { id: "pill-morph", name: qsTr("Capsule Stack"), variants: [qsTr("Staggered"), qsTr("Split Stadium")] },
        { id: "sunburst-analog", name: qsTr("Sunburst"), variants: [qsTr("Sunny"), qsTr("Gem")] },
        { id: "dot-matrix", name: qsTr("Dot Matrix"), variants: [qsTr("Tonal Card"), qsTr("Floating")] },
        { id: "typo-ribbon", name: qsTr("Kinetic Ribbon"), variants: [qsTr("Horizontal"), qsTr("Vertical")] },
        { id: "flip-tiles", name: qsTr("Split Flap"), variants: [qsTr("Tonal Surface"), qsTr("Accent Flap")] },
        { id: "arch-gauge", name: qsTr("Arch Gauge"), variants: [qsTr("Tonal Arch"), qsTr("Inverted Arch")] },
        { id: "radar-minimal", name: qsTr("Radar Bauhaus"), variants: [qsTr("Radar Sweep"), qsTr("Clean Bauhaus")] },
        { id: "wave-progress", name: qsTr("M3 Squiggle"), variants: [qsTr("Wavy Ring"), qsTr("Progress Wave")] },
        { id: "pixel-slanted", name: qsTr("Italic Kinetic"), variants: [qsTr("Italic Block"), qsTr("Ghost Italic")] },
        { id: "hexagon-analog", name: qsTr("Hexagon Analog"), variants: [qsTr("Tonal Hex"), qsTr("Primary Hex")] },
        { id: "vertical-bars", name: qsTr("Equalizer Bars"), variants: [qsTr("Tonal Bars"), qsTr("Accent Bars")] },
        { id: "dual-ring-analog", name: qsTr("Concentric Dial"), variants: [qsTr("Concentric Dark"), qsTr("Tonal Core")] },
        { id: "wordmark-time", name: qsTr("Day Wordmark"), variants: [qsTr("Capsule Day"), qsTr("Minimal Typo")] },
        { id: "minimal-arc", name: qsTr("Horizon Arc"), variants: [qsTr("Horizon Card"), qsTr("Tonal Split")] },
        { id: "corner-badge", name: qsTr("Corner Badge"), variants: [qsTr("Corner Circle"), qsTr("Pill Corner")] },
        { id: "segmented-pill", name: qsTr("Segmented Row"), variants: [qsTr("Tonal Segments"), qsTr("Surface Segments")] },
        { id: "floating-digits", name: qsTr("Typo Divider"), variants: [qsTr("Vertical Bar"), qsTr("Dot Divider")] },
        { id: "compass-dial", name: qsTr("Compass Rose"), variants: [qsTr("Tonal Compass"), qsTr("Primary Ring")] },
        { id: "glass-stack", name: qsTr("Layered Stack"), variants: [qsTr("Layered Tonal"), qsTr("Primary Back")] },
        { id: "binary-dots", name: qsTr("Binary BCD"), variants: [qsTr("Tonal Card"), qsTr("Floating Dots")] },
        { id: "clover-analog", name: qsTr("Clover Dial"), variants: [qsTr("8-Leaf Clover"), qsTr("Puffy Cloud")] },
        { id: "split-ticker", name: qsTr("Kinetic Ticker"), variants: [qsTr("Tonal Stadium"), qsTr("Primary Header")] },
        { id: "minimal-numeral", name: qsTr("Watermark"), variants: [qsTr("Watermark Hours"), qsTr("Watermark Day")] },
        { id: "analog-digital", name: qsTr("Complication"), variants: [qsTr("Date Pill"), qsTr("Digital Pill")] }
    ]

    function entryFor(styleId) {
        for (let i = 0; i < styles.length; i++) {
            if (styles[i].id === styleId)
                return styles[i];
        }
        return styles[0];
    }
}

