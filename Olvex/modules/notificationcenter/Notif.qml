pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.components
import qs.services

// Flat row inside NotifGroup — group card is the only surface.
// Expanded = more content + actions, NOT another nested card.
Item {
    id: root

    required property NotifData modelData
    required property Props props
    required property bool expanded
    required property DrawerVisibilities visibilities

    readonly property StyledText body: (expandedContent.item as ExpandedBody)?.body ?? null
    readonly property bool isCritical: modelData?.urgency === "critical"
    readonly property string bodyText: String(modelData?.body ?? "").trim()
    readonly property bool hasBody: bodyText.length > 0

    readonly property real nonAnimHeight: expanded
        ? summary.implicitHeight
            + expandedContent.implicitHeight + expandedContent.anchors.topMargin
            + (indexHairline.visible ? indexHairline.height + Tokens.spacing.small / 2 : 0)
        : summaryHeightMetrics.height

    implicitHeight: nonAnimHeight

    // Soft top rule between expanded rows (not a second card)
    Rectangle {
        id: indexHairline
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        visible: root.expanded && (root.y > 1)
        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.22)
    }

    state: expanded ? "expanded" : ""

    states: State {
        name: "expanded"

        PropertyChanges {
            summary.anchors.topMargin: indexHairline.visible ? Tokens.spacing.small : 0
            dummySummary.anchors.topMargin: indexHairline.visible ? Tokens.spacing.small : 0
            compactBody.anchors.topMargin: indexHairline.visible ? Tokens.spacing.small : 0
            timeStr.anchors.topMargin: indexHairline.visible ? Tokens.spacing.small : 0
            expandedContent.anchors.topMargin: Tokens.spacing.smaller
            summary.width: root.width - timeStr.implicitWidth - Tokens.spacing.small
            summary.maximumLineCount: Number.MAX_SAFE_INTEGER
        }
    }

    transitions: Transition {
        Anim {
            properties: "margins,topMargin,width,maximumLineCount"
        }
    }

    TextMetrics {
        id: summaryHeightMetrics

        font.pixelSize: summary.resolvedPixelSize
        font.pointSize: -1
        font.family: summary.font.family
        font.weight: summary.font.weight
        text: " "
    }

    StyledText {
        id: summary

        anchors.top: parent.top
        anchors.left: parent.left

        width: parent.width
        text: root.modelData?.summary ?? ""
        color: root.isCritical
            ? Colours.palette.m3error
            : Colours.palette.m3onSurface
        textPointSize: Tokens.font.size.small
        font.weight: root.expanded ? Font.Medium : Font.Normal
        elide: Text.ElideRight
        wrapMode: Text.WordWrap
        maximumLineCount: 1
        lineHeight: 1.15
        lineHeightMode: Text.ProportionalHeight
    }

    StyledText {
        id: dummySummary

        anchors.top: parent.top
        anchors.left: parent.left

        visible: false
        text: root.modelData?.summary ?? ""
        textPointSize: summary.textPointSize
        font.weight: summary.font.weight
    }

    WrappedLoader {
        id: compactBody

        shouldBeActive: !root.expanded && root.hasBody
        anchors.top: parent.top
        anchors.left: dummySummary.right
        anchors.right: parent.right
        anchors.leftMargin: Tokens.spacing.small

        sourceComponent: StyledText {
            text: root.bodyText.replace(/\n/g, " ")
            color: root.isCritical
                ? Colours.palette.m3error
                : Colours.palette.m3onSurfaceVariant
            textPointSize: Tokens.font.size.small
            opacity: 0.88
            elide: Text.ElideRight
        }
    }

    WrappedLoader {
        id: timeStr

        shouldBeActive: root.expanded
        anchors.top: parent.top
        anchors.right: parent.right

        sourceComponent: StyledText {
            animate: true
            text: root.modelData?.timeStr ?? ""
            color: Colours.palette.m3outline
            textPointSize: Tokens.font.size.small
            font.family: Tokens.font.family.mono
            opacity: 0.85
        }
    }

    WrappedLoader {
        id: expandedContent

        shouldBeActive: root.expanded
        anchors.top: summary.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Tokens.spacing.smaller

        sourceComponent: ExpandedBody {}
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.Standard
        }
    }

    component ExpandedBody: ColumnLayout {
        readonly property alias body: bodyText

        spacing: Tokens.spacing.smaller

        StyledText {
            id: bodyText

            Layout.fillWidth: true
            visible: root.hasBody
            textFormat: Text.MarkdownText
            text: root.hasBody
                ? root.bodyText.replace(/(.)\n(?!\n)/g, "$1\n\n")
                : ""
            color: root.isCritical
                ? Colours.palette.m3error
                : Colours.palette.m3onSurfaceVariant
            textPointSize: Tokens.font.size.small
            wrapMode: Text.WrapAnywhere
            opacity: 0.92
            lineHeight: 1.25
            lineHeightMode: Text.ProportionalHeight

            onLinkActivated: link => {
                Quickshell.execDetached(["app2unit", "-O", "--", link]);
                root.visibilities.qspanel = false;
            }
        }

        NotifActionList {
            notif: root.modelData
        }
    }

    component WrappedLoader: Loader {
        id: comp

        required property bool shouldBeActive

        active: false
        opacity: 0

        states: State {
            name: "active"
            when: comp.shouldBeActive

            PropertyChanges {
                comp.opacity: 1
                comp.active: true
            }
        }

        transitions: [
            Transition {
                from: ""
                to: "active"

                SequentialAnimation {
                    PropertyAction {
                        property: "active"
                    }
                    Anim {
                        property: "opacity"
                    }
                }
            },
            Transition {
                from: "active"
                to: ""

                SequentialAnimation {
                    Anim {
                        property: "opacity"
                    }
                    PropertyAction {
                        property: "active"
                    }
                }
            }
        ]
    }
}
