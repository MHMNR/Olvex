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
    property real offsetScale: shouldBeActive ? 0 : 1
    property real sidebarLerp
    readonly property bool needsKeyboard: (content.item as Content)?.needsKeyboard ?? false

    // Peek behavior: when hovered while closed and bottom panel is off, slide 7px into view
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
    // peekOffset pushes it INTO view from bottom; normal hide uses offsetScale
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale + peekOffset * offsetScale
    implicitHeight: content.implicitHeight + content.anchors.margins * 2
    implicitWidth: Tokens.sizes.utilities.width
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

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Tokens.padding.large

        asynchronous: true
        active: true

        sourceComponent: Content {
            implicitWidth: root.implicitWidth - content.anchors.margins * 2
            props: root.props
            visibilities: root.visibilities
            popouts: root.popouts
            deformMatrix: root.deformMatrix
        }
    }

    Connections {
        target: root.visibilities
        function onUtilitiesChanged() {
            if (!root.visibilities.utilities) {
                root.props.expansionActive = "";
                root.props.recordingListExpanded = false;
            }
        }
    }
}
