pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import QtCore

Item {
    id: root

    implicitWidth: 980
    implicitHeight: 460

    property string expression: ""
    property string liveResult: ""
    property bool isFinalized: false
    
    // History State
    property var historyList: []
    property bool showHistory: false

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

        let currentHistory = root.historyList.slice();
        currentHistory.unshift({
            "equation": formatExpression(root.expression) + " =",
            "result": result
        });
        root.historyList = currentHistory;
        
        liveResult = result;
        isFinalized = true;
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

    // ── CalcButton defined at top level for pragma ComponentBehavior: Bound ────
    component CalcButton : Item {
        id: btn
        property string text: ""
        property string iconName: ""
        property bool isOperator: false
        property bool isPrimary: false
        property bool isTertiary: false
        signal clicked()

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        clip: true

        property real currentRadius: btnState.pressed ? (height / 2) * 0.8 : height / 2
        Behavior on currentRadius { Anim { type: Anim.FastSpatial } }

        scale: btnState.pressed ? 0.85 : 1.0
        Behavior on scale { Anim { type: Anim.FastSpatial } }

        Rectangle {
            anchors.fill: parent
            radius: btn.currentRadius
            color: btn.isPrimary
                ? Colours.palette.m3primary
                : btn.isTertiary
                    ? Qt.rgba(Colours.palette.m3tertiary.r, Colours.palette.m3tertiary.g, Colours.palette.m3tertiary.b, 0.22)
                    : btn.isOperator
                        ? Qt.rgba(Colours.palette.m3secondary.r, Colours.palette.m3secondary.g, Colours.palette.m3secondary.b, 0.22)
                        : Qt.rgba(Colours.palette.m3onSurface.r, Colours.palette.m3onSurface.g, Colours.palette.m3onSurface.b, 0.07)
        }

        StyledText {
            anchors.centerIn: parent
            text: btn.text
            color: btn.isPrimary
                ? Colours.palette.m3onPrimary
                : btn.isTertiary
                    ? Colours.palette.m3tertiary
                    : btn.isOperator
                        ? Colours.palette.m3secondary
                        : Colours.palette.m3onSurface
            textPointSize: 22
            font.weight: 600
            visible: btn.text !== ""
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: btn.iconName
            color: btn.isPrimary
                ? Colours.palette.m3onPrimary
                : btn.isTertiary
                    ? Colours.palette.m3tertiary
                    : btn.isOperator
                        ? Colours.palette.m3secondary
                        : Colours.palette.m3onSurface
            iconPointSize: 24
            visible: btn.iconName !== ""
        }

        StateLayer {
            id: btnState
            radius: btn.currentRadius
            color: btn.isPrimary
                ? Colours.palette.m3onPrimary
                : btn.isTertiary
                    ? Colours.palette.m3tertiary
                    : btn.isOperator
                        ? Colours.palette.m3secondary
                        : Colours.palette.m3onSurface
            onClicked: btn.clicked()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.large

        // ── Left Column (Display Card) ──────────────────────────────────
        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            radius: Tokens.rounding.large
            color: Qt.alpha(Colours.palette.m3onSurface, 0.05)
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3onSurface, 0.1)
            clip: true

            StyledRect {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: "transparent"
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.04)
                border.width: 1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.normal

            // History Header
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true } // Spacer
                
                Item {
                    id: histBtn
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: stateLayer.pressed ? 10 : 20
                        color: root.showHistory ? Colours.palette.m3primaryContainer : "transparent"
                        Behavior on radius { Anim { type: Anim.FastSpatial } }
                    }
                    
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "history"
                        iconPointSize: 22
                        color: root.showHistory ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                    }
                    
                    CustomMouseArea {
                        id: stateLayer
                        anchors.fill: parent
                        onClicked: root.showHistory = !root.showHistory
                    }
                }
            }

            // History List
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: historyView
                    anchors.fill: parent
                    clip: true
                    model: root.historyList
                    spacing: Tokens.spacing.large
                    
                    visible: opacity > 0
                    opacity: root.showHistory ? 1.0 : 0.0
                    Behavior on opacity { Anim { type: Anim.FastSpatial } }

                    delegate: Item {
                        width: historyView.width
                        height: col.implicitHeight
                        
                        ColumnLayout {
                            id: col
                            anchors.right: parent.right
                            spacing: 4

                            StyledText {
                                Layout.alignment: Qt.AlignRight
                                text: modelData?.equation ?? ""
                                color: Colours.palette.m3onSurfaceVariant
                                textPointSize: 14
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignRight
                                text: modelData?.result ?? ""
                                color: Colours.palette.m3onSurface
                                textPointSize: 24
                                font.weight: 600
                            }
                        }

                        CustomMouseArea {
                            anchors.fill: parent
                            onClicked: {
                                const result = modelData?.result ?? "";
                                if (!result)
                                    return;
                                root.expression = result.replace(/,/g, '');
                                root.isFinalized = true;
                                root.liveResult = result;
                            }
                        }
                    }
                }
            }

            // Main Display
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 140

                // TOP TEXT: Expression
                // TOP TEXT: Expression Input with Cursor
                TextInput {
                    id: exprText
                    anchors.right: parent.right
                    anchors.bottom: bottomText.top
                    anchors.bottomMargin: Tokens.spacing.normal

                    text: root.expression === "" ? "0" : formatExpression(root.expression)
                    color: root.isFinalized ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                    font.pixelSize: root.isFinalized ? 24 : 42
                    font.weight: root.isFinalized ? 600 : 700
                    font.family: Tokens.font.family.sans
                    renderType: Text.QtRendering
                    
                    // Smooth font size transition when switching between edit/final state
                    Behavior on font.pixelSize {
                        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                    }
                    
                    cursorVisible: !root.isFinalized
                    cursorDelegate: Rectangle {
                        width: 3
                        color: Colours.palette.m3primary
                        visible: exprText.cursorVisible
                    }
                    
                    selectionColor: Colours.palette.m3primaryContainer
                    selectedTextColor: Colours.palette.m3onPrimaryContainer
                    
                    // We prevent native keyboard input here since we have on-screen buttons, 
                    // but we allow cursor movement via clicks.
                    readOnly: true 

                    scale: Math.min(1.0, parent.width / (implicitWidth + 20))
                    transformOrigin: Item.BottomRight

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onPressed: (mouse) => {
                            if (root.isFinalized) root.isFinalized = false;
                            exprText.forceActiveFocus();
                            exprText.cursorPosition = exprText.positionAt(mouse.x, mouse.y);
                        }
                    }

                    property bool _fin: root.isFinalized
                    on_FinChanged: scaleAnim.restart()
                    SequentialAnimation {
                        id: scaleAnim
                        NumberAnimation { target: exprText; property: "scale"; to: 0.92; duration: 80; easing.type: Easing.OutQuad }
                        NumberAnimation { target: exprText; property: "scale"; to: Math.min(1.0, parent.width / (exprText.implicitWidth + 20)); duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                    }
                }

                // BOTTOM TEXT: Live Result
                StyledText {
                    id: bottomText
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    renderType: Text.QtRendering

                    // Smooth font size transition for result display
                    Behavior on font.pixelSize {
                        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                    }
                    // Fade result smoothly when switching edit state
                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                    }

                    text: root.isFinalized ? root.liveResult : (root.liveResult !== "" ? "= " + root.liveResult : "")
                    color: root.isFinalized ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    textPointSize: root.isFinalized ? 54 : 32
                    font.weight: root.isFinalized ? 700 : 600
                    font.family: Tokens.font.family.sans

                    scale: Math.min(1.0, parent.width / (implicitWidth + 20))
                    transformOrigin: Item.BottomRight

                    property bool _fin: root.isFinalized
                    on_FinChanged: resultScaleAnim.restart()
                    SequentialAnimation {
                        id: resultScaleAnim
                        NumberAnimation { target: bottomText; property: "scale"; to: 0.92; duration: 80; easing.type: Easing.OutQuad }
                        NumberAnimation { target: bottomText; property: "scale"; to: Math.min(1.0, parent.width / (bottomText.implicitWidth + 20)); duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                    }
                }
            }
        }
        }

        // ── Right Column (Numpad Card) ───────────────────────────────────────
        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            radius: Tokens.rounding.large
            color: Qt.alpha(Colours.palette.m3onSurface, 0.05)
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3onSurface, 0.1)
            clip: true

            StyledRect {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: "transparent"
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.04)
                border.width: 1
            }

            GridLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                columns: 4
                rowSpacing: Tokens.spacing.normal
                columnSpacing: Tokens.spacing.normal

            // Row 1
            CalcButton { text: "AC"; isTertiary: true; onClicked: root.clear() }
            CalcButton { text: "("; isTertiary: true; onClicked: root.inputBracket("(") }
            CalcButton { text: ")"; isTertiary: true; onClicked: root.inputBracket(")") }
            CalcButton { text: "%"; isTertiary: true; onClicked: root.inputOperator("%") }

            // Row 2
            CalcButton { text: "7"; onClicked: root.inputDigit("7") }
            CalcButton { text: "8"; onClicked: root.inputDigit("8") }
            CalcButton { text: "9"; onClicked: root.inputDigit("9") }
            CalcButton { text: "÷"; isOperator: true; onClicked: root.inputOperator("÷") }

            // Row 3
            CalcButton { text: "4"; onClicked: root.inputDigit("4") }
            CalcButton { text: "5"; onClicked: root.inputDigit("5") }
            CalcButton { text: "6"; onClicked: root.inputDigit("6") }
            CalcButton { text: "×"; isOperator: true; onClicked: root.inputOperator("×") }

            // Row 4
            CalcButton { text: "1"; onClicked: root.inputDigit("1") }
            CalcButton { text: "2"; onClicked: root.inputDigit("2") }
            CalcButton { text: "3"; onClicked: root.inputDigit("3") }
            CalcButton { text: "-"; isOperator: true; onClicked: root.inputOperator("-") }

            // Row 5
            CalcButton { text: "0"; onClicked: root.inputDigit("0") }
            CalcButton { text: "."; onClicked: root.inputDecimal() }
            CalcButton { iconName: "backspace"; onClicked: root.backspace() }
            CalcButton { text: "+"; isOperator: true; onClicked: root.inputOperator("+") }

            // Row 6
            CalcButton { text: "="; isPrimary: true; Layout.columnSpan: 4; onClicked: root.calculateResult() }
        }
        }
    }
}
