import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import ".."
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services
import qs.modules.settings

StyledRect {
    id: root

    required property Session session
    property string query: ""
    property int selectedIndex: 0

    property int hoveredIndex: -1

    onQueryChanged: root.hoveredIndex = -1

    Timer {
        id: clearHoverTimer
        interval: 80
        onTriggered: root.hoveredIndex = -1
    }

    readonly property var results: PaneRegistry.search(query)
    readonly property int resultsCount: results.length

    signal itemActivated(var item)
    signal closeRequested()

    implicitWidth: 520
    implicitHeight: {
        if (query.trim() === "")
            return 0;
        if (resultsCount === 0)
            return 210;
        const listH = Math.min(resultsCount * 64, 420);
        return listH + headerItem.height + 24;
    }

    radius: Tokens.rounding.large
    color: Colours.palette.m3surfaceContainerHigh
    border.width: 0
    clip: true

    Behavior on implicitHeight { Anim { type: Anim.DefaultSpatial } }
    Behavior on opacity { Anim { type: Anim.FastEffects } }

    function ensureVisible(idx) {
        if (resultsList && idx >= 0 && idx < resultsCount) {
            resultsList.positionViewAtIndex(idx, ListView.Contain);
        }
    }

    function escapeHtml(str) {
        if (!str) return "";
        return String(str)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }

    function highlightQuery(text, q, accentHex) {
        if (!text) return "";
        if (!q || q.trim() === "")
            return escapeHtml(text);
        
        const rawTerms = q.trim().split(/\s+/).filter(t => t.length > 0);
        if (rawTerms.length === 0)
            return escapeHtml(text);

        // Sort terms by length descending so longer substrings match before sub-parts
        const terms = rawTerms.slice().sort((a, b) => b.length - a.length);
        let escaped = escapeHtml(text);

        for (let i = 0; i < terms.length; i++) {
            const term = terms[i].replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const regex = new RegExp("(" + term + ")", "gi");
            escaped = escaped.replace(regex, `<font color="${accentHex}"><b>$1</b></font>`);
        }
        return escaped;
    }

    function formatAndroidPath(item) {
        if (!item || !item.breadcrumb) return "";
        const rawParts = item.breadcrumb.split("›").map(s => s.trim()).filter(s => s.length > 0);
        const cleanParts = rawParts.filter(p => p.toLowerCase() !== "settings");
        if (cleanParts.length === 0) return "";
        return cleanParts.join(" › ");
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // ── Top Header / Results Count ──
        Item {
            id: headerItem
            Layout.fillWidth: true
            implicitHeight: 28
            visible: root.query.trim() !== ""

            RowLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "saved_search"
                    color: Colours.palette.m3primary
                    iconPointSize: 16
                }

                StyledText {
                    text: root.resultsCount > 0 
                        ? qsTr("SETTINGS MATCHES (%1)").arg(root.resultsCount)
                        : qsTr("NO MATCHES")
                    color: Colours.palette.m3primary
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                    textPointSize: Tokens.font.size.smaller
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: qsTr("↑↓ Navigate  ↵ Select")
                    color: Colours.palette.m3outline
                    font.weight: Font.Normal
                    textPointSize: Tokens.font.size.smaller
                    visible: root.resultsCount > 0
                }
            }
        }

        // ── Results List (Android 2-Line Pattern with Moving Highlights) ──
        ListView {
            id: resultsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 4
            model: root.results
            visible: root.resultsCount > 0

            // Moving Focus / Selection Indicator Pill
            StyledRect {
                id: focusHighlight
                parent: resultsList.contentItem
                width: resultsList.width
                height: 60
                radius: Tokens.rounding.normal
                color: Qt.alpha(Colours.palette.m3primary, 0.16)
                border.width: 0
                z: 0
                visible: root.resultsCount > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.resultsCount

                x: 0
                y: (root.selectedIndex >= 0 && root.selectedIndex < root.resultsCount)
                    ? root.selectedIndex * (60 + resultsList.spacing)
                    : 0

                Behavior on y {
                    SpringAnimation {
                        spring: 7.0
                        damping: 0.8
                        mass: 1.0
                        epsilon: 0.005
                    }
                }
            }

            // Moving Hover Highlight Indicator Pill
            StyledRect {
                id: hoverHighlight
                parent: resultsList.contentItem
                width: resultsList.width
                height: 60
                radius: Tokens.rounding.normal
                color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
                border.width: 0
                z: 0
                visible: opacity > 0.001
                opacity: (root.hoveredIndex >= 0 && root.hoveredIndex !== root.selectedIndex && root.hoveredIndex < root.resultsCount) ? 1.0 : 0.0

                x: 0
                y: (root.hoveredIndex >= 0 && root.hoveredIndex < root.resultsCount)
                    ? root.hoveredIndex * (60 + resultsList.spacing)
                    : y

                Behavior on y {
                    enabled: hoverHighlight.opacity > 0
                    SpringAnimation {
                        spring: 7.0
                        damping: 0.8
                        mass: 1.0
                        epsilon: 0.005
                    }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
            }

            delegate: StyledRect {
                id: itemCard

                required property var modelData
                required property int index

                readonly property bool isSelected: root.selectedIndex === index
                readonly property color itemAccent: Colours.palette[modelData.accentRole] || Colours.palette.m3primary

                width: resultsList.width
                implicitHeight: 60
                radius: Tokens.rounding.normal
                color: "transparent"
                border.width: 0
                z: 1

                HoverHandler {
                    id: cardHover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (hovered) {
                            clearHoverTimer.stop();
                            root.hoveredIndex = itemCard.index;
                        } else if (root.hoveredIndex === itemCard.index) {
                            clearHoverTimer.restart();
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 12

                    // Icon Squircle Badge
                    StyledRect {
                        implicitWidth: 38
                        implicitHeight: 38
                        radius: Tokens.rounding.small
                        color: Qt.alpha(itemCard.itemAccent, 0.16)
                        Layout.alignment: Qt.AlignVCenter

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: itemCard.modelData.icon || "settings"
                            fill: 1
                            color: itemCard.itemAccent
                            iconPointSize: 18
                        }
                    }

                    // Text Hierarchy Column (Line 1: Title, Line 2: Breadcrumb)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 3

                        // Line 1: Main Title with Query Highlight
                        Text {
                            text: root.highlightQuery(itemCard.modelData.title, root.query, Colours.palette.m3primary)
                            textFormat: Text.RichText
                            color: Colours.palette.m3onSurface
                            font.family: Tokens.font.family.sans
                            font.pixelSize: Math.max(13, Math.round(Tokens.font.size.normal * 96 / 72))
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Line 2: Clean Android-style Breadcrumb Path
                        StyledText {
                            text: root.formatAndroidPath(itemCard.modelData)
                            color: Colours.palette.m3outline
                            font.weight: Font.Normal
                            textPointSize: Tokens.font.size.small
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Right Selection Indicator
                    StyledRect {
                        implicitWidth: itemCard.isSelected ? enterRow.implicitWidth + 12 : 24
                        implicitHeight: 24
                        radius: Tokens.rounding.small
                        color: itemCard.isSelected ? Qt.alpha(Colours.palette.m3primary, 0.22) : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                            id: enterRow
                            anchors.centerIn: parent
                            spacing: 4
                            visible: itemCard.isSelected

                            MaterialIcon {
                                text: "keyboard_return"
                                color: Colours.palette.m3primary
                                iconPointSize: 14
                            }

                            StyledText {
                                text: qsTr("Enter")
                                color: Colours.palette.m3primary
                                font.weight: Font.DemiBold
                                textPointSize: Tokens.font.size.smaller
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "chevron_right"
                            color: Qt.alpha(Colours.palette.m3outline, 0.4)
                            iconPointSize: 16
                            visible: !itemCard.isSelected
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.itemActivated(itemCard.modelData);
                    }
                }
            }
        }

        // ── Empty State ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.resultsCount === 0 && root.query.trim() !== ""

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10

                StyledRect {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: Tokens.rounding.full
                    color: Qt.alpha(Colours.palette.m3outlineVariant, 0.15)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "search_off"
                        color: Colours.palette.m3outline
                        iconPointSize: 24
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No settings found for \"%1\"").arg(root.query)
                    color: Colours.palette.m3onSurface
                    font.weight: Font.Medium
                    textPointSize: Tokens.font.size.normal
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Try searching wifi, volume, font, dock, battery…")
                    color: Colours.palette.m3outline
                    font.weight: Font.Normal
                    textPointSize: Tokens.font.size.small
                }
            }
        }
    }
}
