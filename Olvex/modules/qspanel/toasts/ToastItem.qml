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

    // ── M3 Content Design & Unified Typography ──────
    readonly property string cleanTitle: String(modelData.title ?? "").trim()
    readonly property string rawMessage: String(modelData.message ?? "").trim()

    readonly property string displayText: {
        if (!rawMessage.length)
            return cleanTitle;
        if (!cleanTitle.length)
            return rawMessage;

        const tLower = cleanTitle.toLowerCase();
        const mLower = rawMessage.toLowerCase();

        if (tLower === mLower)
            return rawMessage;

        if (tLower.includes("connected") && !mLower.includes("connected"))
            return rawMessage + " " + qsTr("connected");
        if ((tLower.includes("disconnected") || tLower.includes("removed")) && !mLower.includes("disconnected") && !mLower.includes("removed"))
            return rawMessage + " " + (tLower.includes("removed") ? qsTr("removed") : qsTr("disconnected"));

        if (tLower.includes("audio output") || tLower.includes("audio input"))
            return rawMessage;

        if (mLower.startsWith(tLower) || tLower.startsWith(mLower))
            return rawMessage.length >= cleanTitle.length ? rawMessage : cleanTitle;

        return rawMessage;
    }

    // ── M3 Status Roles ──────────────────────────────
    readonly property bool isSuccess: modelData.type === Toast.Success
    readonly property bool isWarning: modelData.type === Toast.Warning
    readonly property bool isError: modelData.type === Toast.Error
    readonly property bool isInfo: !isSuccess && !isWarning && !isError

    // ── M3 Theme-Adaptive Translucent Surface ───
    readonly property real toastAlpha: Colours.transparencyEnabled ? Colours.transparencyBase : 0.84

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
        return Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.16 : 0.22);
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
    implicitWidth: Math.min(480, Math.max(160, (iconBadge.implicitWidth + primaryText.implicitWidth + closeBtn.implicitWidth + 36)))
    implicitHeight: 42
    width: implicitWidth
    height: implicitHeight

    // M3 Stadium Capsule Shape
    radius: height / 2

    Behavior on radius {
        SpringAnimation { spring: 3.8; damping: 0.74; mass: 1.0; epsilon: 0.005 }
    }

    color: root.containerColor
    border.width: 0
    border.color: "transparent"

    // M3 Pill State Layer
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
        anchors.leftMargin: 8
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

        // Single Unified M3 Message Text
        StyledText {
            id: primaryText

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.displayText
            color: root.contentOnColor
            textPointSize: Tokens.font.size.normal
            font.weight: Font.Medium
            font.letterSpacing: 0.15
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            renderType: Text.QtRendering
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
