pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services
import QtCore

Item {
    id: root

    implicitWidth: 980
    implicitHeight: 460

    readonly property var m3Emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]
    readonly property color glassFill: Colours.tileSurface
    readonly property color glassStroke: Colours.tileStroke
    readonly property color glassHighlight: Colours.tileInnerLine
    readonly property color glassTileFill: Colours.tileFillElevated
    readonly property color glassTileStroke: Colours.tileStroke

    property string expression: ""
    property string liveResult: ""
    property bool isFinalized: false
    
    // History State
    property var historyList: []
    property bool showHistory: false
    readonly property int historyLimit: 100

    Settings {
        id: calcSettings
        category: "Calculator"
        property alias expression: root.expression
        property alias isFinalized: root.isFinalized
        property string historyJson: "[]"
    }

    function normalizeHistory(list) {
        if (!Array.isArray(list))
            return [];
        return list.filter(item => item
            && typeof item === "object"
            && typeof item.equation === "string"
            && typeof item.result === "string");
    }

    Component.onCompleted: {
        try {
            if (calcSettings.historyJson) {
                root.historyList = normalizeHistory(JSON.parse(calcSettings.historyJson));
            }
        } catch(e) {}
        
        // Restore liveResult safely from restored expression
        if (root.expression !== "") {
            root.liveResult = root.evaluateExpression(root.expression);
        }
    }

    onHistoryListChanged: {
        calcSettings.historyJson = JSON.stringify(root.historyList);
    }

    function syncExprDisplay(moveCursorToEnd) {
        exprText.text = root.expression === "" ? "0" : formatExpression(root.expression);
        if (moveCursorToEnd)
            exprText.cursorPosition = exprText.text.length;
    }

    function parseHistoryEquation(equation) {
        if (!equation)
            return "";
        return equation.replace(/\s*=$/, "").replace(/,/g, "").trim();
    }

    function selectHistoryResult(index) {
        const entry = root.historyList[index];
        if (!entry?.result)
            return;

        const clean = entry.result.replace(/,/g, "");
        root.expression = clean;
        root.liveResult = entry.result;
        root.isFinalized = true;
        syncExprDisplay(true);
        root.showHistory = false;
    }

    function selectHistoryEquation(index) {
        const entry = root.historyList[index];
        if (!entry?.equation)
            return;

        const expr = parseHistoryEquation(entry.equation);
        root.expression = expr;
        root.isFinalized = false;
        root.liveResult = evaluateExpression(expr);
        syncExprDisplay(true);
        root.showHistory = false;
    }

    function clearHistory() {
        root.historyList = [];
    }

    function formatNumberString(str) {
        let split = str.split(".");
        split[0] = split[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
        return split.join(".");
    }

    function formatExpression(expr) {
        if (!expr) return "";
        let parts = expr.split(/([+\-×÷()%])/);
        for (let i = 0; i < parts.length; i++) {
            if (!["+", "-", "×", "÷", "(", ")", "%"].includes(parts[i]) && parts[i] !== "") {
                let cleanNum = parts[i].replace(/,/g, '');
                parts[i] = formatNumberString(cleanNum);
            }
        }
        return parts.join("");
    }

    function evaluateExpression(expr) {
        if (!expr) return "";
        try {
            let safeExpr = expr.replace(/×/g, '*').replace(/÷/g, '/');
            safeExpr = safeExpr.replace(/(\d)\(/g, '$1*(');
            safeExpr = safeExpr.replace(/\)(\d)/g, ')*$1');
            safeExpr = safeExpr.replace(/%/g, '/100');
            // QML V4 Engine runs in strict mode and will throw SyntaxError on octals (like "07")
            safeExpr = safeExpr.replace(/\b0+(\d)/g, '$1'); 
            safeExpr = safeExpr.replace(/[+\-*/.]$/, ''); // Remove trailing operators
            
            let openCount = (safeExpr.match(/\(/g) || []).length;
            let closeCount = (safeExpr.match(/\)/g) || []).length;
            for (let i = 0; i < openCount - closeCount; i++) {
                safeExpr += ")";
            }

            if (safeExpr === "") return "";
            
            const result = new Function('return (' + safeExpr + ')')();

            if (result === undefined || result === null) return "";
            if (isNaN(result)) return "Error";
            if (!isFinite(result)) return result > 0 ? "∞" : "-∞";

            const formatted = String(parseFloat(result.toPrecision(12)));
            return formatNumberString(formatted);
        } catch (e) {
            return "";
        }
    }

    onExpressionChanged: {
        liveResult = evaluateExpression(expression);
    }

    function calculateResult() {
        if (root.expression === "" || isFinalized) return;
        
        let result = evaluateExpression(root.expression);
        if (result === "" || result === "Error") return;

        const equation = formatExpression(root.expression) + " =";
        const last = root.historyList[0];
        if (!last || last.equation !== equation || last.result !== result) {
            let currentHistory = root.historyList.slice();
            currentHistory.unshift({ equation, result });
            if (currentHistory.length > root.historyLimit)
                currentHistory = currentHistory.slice(0, root.historyLimit);
            root.historyList = currentHistory;
        }

        liveResult = result;
        isFinalized = true;
        syncExprDisplay(true);
    }

    function insertAtCursor(str) {
        if (isFinalized) {
            if (["+", "-", "×", "÷"].includes(str)) {
                root.expression = root.liveResult.replace(/,/g, '') + str;
            } else {
                root.expression = str;
            }
            isFinalized = false;
            exprText.text = formatExpression(root.expression);
            exprText.cursorPosition = exprText.text.length;
            liveResult = evaluateExpression(root.expression);
            return;
        }

        // Clean slate if empty (prevents merging with the placeholder "0")
        if (root.expression === "") {
            if (["+", "×", "÷"].includes(str)) {
                root.expression = "0" + str;
            } else {
                root.expression = str;
            }
            exprText.text = formatExpression(root.expression);
            exprText.cursorPosition = exprText.text.length;
            liveResult = evaluateExpression(root.expression);
            return;
        }
        
        let cp = exprText.cursorPosition;
        let pre = exprText.text.substring(0, cp);
        let post = exprText.text.substring(cp);
        
        let preUnformatted = pre.replace(/,/g, '');
        
        // Handle operator replacement rules
        if (["+", "-", "×", "÷"].includes(str) && str !== "%") {
            let lastChar = preUnformatted.charAt(preUnformatted.length - 1);
            if (["+", "-", "×", "÷"].includes(lastChar)) {
                preUnformatted = preUnformatted.slice(0, -1);
                pre = formatExpression(preUnformatted); // Reformat pre to adjust cp correctly
            }
        }
        
        let newPreUnformatted = preUnformatted + str;
        let newPreFormatted = formatExpression(newPreUnformatted);
        
        let newUnformatted = (pre + str + post).replace(/,/g, '');
        
        root.expression = newUnformatted;
        exprText.text = formatExpression(newUnformatted);
        exprText.cursorPosition = newPreFormatted.length;
        
        liveResult = evaluateExpression(root.expression);
    }

    function inputDigit(digit) {
        insertAtCursor(digit);
    }

    function inputOperator(op) {
        insertAtCursor(op);
    }

    function inputBracket(char) {
        insertAtCursor(char);
    }

    function inputDecimal() {
        insertAtCursor(".");
    }

    function clear() {
        root.expression = "";
        liveResult = "";
        isFinalized = false;
        exprText.text = "0";
        exprText.cursorPosition = 1;
    }

    function backspace() {
        if (isFinalized) {
            clear();
            return;
        }
        
        let cp = exprText.cursorPosition;
        if (cp === 0) return;
        
        let pre = exprText.text.substring(0, cp);
        let post = exprText.text.substring(cp);
        
        if (pre.endsWith(',')) {
            pre = pre.slice(0, -1);
            cp -= 1;
        }
        
        pre = pre.slice(0, -1);
        
        let preUnformatted = pre.replace(/,/g, '');
        let newPreFormatted = formatExpression(preUnformatted);
        let newUnformatted = (pre + post).replace(/,/g, '');
        
        root.expression = newUnformatted;
        
        if (newUnformatted === "") {
            exprText.text = "0";
            exprText.cursorPosition = 1;
        } else {
            exprText.text = formatExpression(newUnformatted);
            exprText.cursorPosition = newPreFormatted.length;
        }
        liveResult = evaluateExpression(root.expression);
    }

    component CalcKey : ButtonBase {
        id: key

        property string label: ""
        property string iconGlyph: ""
        property int role: 0 // 0 digit, 1 operator, 2 utility, 3 equals

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 56
        Layout.preferredHeight: role === 3 ? 68 : 60
        implicitWidth: 68
        implicitHeight: role === 3 ? 68 : 60

        shapeMorph: true
        radiusMorph: true
        defaultRadius: Tokens.rounding.normal
        pressedRadius: (height || implicitHeight) / 2
        padding: 0

        type: role === 3 ? ButtonBase.Filled : ButtonBase.Tonal

        inactiveColour: role === 3 ? Colours.palette.m3primary
            : role === 0 ? Colours.tileFillElevated
            : role === 2 ? (Colours.light ? Colours.palette.m3tertiaryContainer : Qt.alpha(Colours.palette.m3tertiaryContainer, 0.72))
            : (Colours.light ? Colours.palette.m3secondaryContainer : Qt.alpha(Colours.palette.m3secondaryContainer, 0.72))
        inactiveOnColour: role === 3 ? Colours.palette.m3onPrimary
            : role === 0 ? Colours.palette.m3onSurface
            : role === 2 ? Colours.palette.m3onTertiaryContainer
            : Colours.palette.m3onSecondaryContainer

        scale: stateLayer.pressed ? 0.96 : (stateLayer.containsMouse ? 1.02 : 1.0)
        transformOrigin: Item.Center

        Behavior on scale {
            SpringAnimation {
                spring: stateLayer.pressed ? 5.0 : 4.2
                damping: stateLayer.pressed ? 0.65 : 0.70
                mass: 1.0
                epsilon: 0.01
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: key.label !== ""
            text: key.label
            color: key.onColour
            textPointSize: role === 3 ? 26 : 22
            font.weight: role === 3 ? Font.Bold : Font.DemiBold
            font.family: Tokens.font.family.mono
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: key.iconGlyph !== ""
            text: key.iconGlyph
            color: key.onColour
            iconPointSize: 24
        }

        StyledRect {
            anchors.fill: parent
            radius: key.radius
            color: "transparent"
            border.width: 1
            border.color: root.glassTileStroke
            opacity: key.stateLayer.containsMouse || key.stateLayer.pressed ? 1 : 0.55

            Behavior on opacity {
                Anim { type: Anim.DefaultEffects }
            }
        }
    }

    component GlassPanel: Item {
        id: panel

        default property alias content: innerContent.data
        property int staggerIndex: 0
        property real radius: Tokens.rounding.large

        property bool _ready: false
        Component.onCompleted: Qt.callLater(() => panel._ready = true)

        state: panel._ready ? "visible" : "hidden"

        transform: [
            Scale {
                id: panelScale
                origin.x: panel.width / 2
                origin.y: panel.height / 2
                xScale: 1.05
                yScale: 1.05
            }
        ]

        states: [
            State {
                name: "hidden"
                PropertyChanges { target: panel; opacity: 0 }
                PropertyChanges { target: panelScale; xScale: 1.05; yScale: 1.05 }
            },
            State {
                name: "visible"
                PropertyChanges { target: panel; opacity: 1 }
                PropertyChanges { target: panelScale; xScale: 1.0; yScale: 1.0 }
            }
        ]

        transitions: Transition {
            from: "hidden"
            to: "visible"
            SequentialAnimation {
                PauseAnimation { duration: panel.staggerIndex * 60 }
                ParallelAnimation {
                    NumberAnimation {
                        target: panel
                        property: "opacity"
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.m3Emphasized
                    }
                    NumberAnimation {
                        target: panelScale
                        properties: "xScale,yScale"
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.m3Emphasized
                    }
                }
            }
        }

        StyledRect {
            id: panelBg
            anchors.fill: parent
            radius: panel.radius
            color: root.glassFill
            border.width: 1
            border.color: root.glassStroke

            StyledRect {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: "transparent"
                border.color: root.glassHighlight
                border.width: 1
            }

            StyledClippingRect {
                id: innerContent
                anchors.fill: parent
                anchors.margins: 4
                radius: panelBg.radius - 4
                color: "transparent"
                clip: true
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.normal

        GlassPanel {
            id: displayCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1.1
            staggerIndex: 0

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.normal

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        visible: root.showHistory
                        text: qsTr("History")
                        color: Colours.palette.m3onSurface
                        textPointSize: Tokens.font.size.normal
                        font.weight: Font.DemiBold
                    }

                    Item { Layout.fillWidth: true }

                    ButtonBase {
                        id: clearHistoryBtn
                        visible: root.showHistory && root.historyList.length > 0
                        implicitWidth: 36
                        implicitHeight: 36
                        isRound: true
                        inactiveColour: "transparent"
                        inactiveOnColour: Colours.palette.m3onSurfaceVariant
                        onClicked: root.clearHistory()

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "delete_sweep"
                            iconPointSize: Tokens.font.size.large
                            color: clearHistoryBtn.onColour
                        }
                    }

                    ButtonBase {
                        id: historyBtn
                        checked: root.showHistory
                        isRound: true
                        radiusMorph: true
                        shapeMorph: true
                        checkedRadius: Tokens.rounding.normal
                        implicitWidth: 36
                        implicitHeight: 36
                        inactiveColour: "transparent"
                        activeColour: Colours.tileFillHover
                        inactiveOnColour: Colours.palette.m3onSurfaceVariant
                        activeOnColour: Colours.palette.m3onSurface
                        onClicked: root.showHistory = !root.showHistory

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "history"
                            iconPointSize: Tokens.font.size.large
                            color: historyBtn.onColour
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    VerticalFadeFlickable {
                        id: historyScroll
                        anchors.fill: parent
                        visible: root.showHistory && root.historyList.length > 0
                        opacity: visible ? 1 : 0
                        scale: visible ? 1 : 0.96
                        contentWidth: width
                        contentHeight: historyColumn.height
                        flickableDirection: Flickable.VerticalFlick
                        transformOrigin: Item.TopRight

                        Behavior on opacity {
                            Anim { type: Anim.Emphasized }
                        }

                        Behavior on scale {
                            Anim { type: Anim.Emphasized }
                        }

                        onVisibleChanged: {
                            if (visible)
                                contentY = 0;
                        }

                        Column {
                            id: historyColumn
                            width: historyScroll.width
                            spacing: Tokens.spacing.normal

                            Repeater {
                                model: root.historyList

                                StyledRect {
                                    id: histRow

                                    required property int index
                                    required property var modelData

                                    width: historyColumn.width
                                    radius: Tokens.rounding.normal
                                    color: root.glassTileFill
                                    border.width: 1
                                    border.color: root.glassTileStroke
                                    implicitHeight: histCol.implicitHeight + Tokens.padding.normal * 2

                                    ColumnLayout {
                                        id: histCol
                                        anchors.fill: parent
                                        anchors.margins: Tokens.padding.normal
                                        spacing: 2

                                        StyledText {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignRight
                                            horizontalAlignment: Text.AlignRight
                                            text: histRow.modelData?.equation ?? ""
                                            color: Colours.palette.m3onSurfaceVariant
                                            textPointSize: Tokens.font.size.small
                                            font.family: Tokens.font.family.mono

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.selectHistoryEquation(histRow.index)
                                            }
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignRight
                                            horizontalAlignment: Text.AlignRight
                                            text: histRow.modelData?.result ?? ""
                                            color: Colours.palette.m3onSurface
                                            textPointSize: Tokens.font.size.large
                                            font.weight: Font.DemiBold
                                            font.family: Tokens.font.family.mono

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.selectHistoryResult(histRow.index)
                                            }
                                        }
                                    }

                                    StateLayer {
                                        radius: Tokens.rounding.normal
                                        color: Colours.palette.m3onSurface
                                        showRipple: false
                                        onClicked: root.selectHistoryResult(histRow.index)
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: root.showHistory && root.historyList.length === 0
                        opacity: visible ? 1 : 0
                        scale: visible ? 1 : 0.96
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("No calculations yet")
                        color: Colours.palette.m3onSurfaceVariant
                        textPointSize: Tokens.font.size.normal

                        Behavior on opacity {
                            Anim { type: Anim.Emphasized }
                        }

                        Behavior on scale {
                            Anim { type: Anim.Emphasized }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Tokens.spacing.small
                        visible: !root.showHistory
                        opacity: visible ? 1 : 0
                        scale: visible ? 1 : 0.96
                        transformOrigin: Item.BottomRight

                        Behavior on opacity {
                            Anim { type: Anim.Emphasized }
                        }

                        Behavior on scale {
                            Anim { type: Anim.Emphasized }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            TextInput {
                                id: exprText
                                anchors.right: parent.right
                                anchors.bottom: bottomText.top
                                anchors.bottomMargin: Tokens.spacing.small

                                text: root.expression === "" ? "0" : formatExpression(root.expression)
                                color: root.isFinalized
                                    ? Colours.palette.m3onSurfaceVariant
                                    : Colours.palette.m3onSurface
                                font.pixelSize: root.isFinalized ? 28 : 44
                                font.weight: root.isFinalized ? Font.DemiBold : Font.Bold
                                font.family: Tokens.font.family.mono
                                renderType: Text.NativeRendering

                                Behavior on color {
                                    CAnim {}
                                }

                                Behavior on font.pixelSize {
                                    Anim { type: Anim.Emphasized }
                                }

                                cursorVisible: !root.isFinalized
                                cursorDelegate: Rectangle {
                                    width: 3
                                    radius: 1
                                    color: Colours.palette.m3primary
                                    visible: exprText.cursorVisible
                                }

                                selectionColor: Colours.palette.m3primaryContainer
                                selectedTextColor: Colours.palette.m3onPrimaryContainer
                                readOnly: true

                                scale: Math.min(1.0, parent.width / (implicitWidth + 24))
                                transformOrigin: Item.BottomRight

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.IBeamCursor
                                    onPressed: mouse => {
                                        if (root.isFinalized)
                                            root.isFinalized = false;
                                        exprText.forceActiveFocus();
                                        exprText.cursorPosition = exprText.positionAt(mouse.x, mouse.y);
                                    }
                                }
                            }

                            StyledText {
                                id: bottomText
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom

                                text: root.isFinalized
                                    ? root.liveResult
                                    : (root.liveResult !== "" ? "= " + root.liveResult : "")
                                color: root.isFinalized
                                    ? Colours.tPalette.m3primary
                                    : Colours.palette.m3onSurface
                                textPointSize: root.isFinalized ? 56 : 30
                                font.weight: Font.Bold
                                font.family: Tokens.font.family.mono

                                Behavior on color {
                                    CAnim {}
                                }

                                Behavior on textPointSize {
                                    Anim { type: Anim.Emphasized }
                                }

                                scale: Math.min(1.0, parent.width / (implicitWidth + 24))
                                transformOrigin: Item.BottomRight
                            }
                        }
                    }
                }
            }
        }

        GlassPanel {
            id: keypadCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            staggerIndex: 1

            GridLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.normal
                columns: 4
                rowSpacing: Tokens.spacing.small
                columnSpacing: Tokens.spacing.small

                CalcKey { label: "AC"; role: 2; onClicked: root.clear() }
                CalcKey { label: "("; role: 2; onClicked: root.inputBracket("(") }
                CalcKey { label: ")"; role: 2; onClicked: root.inputBracket(")") }
                CalcKey { label: "%"; role: 2; onClicked: root.inputOperator("%") }

                CalcKey { label: "7"; role: 0; onClicked: root.inputDigit("7") }
                CalcKey { label: "8"; role: 0; onClicked: root.inputDigit("8") }
                CalcKey { label: "9"; role: 0; onClicked: root.inputDigit("9") }
                CalcKey { label: "÷"; role: 1; onClicked: root.inputOperator("÷") }

                CalcKey { label: "4"; role: 0; onClicked: root.inputDigit("4") }
                CalcKey { label: "5"; role: 0; onClicked: root.inputDigit("5") }
                CalcKey { label: "6"; role: 0; onClicked: root.inputDigit("6") }
                CalcKey { label: "×"; role: 1; onClicked: root.inputOperator("×") }

                CalcKey { label: "1"; role: 0; onClicked: root.inputDigit("1") }
                CalcKey { label: "2"; role: 0; onClicked: root.inputDigit("2") }
                CalcKey { label: "3"; role: 0; onClicked: root.inputDigit("3") }
                CalcKey { label: "-"; role: 1; onClicked: root.inputOperator("-") }

                CalcKey { label: "0"; role: 0; onClicked: root.inputDigit("0") }
                CalcKey { label: "."; role: 0; onClicked: root.inputDecimal() }
                CalcKey { iconGlyph: "backspace"; role: 2; onClicked: root.backspace() }
                CalcKey { label: "+"; role: 1; onClicked: root.inputOperator("+") }

                CalcKey {
                    label: "="
                    role: 3
                    Layout.columnSpan: 4
                    onClicked: root.calculateResult()
                }
            }
        }
    }
}
