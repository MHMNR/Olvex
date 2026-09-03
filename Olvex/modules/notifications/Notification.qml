
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

// Heads-up popup toast — card sits on the notifs stack container blob (blur).
StyledRect {
    id: root

    required property NotifData modelData

    // image://icon/* is a theme icon name, not a bitmap — must not load as Image@36
    readonly property string rawImage: String(modelData.image ?? "")
    readonly property string imageIconName: Icons.iconNameFromUrl(rawImage)
    readonly property bool hasImage: rawImage.length > 0 && imageIconName.length === 0
    readonly property bool hasAppIcon: modelData.appIcon.length > 0 || imageIconName.length > 0
    readonly property bool isCritical: modelData.urgency === NotificationUrgency.Critical
    readonly property bool isLow: modelData.urgency === NotificationUrgency.Low
    readonly property int bodyTextFormat: /[<*_`#\[\]]/.test(modelData.body) ? Text.MarkdownText : Text.PlainText
    readonly property string bodyText: String(modelData.body ?? "").trim()
    readonly property bool hasBody: bodyText.length > 0
    readonly property int avatarSize: 36
    readonly property int badgeSize: 16

    // Theme icons (esp. *-symbolic) fail at arbitrary sizes via image://icon.
    // Always resolve to file:// (or empty → MaterialIcon). Never pass image://icon.
    readonly property string resolvedAppIcon: {
        const candidates = [
            String(modelData.appIcon ?? ""),
            imageIconName,
            "dialog-information"
        ];
        for (let i = 0; i < candidates.length; i++) {
            const icon = candidates[i];
            if (!icon.length)
                continue;
            let path = Icons.resolveIcon(icon, "");
            if (path.startsWith("file://") || path.startsWith("/"))
                return path.startsWith("/") ? ("file://" + path) : path;
            if (icon.endsWith("-symbolic")) {
                path = Icons.resolveIcon(icon.slice(0, -9), "");
                if (path.startsWith("file://") || path.startsWith("/"))
                    return path.startsWith("/") ? ("file://" + path) : path;
            }
        }
        return "";
    }
    readonly property bool hasResolvableAppIcon: resolvedAppIcon.length > 0

    readonly property color urgencyAccent: isCritical
        ? Colours.palette.m3error
        : isLow
            ? Colours.palette.m3surfaceContainerHighest
            : Colours.palette.m3secondaryContainer
    readonly property color urgencyOnAccent: isCritical
        ? Colours.palette.m3onError
        : isLow
            ? Colours.palette.m3onSurface
            : Colours.palette.m3onSecondaryContainer

    readonly property int nonAnimHeight: {
        const pad = Tokens.padding.normal * 2;
        const textBlock = summaryRow.implicitHeight
            + (root.expanded
                ? (hasBody ? bodySlot.height + Tokens.spacing.smaller : 0)
                    + (appNameSlot.height > 0 ? appNameSlot.height + 2 : 0)
                    + (actionsSlot.height > 0 ? actionsSlot.height + Tokens.spacing.small : 0)
                : (hasBody ? bodyPreviewSlot.height + 2 : 0));
        return Math.round(Math.max(avatarSize, textBlock) + pad);
    }

    property bool expanded: Config.notifs.openExpanded

    color: isCritical
        ? Qt.alpha(Colours.palette.m3errorContainer, 0.72)
        : Colours.notifTileFill
    border.width: 1
    border.color: isCritical
        ? Qt.alpha(Colours.palette.m3error, 0.28)
        : Colours.tileStrokeSubtle
    radius: Tokens.rounding.large
    // Resolve sizes on this Item (screen Tokens via window tree) — never on Anim
    readonly property int notifWidth: Tokens.sizes.notifs.width
    implicitWidth: notifWidth
    implicitHeight: nonAnimHeight
    clip: false
    antialiasing: true

    // Soft inner rim
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, parent.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: Colours.tileInnerLine
        z: 0
        antialiasing: true
    }

    // Slide in from off-screen using Item property (not Anim-scoped Tokens.sizes)
    x: notifWidth
    Component.onCompleted: {
        x = 0;
        modelData.lock(this);
    }
    Component.onDestruction: modelData.unlock(this)

    Behavior on x {
        Anim {
            easing: Tokens.anim.emphasizedDecel
        }
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on color {
        CAnim {}
    }

    MouseArea {
        property int startY

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.expanded && body.hoveredLink ? Qt.PointingHandCursor : pressed ? Qt.ClosedHandCursor : undefined
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: true
        z: 1

        onEntered: root.modelData.timer.stop()
        onExited: {
            if (!pressed)
                root.modelData.timer.start();
        }

        drag.target: parent
        drag.axis: Drag.XAxis

        onPressed: event => {
            root.modelData.timer.stop();
            startY = event.y;
            if (event.button === Qt.MiddleButton)
                root.modelData.close();
        }
        onReleased: event => {
            if (!containsMouse)
                root.modelData.timer.start();

            if (Math.abs(root.x) < root.notifWidth * Config.notifs.clearThreshold)
                root.x = 0;
            else
                root.modelData.popup = false;
        }
        onPositionChanged: event => {
            if (pressed) {
                const diffY = event.y - startY;
                if (Math.abs(diffY) > Config.notifs.expandThreshold)
                    root.expanded = diffY > 0;
            }
        }
        onClicked: event => {
            if (!GlobalConfig.notifs.actionOnClick || event.button !== Qt.LeftButton)
                return;

            const acts = root.modelData.actions;
            if (acts.length === 1)
                acts[0].invoke();
        }

        Item {
            id: inner

            anchors.fill: parent
            anchors.margins: Tokens.padding.normal

            // ── Avatar ──
            Item {
                id: avatarHost

                anchors.left: parent.left
                anchors.top: parent.top
                width: root.avatarSize
                height: root.avatarSize

                StyledClippingRect {
                    id: avatarBg
                    radius: width / 2
                    color: root.urgencyAccent
                    anchors.fill: parent
                    visible: root.hasImage

                    Loader {
                        id: image

                        asynchronous: true
                        active: root.hasImage
                        anchors.fill: parent

                        sourceComponent: Item {
                            anchors.fill: parent

                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl(root.rawImage)
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: root.avatarSize
                                sourceSize.height: root.avatarSize
                                cache: false
                                asynchronous: true
                            }
                        }
                    }
                }

                Loader {
                    id: appIcon

                    asynchronous: true
                    active: root.hasAppIcon || !root.hasImage
                    anchors.horizontalCenter: root.hasImage ? undefined : parent.horizontalCenter
                    anchors.verticalCenter: root.hasImage ? undefined : parent.verticalCenter
                    anchors.right: root.hasImage ? parent.right : undefined
                    anchors.bottom: root.hasImage ? parent.bottom : undefined

                    sourceComponent: StyledRect {
                        radius: width / 2
                        color: root.urgencyAccent
                        implicitWidth: root.hasImage ? root.badgeSize : root.avatarSize
                        implicitHeight: root.hasImage ? root.badgeSize : root.avatarSize
                        border.width: root.hasImage ? 1.5 : 0
                        border.color: root.color

                        Loader {
                            asynchronous: true
                            active: root.hasResolvableAppIcon
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.55)
                            height: Math.round(parent.width * 0.55)

                            sourceComponent: ColouredIcon {
                                anchors.fill: parent
                                // file:// only — never image://icon
                                source: root.resolvedAppIcon
                                colour: root.urgencyOnAccent
                                // Colourise monochrome SVGs (symbolic names or paths)
                                layer.enabled: String(root.modelData.appIcon).endsWith("symbolic")
                                    || root.imageIconName.endsWith("symbolic")
                                    || root.resolvedAppIcon.indexOf("symbolic") >= 0
                            }
                        }

                        Loader {
                            asynchronous: true
                            active: !root.hasResolvableAppIcon
                            anchors.centerIn: parent

                            sourceComponent: MaterialIcon {
                                text: Icons.getNotifIcon(root.modelData.summary, root.modelData.urgency)
                                color: root.urgencyOnAccent
                                iconPointSize: Tokens.font.size.normal
                            }
                        }
                    }
                }

                // Progress ring (hints.value)
                Shape {
                    id: progressIndicator

                    anchors.centerIn: parent
                    width: root.avatarSize + progressShape.strokeWidth * 2
                    height: root.avatarSize + progressShape.strokeWidth * 2
                    preferredRendererType: Shape.CurveRenderer
                    visible: (root.modelData.hints.value ?? -1) >= 0

                    ShapePath {
                        id: progressShape

                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        strokeWidth: 2
                        strokeColor: Colours.palette.m3primary

                        PathAngleArc {
                            radiusX: progressIndicator.width / 2 - 1
                            centerX: progressIndicator.width / 2
                            radiusY: progressIndicator.height / 2 - 1
                            centerY: progressIndicator.height / 2
                            startAngle: -90
                            sweepAngle: ((root.modelData.hints.value ?? 0) / 100) * 360

                            Behavior on sweepAngle {
                                Anim {
                                    easing: Tokens.anim.emphasizedDecel
                                }
                            }
                        }
                    }
                }
            }

            // ── Text column ──
            Column {
                id: textCol

                anchors.left: avatarHost.right
                anchors.right: expandBtn.left
                anchors.top: parent.top
                anchors.leftMargin: Tokens.spacing.small
                anchors.rightMargin: Tokens.spacing.smaller
                spacing: 2

                // Expanded: app name above summary
                // Clip wrapper avoids Text height↔visible / height↔implicitHeight binding loops
                Item {
                    id: appNameSlot

                    width: parent.width
                    height: root.expanded ? appName.implicitHeight : 0
                    clip: true
                    opacity: root.expanded ? 1 : 0

                    Behavior on height {
                        Anim {
                            type: Anim.DefaultSpatial
                        }
                    }
                    Behavior on opacity {
                        Anim {}
                    }

                    StyledText {
                        id: appName

                        width: parent.width
                        animate: true
                        text: root.modelData.appName
                        color: Colours.palette.m3outline
                        textPointSize: Tokens.font.size.small
                        font.weight: Font.Medium
                        font.letterSpacing: 0.15
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                // Summary · time
                RowLayout {
                    id: summaryRow

                    width: parent.width
                    spacing: Tokens.spacing.smaller

                    StyledText {
                        id: summary

                        Layout.fillWidth: true
                        animate: true
                        text: root.modelData.summary
                        color: root.isCritical
                            ? Colours.palette.m3onErrorContainer
                            : Colours.palette.m3onSurface
                        textPointSize: Tokens.font.size.small
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                        maximumLineCount: root.expanded ? 4 : 1
                        lineHeight: 1.15
                        lineHeightMode: Text.ProportionalHeight
                    }

                    StyledText {
                        text: "·"
                        color: Colours.palette.m3outline
                        textPointSize: Tokens.font.size.small
                        opacity: 0.7
                        Layout.alignment: Qt.AlignTop
                        visible: !root.expanded
                    }

                    StyledText {
                        id: time

                        animate: true
                        text: root.modelData.timeStr
                        color: Colours.palette.m3outline
                        textPointSize: Tokens.font.size.small
                        font.family: Tokens.font.family.mono
                        opacity: 0.9
                        Layout.alignment: Qt.AlignTop
                        visible: !root.expanded
                    }
                }

                // Collapsed body preview — clip slot, no height on StyledText
                Item {
                    id: bodyPreviewSlot

                    width: parent.width
                    height: (!root.expanded && root.hasBody) ? bodyPreview.implicitHeight : 0
                    clip: true
                    visible: height > 0

                    StyledText {
                        id: bodyPreview

                        width: parent.width
                        animate: true
                        textFormat: root.bodyTextFormat
                        text: bodyPreviewMetrics.elidedText
                        color: root.isCritical
                            ? Colours.palette.m3onErrorContainer
                            : Colours.palette.m3onSurfaceVariant
                        textPointSize: Tokens.font.size.small
                        opacity: 0.9
                        maximumLineCount: 1
                        elide: Text.ElideRight

                        TextMetrics {
                            id: bodyPreviewMetrics

                            text: root.bodyText.replace(/\n/g, " ")
                            font.family: bodyPreview.font.family
                            font.pixelSize: bodyPreview.resolvedPixelSize
                            elide: Text.ElideRight
                            elideWidth: Math.max(0, bodyPreview.width)
                        }
                    }
                }

                // Expanded body — clip slot avoids wrap Text height binding loop
                Item {
                    id: bodySlot

                    width: parent.width
                    height: (root.expanded && root.hasBody) ? body.implicitHeight : 0
                    clip: true
                    visible: height > 0

                    StyledText {
                        id: body

                        width: parent.width
                        animate: true
                        textFormat: root.bodyTextFormat
                        text: root.bodyText
                        color: root.isCritical
                            ? Colours.palette.m3onErrorContainer
                            : Colours.palette.m3onSurfaceVariant
                        textPointSize: Tokens.font.size.small
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        opacity: 0.95
                        lineHeight: 1.25
                        lineHeightMode: Text.ProportionalHeight

                        onLinkActivated: link => {
                            Quickshell.execDetached(["app2unit", "-O", "--", link]);
                            root.modelData.popup = false;
                        }
                    }
                }

                // Actions (expanded only)
                Item {
                    id: actionsSlot

                    width: parent.width
                    height: root.expanded ? actions.implicitHeight : 0
                    clip: true
                    opacity: root.expanded ? 1 : 0
                    visible: height > 0

                    Behavior on opacity {
                        Anim {}
                    }

                    RowLayout {
                        id: actions

                        width: parent.width
                        spacing: Tokens.spacing.smaller

                    // Close — perfect circle, no border
                    StyledRect {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        Layout.minimumWidth: 28
                        Layout.maximumWidth: 28
                        radius: 14
                        border.width: 0
                        color: Qt.alpha(Colours.palette.m3error, closeLayer.containsMouse ? 0.18 : 0.1)

                        Behavior on color {
                            CAnim {}
                        }

                        StateLayer {
                            id: closeLayer
                            radius: 14
                            color: Colours.palette.m3error
                            onClicked: root.modelData.close()
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            color: Colours.palette.m3error
                            iconPointSize: Tokens.font.size.normal
                        }
                    }

                    Repeater {
                        model: {
                            const out = [];
                            const acts = root.modelData.actions ?? [];
                            const useIcons = !!root.modelData.hasActionIcons;
                            for (let i = 0; i < acts.length; i++) {
                                const a = acts[i];
                                const label = String(a?.text ?? "").trim();
                                const id = String(a?.identifier ?? "").trim();
                                if (!label && !(useIcons && id && id !== "default"))
                                    continue;
                                out.push(a);
                            }
                            return out;
                        }

                        StyledRect {
                            id: actionBtn

                            required property var modelData

                            readonly property string label: String(modelData?.text ?? "").trim()

                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            Layout.minimumWidth: 48
                            radius: Tokens.rounding.full
                            border.width: 0
                            color: Qt.alpha(Colours.palette.m3onSurface, actionLayer.containsMouse ? 0.12 : 0.07)

                            Behavior on color {
                                CAnim {}
                            }

                            StateLayer {
                                id: actionLayer
                                radius: parent.radius
                                color: Colours.palette.m3onSurface
                                onClicked: {
                                    if (typeof actionBtn.modelData.invoke === "function") {
                                        actionBtn.modelData.invoke();
                                    } else if (root.modelData?.notification?.actions) {
                                        const act = root.modelData.notification.actions.find(a => a.identifier === (actionBtn.modelData.identifier || actionBtn.modelData.id));
                                        if (act && typeof act.invoke === "function")
                                            act.invoke();
                                    }
                                    if (!root.modelData.resident)
                                        root.modelData.popup = false;
                                }
                            }

                            StyledText {
                                anchors.centerIn: parent
                                width: parent.width - Tokens.padding.small * 2
                                horizontalAlignment: Text.AlignHCenter
                                text: actionBtn.label
                                color: Colours.palette.m3onSurface
                                textPointSize: Tokens.font.size.small
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                visible: actionBtn.label.length > 0
                            }

                            Loader {
                                anchors.centerIn: parent
                                active: actionBtn.label.length === 0 && root.modelData.hasActionIcons
                                    && Icons.resolveIcon(actionBtn.modelData?.identifier ?? "", "").length > 0
                                sourceComponent: IconImage {
                                    asynchronous: true
                                    implicitSize: 14
                                    source: Icons.resolveIcon(actionBtn.modelData?.identifier ?? "", "")
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        visible: {
                            const acts = root.modelData.actions ?? [];
                            let n = 0;
                            for (let i = 0; i < acts.length; i++) {
                                const label = String(acts[i]?.text ?? "").trim();
                                const id = String(acts[i]?.identifier ?? "").trim();
                                if (label || (root.modelData.hasActionIcons && id && id !== "default"))
                                    n++;
                            }
                            return n === 0;
                        }
                    }
                    } // RowLayout actions
                } // Item actionsSlot
            } // textCol

            // Expand chip — soft circle, no outline
            StyledRect {
                id: expandBtn

                anchors.right: parent.right
                anchors.top: parent.top
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                border.width: 0
                color: Qt.alpha(Colours.palette.m3onSurface, expandLayer.containsMouse ? 0.12 : 0.06)

                Behavior on color {
                    CAnim {}
                }

                StateLayer {
                    id: expandLayer
                    radius: 14
                    color: root.isCritical
                        ? Colours.palette.m3onErrorContainer
                        : Colours.palette.m3onSurface
                    onClicked: root.expanded = !root.expanded
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    animate: true
                    text: root.expanded ? "expand_less" : "expand_more"
                    color: Colours.palette.m3onSurfaceVariant
                    iconPointSize: Tokens.font.size.normal
                }
            }

            // Expanded time (top-right under expand is crowded — put under expand when open)
            StyledText {
                anchors.right: parent.right
                anchors.top: expandBtn.bottom
                anchors.topMargin: 2
                visible: root.expanded
                animate: true
                text: root.modelData.timeStr
                color: Colours.palette.m3outline
                textPointSize: Tokens.font.size.small
                font.family: Tokens.font.family.mono
                opacity: 0.85
            }
        }
    }
}
