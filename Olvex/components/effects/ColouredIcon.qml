
import QtQuick
import Quickshell.Widgets
import Olvex

IconImage {
    id: root

    required property color colour

    asynchronous: true
    smooth: true

    layer.enabled: true
    layer.effect: Colouriser {
        sourceColor: analyser.dominantColour
        colorizationColor: root.colour
    }

    layer.onEnabledChanged: {
        if (layer.enabled && status === Image.Ready)
            analyser.requestUpdate();
    }

    onStatusChanged: {
        if (layer.enabled && status === Image.Ready)
            analyser.requestUpdate();
    }

    ImageAnalyser {
        id: analyser

        sourceItem: root
    }
}
