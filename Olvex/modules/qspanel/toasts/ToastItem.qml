import QtQuick
import QtQuick.Layouts
import Olvex
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

StyledRect {
    id: root

    required property Toast modelData

    // ── M3 Content Design (Redundancy filtering) ──────
    readonly property string cleanTitle: String(modelData.title ?? "").trim()
    readonly property string rawMessage: String(modelData.message ?? "").trim()
    readonly property bool isRedundantMessage: {
        if (!rawMessage.length) return true;
        const t = cleanTitle.toLowerCase().replace(/[^a-z0-9]/g, "");
        const m = rawMessage.toLowerCase().replace(/[^a-z0-9]/g, "");
        return t === m || (t.length > 3 && m.startsWith(t)) || (m.length > 3 && t.startsWith(m));
    }
    readonly property string cleanMessage: isRedundantMessage ? "" : rawMessage
    readonly property bool hasMessage: cleanMessage.length > 0

    // ── M3 Status Roles ──────────────────────────────
    readonly property bool isSuccess: modelData.type === Toast.Success
    readonly property bool isWarning: modelData.type === Toast.Warning
    readonly property bool isError: modelData.type === Toast.Error
    readonly property bool isInfo: !isSuccess && !isWarning && !isError

    // ── Android 17 Theme-Adaptive Translucent Blur Surface ───
    readonly property real toastAlpha: Colours.transparencyEnabled ? Colours.transparencyBase : 0.82

    readonly property color containerColor: {
        if (isSuccess)
            return Qt.alpha(Colours.palette.m3successContainer, toastAlpha);
        if (isWarning)
            return Qt.alpha(Colours.palette.m3tertiaryContainer, toastAlpha);
        if (isError)
            return Qt.alpha(Colours.palette.m3errorContainer, toastAlpha);
        return Colours.light
            ? Qt.alpha(Colours.palette.m3surfaceBright, toastAlpha)
            : Qt.alpha(Colours.palette.m3surfaceContainerHighest, toastAlpha);
    }

    readonly property color contentOnColor: {
        if (isSuccess)
            return Colours.palette.m3onSuccessContainer;
        if (isWarning)
            return Colours.palette.m3onTertiaryContainer;
        if (isError)
            return Colours.palette.m3onErrorContainer;
        return Colours.palette.m3onSurface;
    }

    readonly property color iconBadgeColor: {
        if (isSuccess)
            return Colours.palette.m3success;
        if (isWarning)
            return Colours.palette.m3tertiary;
        if (isError)
            return Colours.palette.m3error;
        return Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.18 : 0.24);
    }

    readonly property color iconGlyphColor: {
        if (isSuccess)
            return Colours.palette.m3onSuccess;
        if (isWarning)
            return Colours.palette.m3onTertiary;
        if (isError)
            return Colours.palette.m3onError;
        return Colours.palette.m3primary;
    }

    readonly property string defaultIcon: {
        if (isSuccess) return "check_circle";
        if (isWarning) return "warning";
        if (isError) return "error";
        return "info";
    }

    anchors.horizontalCenter: parent.horizontalCenter
    implicitWidth: Math.min(460, Math.max(160, (iconBadge.implicitWidth + textColumn.implicitWidth + closeBtn.implicitWidth + 36)))
    implicitHeight: hasMessage ? 52 : 44
    width: implicitWidth
    height: implicitHeight

    // Android 17 Capsule Pill Shape
    radius: height / 2

    Behavior on radius {
        SpringAnimation { spring: 3.8; damping: 0.74; mass: 1.0; epsilon: 0.005 }
    }

    color: root.containerColor

    border.width: 0
    border.color: "transparent"

    // Android 17 Pill State Layer
    StateLayer {
        id: stateLayer
        anchors.fill: parent
        radius: parent.radius
        color: root.contentOnColor
        onClicked: root.modelData.close()
    }

    RowLayout {
        id: contentLayout

        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        spacing: 8

        // Leading Circular Icon Badge (26x26 dp)
        StyledRect {
            id: iconBadge

            implicitWidth: 26
            implicitHeight: 26
            radius: 13
            Layout.alignment: Qt.AlignVCenter

            color: root.iconBadgeColor

            MaterialIcon {
                id: iconGlyph

                anchors.centerIn: parent
                text: root.modelData.icon.length > 0 ? root.modelData.icon : root.defaultIcon
                color: root.iconGlyphColor
                iconPointSize: Math.round(Tokens.font.size.normal * 1.05)
            }
        }

        // Text Stack (Title & Supporting Text - Center Aligned)
        ColumnLayout {
            id: textColumn

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                id: titleText

                Layout.fillWidth: true
                text: root.cleanTitle
                color: root.contentOnColor
                textPointSize: Tokens.font.size.normal
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
                elide: Text.ElideRight
                renderType: Text.QtRendering
            }

            StyledText {
                id: messageText

                visible: root.hasMessage
                Layout.fillWidth: true
                textFormat: Text.StyledText
                text: root.cleanMessage
                color: root.contentOnColor
                opacity: 0.80
                textPointSize: Tokens.font.size.small
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
                elide: Text.ElideRight
                renderType: Text.QtRendering
            }
        }

        // Compact Dismiss Button (24x24 dp)
        StyledRect {
            id: closeBtn

            implicitWidth: 24
            implicitHeight: 24
            radius: 12
            color: "transparent"
            Layout.alignment: Qt.AlignVCenter
            z: 2

            StateLayer {
                id: closeStateLayer
                anchors.fill: parent
                radius: parent.radius
                color: root.contentOnColor
                onClicked: root.modelData.close()
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "close"
                color: root.contentOnColor
                opacity: closeStateLayer.containsMouse ? 1.0 : 0.60
                iconPointSize: Tokens.font.size.small
            }
        }
    }

    Behavior on color {
        CAnim {}
    }
}
