import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.components
import qs.services
import Olvex.Services
import Olvex.Config
import qs.utils
import qs.components.effects

Item {
    id: root
    readonly property var ydotool: Ydotool
    property var wordEngine: null  // OskWordEngine instance passed from parent
    
    property var keyData: null
    property string key: {
        if (!keyData) return "";
        let label = (keyData && keyData.label) ? keyData.label : "";
        let isShiftActive = ydotool.isShiftActive;
        let isCapsActive = ydotool.capsMode;
        
        // Shift affects everything (letters and symbols)
        if (isShiftActive) {
            if (keyData.labelShift) return keyData.labelShift;
            if (label.length === 1 && label.match(/[a-z]/i)) {
                return label.toUpperCase();
            }
        } 
        // Caps Lock ONLY affects letters
        else if (isCapsActive) {
            if (label.length === 1 && label.match(/[a-z]/i)) {
                return label.toUpperCase();
            }
        }
        return label;
    }
    property string type: keyData ? (keyData.keytype || "normal") : "normal"
    property var keycode: keyData ? (keyData.keycode || 0) : 0
    property string shape: keyData ? (keyData.shape || "normal") : "normal"
    
    signal hideRequested()
    signal layoutSwitchRequested(string targetLayout)
    
    property bool isShift: keyData && keyData.label ? (keyData.label.toLowerCase() == "shift" || keyData.label.toLowerCase() == "keyboard_arrow_up") : false
    property bool isCtrl: keyData && keyData.label ? (keyData.label.toLowerCase() == "ctrl" || keyData.label.toLowerCase() == "control") : false
    property bool isAlt: keyData && keyData.label ? (keyData.label.toLowerCase() == "alt") : false
    property bool isSuper: keyData && keyData.label ? (keyData.label.toLowerCase() == "super" || keyData.label.toLowerCase() == "win" || keyData.label.toLowerCase() == "meta") : false
    
    property bool isDualMod: (isShift || isSuper)
    property bool isToggleMod: (isCtrl || isAlt)
    property bool isComboMod: (isDualMod || isToggleMod)
    
    property bool isBackspace: (key && key.toLowerCase() == "backspace") || shape == "backspace"
    property bool isEnter: key ? (key.toLowerCase() == "enter" || key.toLowerCase() == "return" || key.toLowerCase() == "keyboard_return") : false
    property bool isCaps: key ? (key.toLowerCase() == "caps lock" || key.toLowerCase() == "caps" || key.toLowerCase() == "keyboard_capslock") : false
    property bool isNum: key ? (key.toLowerCase() == "numlk" || key.toLowerCase() == "num lock") : false
    property bool isEsc: key ? (key.toLowerCase() == "esc") : false
    property bool isFn: (root.shape == "fn")
    property bool isModifier: (root.type == "modkey" || root.shape == "control" || root.shape == "caps" || root.shape == "shift")
    
    readonly property bool isAnyShiftActive: ydotool.isShiftActive
    readonly property bool latched: ydotool.isLatched(root.keycode)
    readonly property bool locked: ydotool.isLocked(root.keycode)
    readonly property bool visualPressed: stateLayer.pressed

    readonly property bool toggled: {
        if (isShift) return ydotool.isShiftActive;
        if (isCtrl) return ydotool.isCtrlActive;
        if (isAlt) return ydotool.isAltActive;
        if (isSuper) return ydotool.isSuperActive;
        if (isCaps) return ydotool.capsMode;
        if (isNum) return ydotool.numMode;
        return latched || locked;
    }

    property real baseWidth: 55
    property real baseHeight: 55
    
    property var widthMultiplier: ({
        "normal": 1,
        "expand": 1.5,
        "tab": 1.5,
        "caps": 1.75,
        "shift": 2.25,
        "space": 6.25,
        "control": 1.5,
        "fn": 1
    })

    property var heightMultiplier: ({
        "normal": 1,
        "expand": 1,
        "tab": 1,
        "caps": 1,
        "shift": 1,
        "space": 1,
        "control": 1,
        "fn": 0.8
    })

    property real widthMultiplierOverride: 0

    implicitWidth: baseWidth * (widthMultiplierOverride > 0 ? widthMultiplierOverride : ((keyData ? keyData.width : 0) || widthMultiplier[shape] || 1))
    implicitHeight: baseHeight * (heightMultiplier[shape] || 1)
    

    property real widthExpansion: (root.visualPressed && !root.isLongPressed) ? 12 : 0
    Behavior on widthExpansion { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }

    // Main Container with Press Animation and Symmetrical Margins
    Item {
        id: container
        anchors.fill: parent
        clip: true
        anchors.leftMargin: 4 - root.widthExpansion / 2
        anchors.rightMargin: 4 - root.widthExpansion / 2
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        
        scale: (root.visualPressed && !root.isLongPressed) ? 0.98 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Rectangle {
            id: keyBg
            anchors.fill: parent
            radius: height / 2 // Pill shape
            color: {
                if (root.visualPressed) return Colours.palette.m3primary;
                if (isEnter) return Colours.palette.m3primary;
                if (isEsc) return Colours.palette.m3error;
                
                if (locked) return Colours.palette.m3primary;
                if (latched) return Qt.lighter(Colours.palette.m3primary, 1.2);
                if (toggled && (isCaps || isNum)) return Colours.palette.m3primary;
                
                if (isFn) return Colours.tPalette.m3surfaceVariant;
                if (isModifier) return Colours.tPalette.m3surfaceContainerHigh;
                
                return Colours.tPalette.m3surfaceContainer;
            }
            
            border.width: 0
            border.color: Qt.alpha(Colours.palette.m3onSurface, 0.1)

            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutQuad } }

            // Lock Indicator Dot
            Rectangle {
                visible: root.locked
                anchors.top: parent.top
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: 4
                height: 4
                radius: 2
                color: Colours.palette.m3onPrimary
            }

            // Press feedback — smooth color transition handles it via keyBg.color
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Colours.palette.m3onPrimary
                opacity: root.visualPressed ? 0.08 : 0
                Behavior on opacity { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
            }

            // Inner gloss/depth
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3onSurface, 0.05)
                visible: !root.isEnter && !toggled && !root.isEsc
            }
        }

        ColouredIcon {
            id: osLogoIcon
            anchors.centerIn: parent
            visible: root.isSuper
            source: SysInfo.osLogo
            implicitSize: 20
            colour: (root.visualPressed || root.toggled) ? Colours.palette.m3onPrimary : keyText.color
        }

        StyledText {
            id: keyText
            visible: !root.isSuper
            anchors.fill: parent
            anchors.margins: 6
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            fontSizeMode: Text.Fit
            minimumPixelSize: 10
            
            property bool isIcon: isBackspace || isEnter || isShift || isCaps || ((root.keyData && !!root.keyData.isIcon) || (root.keyData && !!root.keyData.isHide))
            font.family: isIcon ? "Material Symbols Rounded" : "Inter"
            font.pixelSize: isIcon ? 24 : (root.shape == "fn" ? 14 : 18)
            font.weight: (root.toggled || root.isEnter || root.isEsc) ? Font.Bold : Font.Normal
            font.features: isIcon ? ({"liga": 1}) : ({})
            color: {
                if (root.visualPressed) return Colours.palette.m3onPrimary;
                if (root.isEnter) return Colours.palette.m3onPrimary;
                if (root.isEsc) return Colours.palette.m3onError;
                if (root.toggled) return Colours.palette.m3onPrimary;
                return Colours.palette.m3onSurface;
            }
            text: {
                if (!root.keyData) return "";
                if (root.keyData.isHide) return "keyboard_hide";
                if (root.keyData.isIcon) return root.key;

                if (root.isBackspace) return "backspace";
                if (root.isEnter) return "keyboard_return";
                if (root.isShift) return "keyboard_arrow_up";
                if (root.isCaps) return "keyboard_capslock";
                return root.key;
            }
        }
    }

    property bool isLongPressed: false
    
    Timer {
        id: longPressTimer
        interval: 250
        onTriggered: root.isLongPressed = true
    }
    
    function handlePress() {
        root.isLongPressed = false;
        longPressTimer.start();

        if (root.keyData && root.keyData.isHide) { root.hideRequested(); return; }
        if (root.keyData && root.keyData.isLayoutSwitch) { root.layoutSwitchRequested(root.keyData.switchTarget); return; }
        if (root.keyData && root.keyData.isRawChar) { ydotool.typeString(root.keyData.rawChar); return; }

        if (root.keycode > 0) {
            const extraModifiers = (root.keyData && root.keyData.isShiftedKey) ? ["shift"] : [];
            ydotool.press(root.keycode, extraModifiers);

            if (wordEngine && !isModifier) {
                if (isBackspace) wordEngine.onBackspace();
                else if (isEnter) wordEngine.onChar("\n");
                else if (shape === "space") wordEngine.onChar(" ");
                else {
                    const label = root.keyData ? root.keyData.label : null;
                    if (label && label.length === 1) {
                        const ch = isAnyShiftActive ? ((root.keyData && root.keyData.labelShift) || label) : label;
                        wordEngine.onChar(ch);
                    }
                }
            }
        }
    }

    function handleRelease() {
        longPressTimer.stop();
        root.isLongPressed = false;

        if (root.keyData && root.keyData.isHide) return;
        if (root.keycode <= 0) return;
        ydotool.release(root.keycode);
    }

    StateLayer {
        id: stateLayer
        anchors.fill: parent
        radius: height / 2
        onPressed: root.handlePress()
        onReleased: root.handleRelease()
    }
}
