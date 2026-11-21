pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property real refWidth: 1920.0
    readonly property real refHeight: 1080.0
    readonly property real minScale: 0.60

    function forDimensions(w: real, h: real): real {
        if (!w || !h || w <= 0 || h <= 0)
            return 1.0;

        const raw = Math.min(Math.max(w, h) / refWidth, Math.min(w, h) / refHeight);
        if (raw >= 0.995)
            return 1.0;

        return Math.max(minScale, raw);
    }

    function forScreen(screen: var): real {
        return screen ? forDimensions(screen.width, screen.height) : 1.0;
    }

    function virtualWidth(w: real, scale: real): real {
        return Math.round(w / ((scale && scale > 0.01) ? scale : 1.0));
    }

    function virtualHeight(h: real, scale: real): real {
        return Math.round(h / ((scale && scale > 0.01) ? scale : 1.0));
    }
}
