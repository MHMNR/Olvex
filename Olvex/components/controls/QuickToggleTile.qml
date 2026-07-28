import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services
import QtQuick.Effects

StyledRect {
    id: root

    property string icon
    property string label
    property string stateText
    property bool checked
    property bool toggle: true
    property bool disabled: false
    property bool isExpanding: false
    property bool isPanelVisible: true
    property int staggerIndex: 0
    readonly property bool isLowPower: PowerProfiles.profile === PowerProfile.PowerSaver

    // Perspective Kinetic Bloom Animation (Opening Only)
    property bool _ready: false
    Component.onCompleted: Qt.callLater(() => _ready = true)

    state: root.isExpanding ? "expanding" : ((isPanelVisible && _ready) ? "visible" : "hidden")

    transform: [
        Translate {
            id: trans
            x: -20
            y: root.isLowPower ? 0 : 20
        },
        Scale {
            id: scale
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: root.isLowPower ? 1.0 : 0.8
            yScale: root.isLowPower ? 1.0 : 1.1
        }
    ]

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: root; opacity: 0 }
            PropertyChanges { target: trans; x: -20; y: root.isLowPower ? 0 : 20 }
            PropertyChanges { target: scale; xScale: root.isLowPower ? 1.0 : 0.8; yScale: root.isLowPower ? 1.0 : 1.1 }
        },
        State {
            name: "visible"
            PropertyChanges { target: root; opacity: 1 }
            PropertyChanges { target: trans; x: 0; y: 0 }
            PropertyChanges { target: scale; xScale: 1.0; yScale: 1.0 }
        },
        State {
            name: "expanding"
            PropertyChanges { target: root; opacity: 0 }
            PropertyChanges { target: trans; x: 0; y: 0 }
            PropertyChanges { target: scale; xScale: 1.0; yScale: 1.0 }
        }
    ]

    transitions: Transition {
        from: "hidden"; to: "visible"
        SequentialAnimation {
            PauseAnimation { duration: root.isLowPower ? 0 : root.staggerIndex }
            ParallelAnimation {
                NumberAnimation { target: root; property: "opacity"; duration: root.isLowPower ? 150 : 400; easing.type: Easing.OutCubic }
                NumberAnimation { target: trans; properties: "x,y"; duration: root.isLowPower ? 200 : 900; easing.type: Easing.OutExpo }
                NumberAnimation { 
                    target: scale; properties: "xScale,yScale"; duration: root.isLowPower ? 200 : 1000; 
                    easing.type: Easing.OutExpo
                }
            }
        }
    }

    opacity: isExpanding ? 0 : 1

    property color activeColour:    Colours.palette.m3primary
    property color inactiveColour:  Colours.tPalette.m3surfaceVariant
    property color activeOnColour:  Colours.palette.m3onPrimary
    property color inactiveOnColour: Colours.palette.m3onSurface
    property color disabledColour:  Qt.alpha(Colours.palette.m3onSurface, 0.12)
    property color disabledOnColour: Qt.alpha(Colours.palette.m3onSurface, 0.38)

    signal clicked
    signal held

    implicitWidth: 100
    implicitHeight: 110
    radius: 32
    color: Qt.rgba(1.0, 1.0, 1.0, 0.03)
    border.color: Qt.alpha("#ff99cc", 0.12)
    border.width: 1

    Behavior on radius { Anim { type: Anim.FastSpatial } }
    Behavior on scale { Anim {} }
    
    scale: mouseArea.pressed ? 0.92 : (mouseArea.containsMouse ? 1.03 : 1)

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.disabled
        cursorShape: enabled ? Qt.PointingHandCursor : undefined
        onClicked: root.clicked()
        onPressAndHold: root.held()
    }

    ColumnLayout {
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        StyledRect {
            id: iconPill
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.checked ? 100 : 55
            Layout.preferredHeight: 55
            radius: height / 2
            color: root.disabled ? root.disabledColour
                 : root.checked ? root.activeColour
                 : root.inactiveColour

            Behavior on Layout.preferredWidth { Anim { type: Anim.FastSpatial } }
            Behavior on Layout.preferredHeight { Anim { type: Anim.FastSpatial } }
            Behavior on radius { Anim { type: Anim.FastSpatial } }

             MaterialIcon {
                anchors.centerIn: parent
                text: root.icon
                fill: !root.toggle || root.checked ? 1 : 0
                color: root.disabled ? root.disabledOnColour
                     : root.checked ? root.activeOnColour
                     : root.inactiveOnColour
             iconPointSize: Tokens.font.size.large

                Behavior on fill { Anim {} }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

                Item {
                    id: marqueeContainer
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.width - 24
                    Layout.preferredHeight: labelText.implicitHeight
                    clip: true

                    readonly property bool needsMarquee: labelText.implicitWidth > width
                    readonly property real speed: 30 // pixels per second

                    // Edge Fading Mask
                    layer.enabled: needsMarquee
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: ShaderEffectSource {
                            sourceItem: Rectangle {
                                width: marqueeContainer.width
                                height: marqueeContainer.height
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.1; color: "black" }
                                    GradientStop { position: 0.9; color: "black" }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }
                        }
                    }

                    Row {
                        id: marqueeRow
                        spacing: 40
                        property real marqueeX: 0

                        anchors.horizontalCenter: marqueeContainer.needsMarquee ? undefined : marqueeContainer.horizontalCenter
                        x: marqueeContainer.needsMarquee ? marqueeRow.marqueeX : 0

                        StyledText {
                            id: labelText
                            text: root.label
                            textPointSize: Tokens.font.size.small
                            font.bold: true
                            color: root.disabled ? root.disabledOnColour
                                 : root.checked ? Colours.palette.m3onSurface
                                 : root.inactiveOnColour
                        }

                        // Duplicate text for seamless loop
                        StyledText {
                            text: labelText.text
                            font: labelText.font
                            color: labelText.color
                            visible: marqueeContainer.needsMarquee
                        }

                        SequentialAnimation {
                            id: marqueeAnim
                            running: marqueeContainer.needsMarquee && root.isPanelVisible
                            loops: Animation.Infinite

                            PauseAnimation { duration: 2500 }

                            NumberAnimation {
                                target: marqueeRow
                                property: "marqueeX"
                                from: 0
                                to: -(labelText.implicitWidth + 40)
                                duration: Math.max(3000, (labelText.implicitWidth) * 1000 / marqueeContainer.speed)
                                easing.type: Easing.InOutQuad
                            }

                            PauseAnimation { duration: 1500 }

                            PropertyAnimation { target: marqueeRow; property: "opacity"; to: 0; duration: 400 }
                            PropertyAction { target: marqueeRow; property: "marqueeX"; value: 0 }
                            PropertyAnimation { target: marqueeRow; property: "opacity"; to: 1; duration: 400 }
                        }
                    }
                }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.stateText
                textPointSize: Tokens.font.size.small - 2
                color: root.disabled ? root.disabledOnColour
                     : root.inactiveOnColour
                opacity: 0.8
            }
        }
    }
}
