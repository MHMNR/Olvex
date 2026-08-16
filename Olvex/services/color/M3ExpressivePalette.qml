
import QtQuick
import Olvex

QtObject {
    id: root

    // M3 Expressive dark defaults (semantic roles — tokens-theming.md)
    property color m3primary: "#CFBCFF"
    property color m3onPrimary: "#381E72"
    property color m3primaryContainer: "#4F378A"
    property color m3onPrimaryContainer: "#E9DDFF"
    property color m3secondary: "#CCC2DC"
    property color m3onSecondary: "#332D41"
    property color m3secondaryContainer: "#4A4458"
    property color m3onSecondaryContainer: "#E8DEF8"
    property color m3tertiary: "#EFB8C8"
    property color m3onTertiary: "#492532"
    property color m3tertiaryContainer: "#633B48"
    property color m3onTertiaryContainer: "#FFD8E4"
    property color m3error: "#F2B8B5"
    property color m3onError: "#601410"
    property color m3errorContainer: "#8C1D18"
    property color m3onErrorContainer: "#F9DEDC"
    property color m3background: "#141218"
    property color m3onBackground: "#E6E1E5"
    property color m3surface: "#141218"
    property color m3onSurface: "#E6E1E5"
    property color m3surfaceVariant: "#49454F"
    property color m3onSurfaceVariant: "#CAC4D0"
    property color m3surfaceDim: "#141218"
    property color m3surfaceBright: "#3B383E"
    property color m3surfaceContainerLowest: "#0F0D13"
    property color m3surfaceContainerLow: "#1D1B20"
    property color m3surfaceContainer: "#211F26"
    property color m3surfaceContainerHigh: "#2B2930"
    property color m3surfaceContainerHighest: "#36343B"
    property color m3inverseSurface: "#E6E1E5"
    property color m3inverseOnSurface: "#313033"
    property color m3inversePrimary: "#6750A4"
    property color m3outline: "#938F99"
    property color m3outlineVariant: "#49454F"
    property color m3shadow: "#000000"
    property color m3scrim: "#000000"
    property color m3surfaceTint: "#CFBCFF"
    property color m3success: "#B5CCBA"
    property color m3onSuccess: "#213528"
    property color m3successContainer: "#374B3E"
    property color m3onSuccessContainer: "#D1E9D6"

    property color term0: "#353434"
    property color term1: "#ff4c8a"
    property color term2: "#ffbbb7"
    property color term3: "#ffdedf"
    property color term4: "#b3a2d5"
    property color term5: "#e98fb0"
    property color term6: "#ffba93"
    property color term7: "#eed1d2"
    property color term8: "#b39e9e"
    property color term9: "#ff80a3"
    property color term10: "#ffd3d0"
    property color term11: "#fff1f0"
    property color term12: "#dcbc93"
    property color term13: "#f9a8c2"
    property color term14: "#ffd1c0"
    property color term15: "#ffffff"

    // Smooth transitions when wallpaper changes
    Behavior on m3primary { ColorAnimation { duration: 100 } }
    Behavior on m3primaryContainer { ColorAnimation { duration: 100 } }
    Behavior on m3secondaryContainer { ColorAnimation { duration: 100 } }
    Behavior on m3tertiary { ColorAnimation { duration: 100 } }
    Behavior on m3tertiaryContainer { ColorAnimation { duration: 100 } }
    Behavior on m3error { ColorAnimation { duration: 100 } }
    Behavior on m3errorContainer { ColorAnimation { duration: 100 } }
    Behavior on m3surface { ColorAnimation { duration: 100 } }
    Behavior on m3surfaceVariant { ColorAnimation { duration: 100 } }
    Behavior on m3surfaceContainerLow { ColorAnimation { duration: 100 } }
    Behavior on m3surfaceContainer { ColorAnimation { duration: 100 } }
    Behavior on m3surfaceContainerHigh { ColorAnimation { duration: 100 } }
    Behavior on m3surfaceContainerHighest { ColorAnimation { duration: 100 } }
    Behavior on m3outline { ColorAnimation { duration: 100 } }
    Behavior on m3outlineVariant { ColorAnimation { duration: 100 } }
    Behavior on m3surfaceTint { ColorAnimation { duration: 100 } }
    Behavior on m3success { ColorAnimation { duration: 100 } }
    Behavior on m3successContainer { ColorAnimation { duration: 100 } }

    function applyScheme(scheme) {
        return M3ColorMapper.applySchemeToPalette(root, scheme);
    }

    function applyPayload(data) {
        const scheme = M3ColorMapper.parseSchemePayload(data);
        if (!scheme)
            return null;
        root.applyScheme(scheme);
        return scheme;
    }
}
