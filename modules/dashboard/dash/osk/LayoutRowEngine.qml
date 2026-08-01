import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var layoutData
    property real baseWidth
    property real baseHeight
    property real scaleFactor: 1.0
    property var wordEngine
    property bool isSplit: false
    
    // Split Transition Flag: Only animate chain reaction when manually toggling split mode
    property bool isSplitTransitioning: false
    Timer {
        id: splitTransitionTimer
        interval: 100
        onTriggered: root.isSplitTransitioning = false
    }
    onIsSplitChanged: {
        root.isSplitTransitioning = true;
        splitTransitionTimer.restart();
    }
    
    signal hideRequested()
    signal layoutSwitchRequested(string targetLayout)

    // STABILITY FIX: explicit size
    implicitWidth: mainCol.implicitWidth
    implicitHeight: mainCol.implicitHeight

    ColumnLayout {
        id: mainCol
        width: root.width 
        spacing: 0
        
        Repeater {
            model: (root.layoutData && root.layoutData.keys) ? root.layoutData.keys : []
            delegate: RowLayout {
                id: keyRow
                required property int index
                required property var modelData
                spacing: 0
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                
                // GBoard-style Split Logic (CONSTANT - NO !root.isSplit check)
                readonly property int splitIndex: {
                    if (!keyRow.modelData) return 0;
                    if (root.layoutData && root.layoutData.name_short === "Phone") {
                        if (index === 0) return 5; // Numbers: 12345 | 67890
                        if (index === 1) return 5; // QWERTY: qwert | yuiop
                        if (index === 2) return 6; // ASDF:  [spc]asdfg | hjkl[spc]
                        if (index === 3) return 5; // ZXC:   [shft]zxcv | bnm[bksp]
                        if (index === 4) return 4; // Space: [?123][,][emo][space] | [space][.][ent]
                    }
                    return Math.ceil(keyRow.modelData.length / 2);
                }
                
                // Synchronized Spacebar Delay to prevent halves from sliding out of sync on asymmetrical layouts
                readonly property int spacebarSplitDelay: {
                    let lMax = Math.max(0, splitIndex - 1) * 35;
                    let rCount = keyRow.modelData ? (keyRow.modelData.length - keyRow.splitIndex) : 0;
                    let rMax = Math.max(0, rCount - 1) * 35;
                    // Add 40ms offset to make it "follow" the adjacent keys (train buggy effect)
                    return Math.max(lMax, rMax) + 40;
                }

                // Left Edge Spacer (Centers the row when not split)
                Item {
                    Layout.fillWidth: true
                    visible: !root.isSplit
                }

                Repeater {
                    id: singleRepeater
                    model: keyRow.modelData
                    delegate: RowLayout {
                        id: keyWrapper
                        required property int index
                        required property var modelData
                        spacing: 0
                        
                        // Mirrored Spacebar (Left side of gap)
                        Loader {
                            id: mirL
                            // ZERO-DESTRUCTION: Keep it visible to track absoluteX continuously, but fake its destruction via width/opacity
                            visible: index === keyRow.splitIndex && modelData && modelData.keycode === 57
                            opacity: root.isSplit ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            clip: true
                            sourceComponent: keyComponent
                            property var keyData: modelData
                            property real widthMultiplierOverride: root.isSplit ? ((keyData && keyData.width) ? (keyData.width / 2) : 3.125) : 0.001
                            
                            // Physics for mirror (Always acts as Left Half)
                            property real absoluteX: keyWrapper.x + x - (mainCol.width / 2)
                            property real prevX: 0
                            property real currentOffsetX: 0
                            property bool isFirstRun: true
                            property bool pendingPhysics: false
                            onAbsoluteXChanged: {
                                if (pendingPhysics) return;
                                pendingPhysics = true;
                                Qt.callLater(function() {
                                    pendingPhysics = false;
                                    if (!mirL.isFirstRun && mirL.prevX !== 0 && Math.abs(mirL.absoluteX - mirL.prevX) > 1) {
                                        let isDocking = !root.isSplitTransitioning;
                                        if (isDocking) {
                                            mirL.prevX = mirL.absoluteX;
                                            return;
                                        }
                                        
                                        mirL.currentOffsetX += (mirL.prevX - mirL.absoluteX);
                                        pauseAnimMirL.duration = root.isSplit ? keyRow.spacebarSplitDelay : 0;
                                        offsetAnimMirL.restart();
                                    }
                                    mirL.prevX = mirL.absoluteX;
                                    mirL.isFirstRun = false;
                                });
                            }
                            transform: Translate { x: mirL.currentOffsetX }
                            SequentialAnimation {
                                id: offsetAnimMirL
                                PauseAnimation { id: pauseAnimMirL; duration: 0 }
                                NumberAnimation { target: mirL; property: "currentOffsetX"; to: 0; duration: 650; easing.type: Easing.OutExpo }
                            }
                        }

                        // Expanding Gap
                        Item {
                            visible: root.isSplit && index === keyRow.splitIndex
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                        }

                        // Mirrored Spacebar (Right side of gap)
                        Loader {
                            id: mirR
                            property var prevKeyData: index > 0 ? keyRow.modelData[index - 1] : null
                            // ZERO-DESTRUCTION: Keep visible
                            visible: index === keyRow.splitIndex && prevKeyData && prevKeyData.keycode === 57
                            opacity: root.isSplit ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            clip: true
                            sourceComponent: keyComponent
                            property var keyData: prevKeyData
                            property real widthMultiplierOverride: root.isSplit ? ((keyData && keyData.width) ? (keyData.width / 2) : 3.125) : 0.001
                            
                            // Physics for mirror (Always acts as Right Half)
                            property real absoluteX: keyWrapper.x + x - (mainCol.width / 2)
                            property real prevX: 0
                            property real currentOffsetX: 0
                            property bool isFirstRun: true
                            property bool pendingPhysics: false
                            onAbsoluteXChanged: {
                                if (pendingPhysics) return;
                                pendingPhysics = true;
                                Qt.callLater(function() {
                                    pendingPhysics = false;
                                    if (!mirR.isFirstRun && mirR.prevX !== 0 && Math.abs(mirR.absoluteX - mirR.prevX) > 1) {
                                        let isDocking = !root.isSplitTransitioning;
                                        if (isDocking) {
                                            mirR.prevX = mirR.absoluteX;
                                            return;
                                        }
                                        
                                        mirR.currentOffsetX += (mirR.prevX - mirR.absoluteX);
                                        
                                        pauseAnimMirR.duration = root.isSplit ? keyRow.spacebarSplitDelay : 0;
                                        offsetAnimMirR.restart();
                                    }
                                    mirR.prevX = mirR.absoluteX;
                                    mirR.isFirstRun = false;
                                });
                            }
                            transform: Translate { x: mirR.currentOffsetX }
                            SequentialAnimation {
                                id: offsetAnimMirR
                                PauseAnimation { id: pauseAnimMirR; duration: 0 }
                                // Merging: Do not slide to 0, slide to full width to sit on right half of merged target
                                NumberAnimation { 
                                    target: mirR; 
                                    property: "currentOffsetX"; 
                                    to: (root.isSplitTransitioning && !root.isSplit) ? (root.baseWidth * (((mirR.keyData && mirR.keyData.width) ? mirR.keyData.width : 6.25) / 2)) : 0; 
                                    duration: 650; 
                                    easing.type: Easing.OutExpo 
                                }
                            }
                        }

                        // Main Key
                        Loader {
                            id: keyLoader
                            sourceComponent: (modelData && modelData.keytype === "spacer") ? spacerComponent : keyComponent
                            property var keyData: modelData
                            property real widthMultiplierOverride: {
                                if (root.isSplit && modelData && modelData.keycode === 57) {
                                    if (index === keyRow.splitIndex || index === keyRow.splitIndex - 1) {
                                        return (modelData.width || 6.25) / 2;
                                    }
                                }
                                return 0;
                            }
                            
                            // CHAIN REACTION PHYSICS (Zero-Destruction Tracked Delta)
                            property real absoluteX: keyWrapper.x + x - (mainCol.width / 2)
                            property real prevX: 0
                            property real currentOffsetX: 0
                            property bool isFirstRun: true
                            property bool pendingPhysics: false
                            onAbsoluteXChanged: {
                                if (pendingPhysics) return;
                                pendingPhysics = true;
                                Qt.callLater(function() {
                                    pendingPhysics = false;
                                    if (!keyLoader.isFirstRun && keyLoader.prevX !== 0 && Math.abs(keyLoader.absoluteX - keyLoader.prevX) > 1) {
                                        let isDocking = !root.isSplitTransitioning;
                                        if (isDocking) {
                                            keyLoader.prevX = keyLoader.absoluteX;
                                            return;
                                        }
                                        
                                        keyLoader.currentOffsetX += (keyLoader.prevX - keyLoader.absoluteX);
                                        
                                        let delay = 0;
                                        let isSpacebarPart = (modelData && modelData.keycode === 57 && (index === keyRow.splitIndex || index === keyRow.splitIndex - 1));
                                        
                                        if (isSpacebarPart) {
                                            delay = root.isSplit ? keyRow.spacebarSplitDelay : 0;
                                        } else if (index < keyRow.splitIndex) {
                                            if (root.isSplit) delay = index * 35;
                                            else delay = (keyRow.splitIndex - 1 - index) * 35;
                                        } else {
                                            let rightCount = keyRow.modelData.length - keyRow.splitIndex;
                                            let rightIdx = index - keyRow.splitIndex;
                                            if (root.isSplit) delay = (rightCount - 1 - rightIdx) * 35;
                                            else delay = rightIdx * 35;
                                        }
                                        
                                        pauseAnim.duration = delay;
                                        offsetAnim.restart();
                                    }
                                    keyLoader.prevX = keyLoader.absoluteX;
                                    keyLoader.isFirstRun = false;
                                });
                            }
                            
                            transform: Translate { x: keyLoader.currentOffsetX }
                            
                            SequentialAnimation {
                                id: offsetAnim
                                PauseAnimation { id: pauseAnim; duration: 0 }
                                NumberAnimation {
                                    target: keyLoader
                                    property: "currentOffsetX"
                                    to: 0
                                    duration: 650
                                    easing.type: Easing.OutExpo
                                }
                            }
                        }
                    }
                }
                
                // Right Edge Spacer (Centers the row when not split)
                Item {
                    Layout.fillWidth: true
                    visible: !root.isSplit
                }
            }
        }
    }

    Component {
        id: keyComponent
        OskKey { 
            baseWidth: root.baseWidth
            baseHeight: root.baseHeight
            keyData: parent.keyData
            widthMultiplierOverride: parent.widthMultiplierOverride
            wordEngine: root.wordEngine
            onHideRequested: root.hideRequested()
            onLayoutSwitchRequested: (target) => root.layoutSwitchRequested(target)
        }
    }

    Component {
        id: spacerComponent
        Item {
            implicitWidth: root.baseWidth * (parent.keyData.width || 1)
            implicitHeight: root.baseHeight * (parent.keyData.height || 1)
        }
    }
}
