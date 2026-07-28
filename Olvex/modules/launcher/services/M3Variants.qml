pragma Singleton

import ".."
import QtQuick
import Quickshell
import Olvex.Config
import qs.utils

Searcher {
    id: root

    function transformSearch(search: string): string {
        return search.slice(`${GlobalConfig.launcher.actionPrefix}variant `.length);
    }

    catalog: variants.instances
    useFuzzy: GlobalConfig.launcher.useFuzzy.variants

    Variants {
        id: variants

        model: [
            {
                variant: "vibrant",
                icon: "sentiment_very_dissatisfied",
                name: qsTr("Vibrant"),
                description: qsTr("A high chroma palette. The primary palette's chroma is at maximum.")
            },
            {
                variant: "tonalspot",
                icon: "android",
                name: qsTr("Tonal Spot"),
                description: qsTr("Default for Material theme colours. A pastel palette with a low chroma.")
            },
            {
                variant: "expressive",
                icon: "compare_arrows",
                name: qsTr("Expressive"),
                description: qsTr("A medium chroma palette. The primary palette's hue is different from the seed colour, for variety.")
            },
            {
                variant: "fidelity",
                icon: "compare",
                name: qsTr("Fidelity"),
                description: qsTr("Matches the seed colour, even if the seed colour is very bright (high chroma).")
            },
            {
                variant: "content",
                icon: "sentiment_calm",
                name: qsTr("Content"),
                description: qsTr("Almost identical to fidelity.")
            },
            {
                variant: "fruitsalad",
                icon: "nutrition",
                name: qsTr("Fruit Salad"),
                description: qsTr("A playful theme - the seed colour's hue does not appear in the theme.")
            },
            {
                variant: "rainbow",
                icon: "looks",
                name: qsTr("Rainbow"),
                description: qsTr("A playful theme - the seed colour's hue does not appear in the theme.")
            },
            {
                variant: "neutral",
                icon: "contrast",
                name: qsTr("Neutral"),
                description: qsTr("Close to grayscale, a hint of chroma.")
            },
            {
                variant: "monochrome",
                icon: "filter_b_and_w",
                name: qsTr("Monochrome"),
                description: qsTr("All colours are grayscale, no chroma.")
            }
        ]

        Variant {}
    }

    component Variant: QtObject {
        required property var modelData
        readonly property string variant: modelData.variant
        readonly property string icon: modelData.icon
        readonly property string name: modelData.name
        readonly property string description: modelData.description

        function onClicked(list: AppList): void {
            list.visibilities.launcher = false;
            Schemes.setVariant(variant);
        }
    }
}