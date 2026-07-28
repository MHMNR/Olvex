pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Olvex.Config
import qs.components
import qs.services

TextField {
    id: root

    color: Colours.palette.m3onSurface
    placeholderTextColor: Colours.palette.m3outline
    font.family: Tokens.font.family.sans
    font.pixelSize: Math.max(10, Math.round(Tokens.font.size.smaller * 96 / 72))
    renderType: echoMode === TextField.Password ? TextField.QtRendering : TextField.NativeRendering
    cursorVisible: !readOnly

    leftPadding: 12
    rightPadding: 12
    topPadding: 8
    bottomPadding: 8

    background: StyledRect {
        implicitHeight: 36
        implicitWidth: 120
        radius: Tokens.rounding.normal
        color: Colours.palette.m3surfaceVariant
        
        border.color: root.activeFocus ? Colours.palette.m3primary : "transparent"
        border.width: root.activeFocus ? 2 : 0
        
        Behavior on border.color { CAnim {} }
    }

    cursorDelegate: StyledRect {
        id: cursor

        property bool disableBlink

        implicitWidth: 2
        color: Colours.palette.m3primary
        radius: Tokens.rounding.normal

        Connections {
            function onCursorPositionChanged(): void {
                if (root.activeFocus && root.cursorVisible) {
                    cursor.opacity = 1;
                    cursor.disableBlink = true;
                    enableBlink.restart();
                }
            }

            target: root
        }

        Timer {
            id: enableBlink

            interval: 100
            onTriggered: cursor.disableBlink = false
        }

        Timer {
            running: root.activeFocus && root.cursorVisible && !cursor.disableBlink
            repeat: true
            triggeredOnStart: true
            interval: 500
            onTriggered: parent.opacity = parent.opacity === 1 ? 0 : 1
        }

        Binding {
            when: !root.activeFocus || !root.cursorVisible
            cursor.opacity: 0
        }

        Behavior on opacity {
            Anim {
                type: Anim.StandardSmall
            }
        }
    }

    Behavior on color {
        CAnim {}
    }

    Behavior on placeholderTextColor {
        CAnim {}
    }
}
