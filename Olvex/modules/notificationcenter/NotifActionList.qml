
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Olvex.Config
import qs.components
import qs.services

// Close + real app actions + copy (body only).
// Never render blank fill-width pills (empty default actions from apps like kitty).
Item {
    id: root

    required property NotifData notif

    readonly property string bodyText: String(notif?.body ?? "").trim()
    readonly property var actionModel: {
        const rows = [];
        rows.push({ kind: "close" });

        const acts = notif?.actions ?? [];
        const useIcons = !!notif?.hasActionIcons;
        for (let i = 0; i < acts.length; i++) {
            const a = acts[i];
            const label = String(a?.text ?? "").trim();
            const id = String(a?.identifier ?? "").trim();

            // Skip nameless actions — they used to become long empty bars
            // (common for "default" actions with invoke but no UI text)
            if (!label) {
                if (!(useIcons && id && id !== "default"))
                    continue;
            }

            rows.push({ kind: "action", action: a, label: label, id: id });
        }

        if (root.bodyText.length > 0)
            rows.push({ kind: "copy" });

        return rows;
    }

    readonly property int primaryCount: {
        let n = 0;
        for (let i = 0; i < actionModel.length; i++) {
            if (actionModel[i].kind === "action")
                n++;
        }
        return n;
    }

    Layout.fillWidth: true
    implicitHeight: actionList.implicitHeight
    // Hide entire row only if somehow empty (always has close)
    visible: actionModel.length > 0

    RowLayout {
        id: actionList

        anchors.left: parent.left
        width: parent.width
        spacing: Tokens.spacing.smaller

        Repeater {
            model: root.actionModel

            StyledRect {
                id: action

                required property var modelData

                readonly property string kind: modelData.kind
                readonly property bool isClose: kind === "close"
                readonly property bool isCopy: kind === "copy"
                readonly property bool isPrimary: kind === "action"
                readonly property var act: modelData.action
                readonly property string label: modelData.label ?? String(act?.text ?? "").trim()

                // Icon chips = perfect circles; text actions can stretch
                readonly property int iconSize: 28

                Layout.fillWidth: isPrimary && root.primaryCount > 0
                Layout.preferredWidth: isClose || isCopy
                    ? iconSize
                    : (isPrimary ? Math.max(implicitWidth, 56) : implicitWidth)
                Layout.preferredHeight: isClose || isCopy ? iconSize : implicitHeight
                Layout.minimumWidth: isClose || isCopy ? iconSize : -1
                Layout.maximumWidth: isClose || isCopy ? iconSize : -1
                Layout.minimumHeight: isClose || isCopy ? iconSize : -1
                Layout.maximumHeight: isClose || isCopy ? iconSize : -1
                implicitWidth: isClose || isCopy
                    ? iconSize
                    : actionInner.implicitWidth + Tokens.padding.normal * 2
                implicitHeight: isClose || isCopy ? iconSize : 28

                // Equal sides + full radius → true circle for close/copy
                radius: isClose || isCopy ? iconSize / 2 : Tokens.rounding.full
                border.width: 0
                border.color: "transparent"
                color: {
                    if (isClose)
                        return Qt.alpha(Colours.palette.m3error, actionStateLayer.containsMouse ? 0.18 : 0.1);
                    if (isCopy)
                        return Qt.alpha(Colours.palette.m3onSurface, actionStateLayer.containsMouse ? 0.1 : 0.05);
                    return actionStateLayer.containsMouse
                        ? Qt.alpha(Colours.palette.m3onSurface, 0.1)
                        : Qt.alpha(Colours.palette.m3onSurface, 0.06);
                }

                Behavior on color {
                    CAnim {}
                }

                Timer {
                    id: copyTimer

                    interval: 3000
                    onTriggered: {
                        if (actionInner.item && actionInner.item.text !== undefined)
                            actionInner.item.text = "content_copy";
                    }
                }

                StateLayer {
                    id: actionStateLayer

                    radius: action.isClose || action.isCopy
                        ? action.iconSize / 2
                        : parent.radius
                    color: action.isClose
                        ? Colours.palette.m3error
                        : Colours.palette.m3onSurface

                    onClicked: {
                        if (action.isClose) {
                            root.notif.close();
                        } else if (action.isCopy) {
                            Quickshell.clipboardText = root.notif.body;
                            if (actionInner.item && actionInner.item.text !== undefined)
                                actionInner.item.text = "inventory";
                            copyTimer.start();
                        } else {
                            let invoked = false;
                            if (typeof action.act?.invoke === "function") {
                                action.act.invoke();
                                invoked = true;
                            } else if (root.notif?.notification?.actions) {
                                const act = root.notif.notification.actions.find(a => a.identifier === (action.modelData.id || action.modelData.identifier));
                                if (act && typeof act.invoke === "function") {
                                    act.invoke();
                                    invoked = true;
                                }
                            }
                            if (invoked && !root.notif.resident) {
                                root.notif.close();
                            }
                        }
                    }
                }

                Loader {
                    id: actionInner

                    anchors.centerIn: parent
                    sourceComponent: action.isClose || action.isCopy
                        ? iconBtn
                        : (root.notif?.hasActionIcons && action.modelData.id)
                            ? iconComp
                            : textComp
                }

                Component {
                    id: iconBtn

                    MaterialIcon {
                        animate: action.isCopy
                        text: action.isCopy ? "content_copy" : "close"
                        color: action.isClose
                            ? Colours.palette.m3error
                            : Colours.palette.m3onSurfaceVariant
                        iconPointSize: Tokens.font.size.normal
                    }
                }

                Component {
                    id: iconComp

                    IconImage {
                        asynchronous: true
                        implicitSize: 14
                        source: Quickshell.iconPath(action.modelData.id || action.act?.identifier || "")
                    }
                }

                Component {
                    id: textComp

                    StyledText {
                        text: action.label
                        color: Colours.palette.m3onSurface
                        textPointSize: Tokens.font.size.small
                        font.weight: Font.Medium
                    }
                }
            }
        }

        // Push close (and lone copy) left when no primary actions
        Item {
            Layout.fillWidth: true
            visible: root.primaryCount === 0
        }
    }
}
