import QtQuick
import QtQuick.Layouts
import QtQuick.Templates
import Olvex.Config
import qs.components
import qs.services

// Horizontal settings slider — token-scaled chrome + optional side value readout.
Slider {
    id: root

    // ── Value readout (side number for precision) ──
    property bool showValue: true // Show numeral value display for Nothing OS style
    // -1 = auto. 0+ = fixed decimal places (ignored when percent mode).
    property int valueDecimals: -1
    property string valueSuffix: ""
    // Force percent / decimal; auto when unset (null)
    property var valueAsPercent: null
    property var formatValue: null // function(real) → string

    readonly property bool _usePercent: {
        if (formatValue)
            return false;
        if (valueAsPercent === true)
            return true;
        if (valueAsPercent === false)
            return false;
        // Auto: 0..≤2 ratio ranges (opacity, volume) → percent
        return from >= 0 && to > 0 && to <= 2 && (stepSize <= 0 || stepSize < 1);
    }

    readonly property string valueText: {
        if (formatValue)
            return formatValue(value);
        if (_usePercent)
            return Math.round(value * 100) + (valueSuffix || "%");
        let dec = valueDecimals;
        if (dec < 0) {
            if (stepSize >= 1)
                dec = 0;
            else if (stepSize >= 0.1)
                dec = 1;
            else if (stepSize > 0)
                dec = 2;
            else
                dec = (to - from) <= 10 ? 1 : 0;
        }
        return Number(value).toFixed(dec) + valueSuffix;
    }

    // Control chrome scales with type
    readonly property real baseH: Math.max(24, Math.round((Tokens.font?.size?.normal ?? 13) * 1.9))
    readonly property real trackThickness: 16
    readonly property int segmentsCount: 20
    
    readonly property real valueGap: Tokens.spacing.small
    readonly property real valueColW: showValue ? Math.max(valueLabel.implicitWidth, 40) : 0

    implicitWidth: 260 + (showValue ? valueColW + valueGap : 0)
    implicitHeight: baseH
    padding: 0
    leftPadding: 0
    rightPadding: showValue ? valueColW + valueGap : 0
    topPadding: 0
    bottomPadding: 0
    live: true
    hoverEnabled: true
    snapMode: Slider.SnapOnRelease // Ensure buttery smooth dragging without step-size chunking

    Layout.preferredHeight: baseH
    Layout.minimumHeight: baseH
    Layout.fillHeight: false

    // Side number — monospaced figures for stable width while dragging
    StyledText {
        id: valueLabel

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showValue
        text: root.valueText
        color: root.enabled ? Colours.palette.m3onSurfaceVariant : Qt.alpha(Colours.palette.m3onSurface, 0.38)
        font.family: Tokens.font.family.mono
        font.weight: Font.Normal
        font.letterSpacing: 0.2
        textPointSize: Tokens.font.size.small
        horizontalAlignment: Text.AlignRight
        // Reserve width so layout doesn't jump 9→10→100
        width: Math.max(implicitWidth, 40)
    }

    background: Item {
        x: root.leftPadding
        y: root.topPadding + (root.availableHeight - height) / 2
        implicitWidth: 260
        implicitHeight: root.baseH
        width: root.availableWidth
        height: root.availableHeight > 0 ? root.availableHeight : root.baseH

        HoverHandler {
            enabled: root.enabled
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        // Nothing OS Segmented Matrix
        Row {
            anchors.fill: parent
            spacing: 4

            Repeater {
                model: root.segmentsCount

                Rectangle {
                    readonly property real segRatio: index / (root.segmentsCount - 1)
                    readonly property bool isActive: segRatio <= root.visualPosition

                    width: (parent.width - (root.segmentsCount - 1) * 4) / root.segmentsCount
                    height: root.trackThickness
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 3

                    color: isActive ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
                    opacity: isActive ? 1.0 : 0.75
                    scale: isActive ? 1.0 : 0.85

                    Behavior on color { ColorAnimation { duration: 60 } }
                }
            }
        }
    }

    handle: Item {
        width: 0
        height: 0
        x: root.leftPadding + root.visualPosition * root.availableWidth
        y: root.topPadding + root.availableHeight / 2
    }
}
