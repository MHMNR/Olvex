pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Olvex.Config
import qs.components
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    property real horizontalStretch
    property matrix4x4 deformMatrix

    readonly property PersistentProperties props: PersistentProperties {
        property bool recordingListExpanded: false
        property string recordingConfirmDelete
        property string recordingMode
        property string recordingFps: "60"

        property string expansionActive: ""
        property bool isTransitioning: false
        property rect expansionSource: Qt.rect(0, 0, 0, 0)
        property point expansionLocalSource: Qt.point(0, 0)
        property Item expansionSourceItem
        
        property real expansionYOffset: 40
        property real expansionBgOpacity: 0.3
        property real expansionBgBlur: 1.0
        property real expansionCardOpacity: 1.0
        property real expansionCardScale: 1.0

        reloadableId: "utilities"
    }
    readonly property bool shouldBeActive: visibilities.utilities && Config.utilities.enabled && !(visibilities.session && Config.session.enabled)
    readonly property bool contentReady: content.status === Loader.Ready
    property bool openAnimationReady: false
    property real offsetScale: shouldBeActive && openAnimationReady ? 0 : 1
    property real sidebarLerp
    readonly property bool needsKeyboard: (content.item as Content)?.needsKeyboard ?? false
    readonly property bool contentActive: root.shouldBeActive || root.visible

    // Peek: when hovered while closed and bottom panel is off, slide a strip in from the right
    property bool hovered: false
    readonly property bool bottomPanelOff: !(Config.bar.bottomPanel?.enabled ?? true)
    property real peekOffset: (hovered && !shouldBeActive && bottomPanelOff) ? 17 : 0

    Behavior on peekOffset {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    visible: offsetScale < 1 || (peekOffset > 0 && Config.utilities.enabled)
    // Render to offscreen layer during peek so the rounded corner is anti-aliased
    // at the screen-edge clip boundary instead of appearing jaggy
    layer.enabled: peekOffset > 0 && !shouldBeActive
    layer.smooth: true
    // Slide from right → left: offsetScale 1 = fully off-screen right, 0 = docked
    // peekOffset pulls a thin strip into view while closed
    anchors.rightMargin: (-implicitWidth - 5) * offsetScale + peekOffset * offsetScale
    // Height comes from Panels anchors (top + bottom) — full column
    implicitWidth: Tokens.sizes.utilities.width
    // Fallback when not yet anchored
    implicitHeight: parent ? parent.height : ((content.item?.implicitHeight || 0) + content.anchors.margins * 2)
    opacity: (hovered || peekOffset > 0) ? 1 : 1 - (offsetScale * offsetScale)

    states: State {
        name: "attachedToSidebar"
        when: root.visibilities.sidebar

        PropertyChanges {
            root.sidebarLerp: 1
        }
    }

    transitions: [
        Transition {
            from: ""

            Anim {
                property: "sidebarLerp"
                duration: Tokens.anim.durations.expressiveDefaultSpatial / 2
                easing: Tokens.anim.standardAccel
            }
        },
        Transition {
            to: ""

            Anim {
                property: "sidebarLerp"
                duration: Tokens.anim.durations.expressiveDefaultSpatial / 2
                easing: Tokens.anim.standardDecel
            }
        }
    ]

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Loader {
        id: content

        anchors.fill: parent
        anchors.margins: Tokens.padding.large

        asynchronous: true
        active: root.contentActive

        onStatusChanged: {
            if (status === Loader.Ready && root.shouldBeActive)
                Qt.callLater(() => root.openAnimationReady = true);
        }

        sourceComponent: Content {
            // Fill the loader so ColumnLayout can expand the notification tile
            width: content.width
            height: content.height
            props: root.props
            visibilities: root.visibilities
            popouts: root.popouts
            deformMatrix: root.deformMatrix
        }
    }

    Connections {
        target: root.visibilities
        function onUtilitiesChanged() {
            if (root.visibilities.utilities) {
                root.openAnimationReady = false;
                Qt.callLater(() => {
                    if (root.contentReady)
                        root.openAnimationReady = true;
                });
            } else {
                root.openAnimationReady = false;
            }

            if (!root.visibilities.utilities) {
                root.props.expansionActive = "";
                root.props.recordingListExpanded = false;
            }
        }
    }
}
