pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import QtQuick.Effects
import Olvex.Config
import qs.components
import qs.services

// Material Design 3 (M3) Slider — Continuous & Discrete with Active/Inactive Track,
// Vertical Bar Handle, Stop Indicators, 5px Track Gap, Hover Halo, Floating Value Pin,
// and Keyboard / Scroll Wheel interaction.
T.Slider {
    id: root

    // ── Value readout (side number for precision) ──
    property bool showValue: true
    property bool showValuePopup: true // Floating M3 value pin popup above thumb
    property int valueDecimals: -1
    property string valueSuffix: ""
    property var valueAsPercent: null // Force percent / decimal; auto when null
    property var formatValue: null    // function(real) → string

    // ── M3 Styling Tokens & Dimensions ──
    property real trackHeight: 14
    property real thumbWidth: 4
    property real thumbHeight: 26
    property real gap: 5
    property real stopIndicatorSize: 4
    property color activeTrackColor: root.enabled ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.38)
    property color inactiveTrackColor: root.enabled ? Colours.palette.m3surfaceContainerHighest : Qt.alpha(Colours.palette.m3onSurface, 0.12)
    property color thumbColor: root.enabled ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.38)
    property color popupBgColor: Colours.palette.m3inverseSurface
    property color popupTextColor: Colours.palette.m3inverseOnSurface
    property color haloColor: Colours.palette.m3primary

    readonly property bool _usePercent: {
        if (formatValue)
            return false;
        if (valueAsPercent === true)
            return true;
        if (valueAsPercent === false)
            return false;
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

    readonly property real baseH: Math.max(32, Math.round((Tokens.font?.size?.normal ?? 13) * 2.2))
    readonly property real valueGap: Tokens.spacing.normal
    readonly property real valueColW: showValue ? Math.max(valueLabel.implicitWidth, 42) : 0

    implicitWidth: 260 + (showValue ? valueColW + valueGap : 0)
    implicitHeight: Math.max(baseH, thumbHeight + 8)
    padding: 0
    leftPadding: thumbWidth / 2 + gap
    rightPadding: (showValue ? valueColW + valueGap : 0) + thumbWidth / 2 + gap
    topPadding: 0
    bottomPadding: 0
    live: true
    hoverEnabled: true
    snapMode: T.Slider.SnapOnRelease
    focus: true
    activeFocusOnTab: true

    Layout.preferredHeight: implicitHeight
    Layout.minimumHeight: implicitHeight
    Layout.fillHeight: false

    // Keyboard support
    Keys.onLeftPressed: event => {
        const step = root.stepSize > 0 ? root.stepSize : (root.to - root.from) / 100;
        root.value = Math.max(root.from, root.value - step);
        event.accepted = true;
    }
    Keys.onRightPressed: event => {
        const step = root.stepSize > 0 ? root.stepSize : (root.to - root.from) / 100;
        root.value = Math.min(root.to, root.value + step);
        event.accepted = true;
    }

    // Scroll wheel support
    WheelHandler {
        enabled: root.enabled
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const step = root.stepSize > 0 ? root.stepSize : (root.to - root.from) / 50;
            if (event.angleDelta.y > 0)
                root.value = Math.min(root.to, root.value + step);
            else if (event.angleDelta.y < 0)
                root.value = Math.max(root.from, root.value - step);
        }
    }

    // Side number readout (optional)
    StyledText {
        id: valueLabel

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showValue
        text: root.valueText
        color: root.enabled ? Colours.palette.m3onSurfaceVariant : Qt.alpha(Colours.palette.m3onSurface, 0.38)
        font.family: Tokens.font.family.mono
        font.weight: Font.Medium
        font.letterSpacing: 0.2
        textPointSize: Tokens.font.size.small
        horizontalAlignment: Text.AlignRight
        width: Math.max(implicitWidth, 42)
    }

    // ── Track Background ──
    background: Item {
        x: root.leftPadding
        y: root.topPadding + (root.availableHeight - height) / 2
        implicitWidth: 200
        implicitHeight: root.trackHeight
        width: root.availableWidth
        height: root.trackHeight

        HoverHandler {
            id: trackHover
            enabled: root.enabled
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        // Inactive Track (from handle gap to right edge)
        Rectangle {
            id: inactiveTrack
            anchors.verticalCenter: parent.verticalCenter
            x: Math.min(parent.width, Math.max(0, root.visualPosition * parent.width + root.gap))
            width: Math.max(0, parent.width - x)
            height: parent.height
            radius: height / 2
            color: root.inactiveTrackColor
            antialiasing: true

            Behavior on color {
                ColorAnimation { duration: Tokens.anim.durations.expressiveFastEffects }
            }
        }

        // Active Track (from left edge up to handle gap)
        Rectangle {
            id: activeTrack
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(parent.width, root.visualPosition * parent.width - root.gap))
            height: parent.height
            radius: height / 2
            color: root.activeTrackColor
            antialiasing: true

            Behavior on color {
                ColorAnimation { duration: Tokens.anim.durations.expressiveFastEffects }
            }
        }

        // Stop Indicator at track terminus (m3.material.io)
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: (parent.height - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: root.stopIndicatorSize
            height: root.stopIndicatorSize
            radius: width / 2
            color: Qt.alpha(Colours.palette.m3onSurface, root.enabled ? 0.38 : 0.12)
            visible: (parent.width - (root.visualPosition * parent.width)) > root.gap * 2
            antialiasing: true
        }

        // Discrete Tick Marks (when stepSize is active and step count is reasonable)
        readonly property int stepCount: (root.stepSize > 0 && root.to > root.from) ? Math.round((root.to - root.from) / root.stepSize) : 0
        readonly property bool showTicks: stepCount > 1 && stepCount <= 30

        Repeater {
            model: parent.showTicks ? (parent.stepCount + 1) : 0

            Rectangle {
                required property int index

                readonly property real tickPos: parent.stepCount > 0 ? (index / parent.stepCount) : 0
                readonly property bool isPassed: tickPos <= root.visualPosition

                x: Math.round(tickPos * parent.width - width / 2)
                anchors.verticalCenter: parent.verticalCenter
                width: root.stopIndicatorSize
                height: root.stopIndicatorSize
                radius: width / 2
                color: isPassed ? Colours.palette.m3onPrimary : Colours.palette.m3outlineVariant
                opacity: (tickPos === 0 || tickPos === 1) ? 0 : 0.7
                antialiasing: true
            }
        }
    }

    // ── Thumb Handle & Value Pin Popup ──
    handle: Item {
        id: handleItem
        x: root.leftPadding + root.visualPosition * root.availableWidth - width / 2
        y: root.topPadding + (root.availableHeight - height) / 2
        width: Math.max(24, root.thumbWidth + 12)
        height: root.thumbHeight + 8

        // M3 Vertical Bar Handle
        Rectangle {
            id: thumbVisual
            anchors.centerIn: parent
            width: root.pressed ? Math.max(2.5, root.thumbWidth * 0.75) : root.thumbWidth
            height: root.pressed ? root.thumbHeight + 2 : root.thumbHeight
            radius: width / 2
            color: root.thumbColor
            antialiasing: true

            Behavior on width {
                SpringAnimation {
                    spring: 6.0
                    damping: 0.60
                    epsilon: 0.005
                }
            }
            Behavior on height {
                SpringAnimation {
                    spring: 6.0
                    damping: 0.60
                    epsilon: 0.005
                }
            }
            Behavior on color {
                ColorAnimation { duration: Tokens.anim.durations.expressiveFastEffects }
            }
        }
    }
}
