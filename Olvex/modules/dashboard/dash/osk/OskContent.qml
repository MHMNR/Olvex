import QtQuick
import QtCore
import QtQuick.Layouts
import QtCore
import Olvex.Config
import "layouts.js" as Layouts

Item {
    id: root    
    property var layouts: Layouts.byName
    property string activeLayoutName: Layouts.defaultLayout
    property string prevLayoutName: ""
    property var currentLayout: layouts[activeLayoutName]

    signal hideRequested()
    signal layoutSwitchRequested(string targetLayout)
    property bool isSplit: false
    property var wordEngine: null  
    property var sessionRecentEmojis: []
    
    property bool _settingsLoaded: false
    
    Settings {
        id: recentSettings
        category: "OnScreenKeyboard"
        property string savedRecents: "[]"
    }

    Component.onCompleted: {
        try {
            root.sessionRecentEmojis = JSON.parse(recentSettings.savedRecents);
        } catch(e) {
            root.sessionRecentEmojis = [];
        }
        root._settingsLoaded = true;
    }

    onSessionRecentEmojisChanged: {
        if (root._settingsLoaded) {
            recentSettings.savedRecents = JSON.stringify(root.sessionRecentEmojis);
        }
    }

    property bool isDocked: false
    property real dockProgress: 0.0
    property real scaleFactor: 1.0
    property real screenWidth: 1920

    // STATE-BASED Scaling: Static targets for stability
    readonly property real dynamicScaleTarget: {
        if (activeLayoutName === "Traditional") {
            let availableW = screenWidth - 80;
            return Math.min(1.4, Math.max(1.0, availableW / 1265));
        }
        return 1.0;
    }
    
    // Physical scale (instant) and Visual scale (bouncy)
    readonly property real physicalScale: isDocked ? (scaleFactor * dynamicScaleTarget) : scaleFactor
    property real visualScale: physicalScale
    Behavior on visualScale { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }

    readonly property real currentBaseWidth: 55 * physicalScale
    readonly property real currentBaseHeight: 55 * scaleFactor

    implicitWidth: {
        if (root.activeLayoutName.includes("Phone") && !root.isSplit) return 640;
        let item = customLoader.item || primaryLoader.item;
        return item ? item.implicitWidth : 800;
    }
    implicitHeight: (customLoader.item || primaryLoader.item) ? (customLoader.item || primaryLoader.item).implicitHeight : 350

    // Snapshot Morph System (GPU Optimized)
    ShaderEffectSource {
        id: layoutSnapshot
        anchors.fill: parent
        sourceItem: root.currentLayout.isCustom ? customLoader : primaryLoader
        live: false 
        recursive: false
        opacity: 0
        visible: opacity > 0
        z: 10
        
        property real offset: 0
        transform: Translate { x: layoutSnapshot.offset }

        ParallelAnimation {
            id: snapshotAnim
            NumberAnimation { target: layoutSnapshot; property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { target: layoutSnapshot; property: "offset"; duration: 250; easing.type: Easing.OutExpo }
        }
    }
    
    onActiveLayoutNameChanged: {
        layoutSnapshot.scheduleUpdate();
        layoutSnapshot.opacity = 1;
        
        function getRank(name) {
            if (name.includes("Emoji")) return 2;
            if (name.includes("Symbol")) return 1;
            return 0;
        }
        
        let oldRank = getRank(prevLayoutName);
        let newRank = getRank(activeLayoutName);
        let dir = (newRank >= oldRank) ? 1 : -1;
        
        layoutSnapshot.offset = 0;
        snapshotAnim.animations[1].to = -dir * 120;
        
        root.currentLayout = layouts[activeLayoutName];
        
        if (root.currentLayout.isCustom) {
            customLoader.offset = dir * 120;
            customLoader.entryScale = 0.98;
            customFade.restart();
            customSlide.restart();
            customScale.restart();
        } else {
            primaryLoader.offset = dir * 120;
            primaryLoader.entryScale = 0.98;
            primaryFade.restart();
            primarySlide.restart();
            primaryScale.restart();
        }
        
        snapshotAnim.restart();
        prevLayoutName = activeLayoutName;
    }

    // Dual-Engine System: Primary (Row/Block) and Custom (Emoji)
    // We keep both active to ensure instantaneous switching back to ABC
    
    Loader {
        id: primaryLoader
        anchors.fill: parent
        opacity: !root.currentLayout.isCustom ? 1 : 0
        visible: opacity > 0
        
        property real entryScale: 1.0
        property real offset: 0
        
        layer.enabled: true
        layer.smooth: false // KEEP IT SHARP
        
        transform: [
            Translate { x: Math.round(primaryLoader.offset) },
            Scale { 
                origin.x: primaryLoader.width/2; 
                origin.y: primaryLoader.height/2; 
                xScale: primaryLoader.entryScale * (root.visualScale / root.physicalScale)
                yScale: primaryLoader.entryScale
            }
        ]
        
        sourceComponent: {
            if (!root.currentLayout) return null;
            if (root.currentLayout.isCustom) return null; 
            return root.currentLayout.isBlockBased ? blockBasedComponent : rowBasedComponent;
        }
    }

    Loader {
        id: customLoader
        anchors.fill: parent
        opacity: root.currentLayout.isCustom ? 1 : 0
        visible: opacity > 0
        
        property real entryScale: 1.0
        property real offset: 0
        
        layer.enabled: true
        layer.smooth: false // KEEP IT SHARP
        
        transform: [
            Translate { x: Math.round(customLoader.offset) },
            Scale { 
                origin.x: customLoader.width/2; 
                origin.y: customLoader.height/2; 
                xScale: customLoader.entryScale * (root.visualScale / root.physicalScale)
                yScale: customLoader.entryScale
            }
        ]
        
        sourceComponent: root.currentLayout.isCustom ? customLayoutComponent : null
    }

    // New Content Animations (Universal)
    NumberAnimation { id: primaryFade; target: primaryLoader; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
    NumberAnimation { id: primarySlide; target: primaryLoader; property: "offset"; to: 0; duration: 300; easing.type: Easing.OutExpo }
    NumberAnimation { id: primaryScale; target: primaryLoader; property: "entryScale"; to: 1.0; duration: 250; easing.type: Easing.OutBack }
    
    NumberAnimation { id: customFade; target: customLoader; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
    NumberAnimation { id: customSlide; target: customLoader; property: "offset"; to: 0; duration: 300; easing.type: Easing.OutExpo }
    NumberAnimation { id: customScale; target: customLoader; property: "entryScale"; to: 1.0; duration: 250; easing.type: Easing.OutBack }

    // ISOLATED LAYOUTS: Dispatched to independent engines
    Component {
        id: rowBasedComponent
        LayoutRowEngine {
            layoutData: root.currentLayout
            baseWidth: root.currentBaseWidth
            baseHeight: root.currentBaseHeight
            isSplit: root.isSplit
            wordEngine: root.wordEngine
            onHideRequested: root.hideRequested()
            onLayoutSwitchRequested: (target) => root.layoutSwitchRequested(target)
        }
    }

    Component {
        id: blockBasedComponent
        LayoutBlockEngine {
            layoutData: root.currentLayout
            baseWidth: root.currentBaseWidth
            baseHeight: root.currentBaseHeight
            scaleFactor: root.visualScale
            wordEngine: root.wordEngine
            onHideRequested: root.hideRequested()
            onLayoutSwitchRequested: (target) => root.layoutSwitchRequested(target)
        }
    }

    Component {
        id: customLayoutComponent
        Loader {
            anchors.fill: parent
            source: root.currentLayout.customComponent
            Binding { target: item; property: "baseWidth"; value: root.currentBaseWidth; restoreMode: Binding.RestoreBinding }
            Binding { target: item; property: "baseHeight"; value: root.currentBaseHeight; restoreMode: Binding.RestoreBinding }
            Binding { target: item; property: "wordEngine"; value: root.wordEngine; restoreMode: Binding.RestoreBinding }
            Binding { target: item; property: "sessionRecentsContext"; value: root; restoreMode: Binding.RestoreBinding }
            
            Connections {
                target: item
                ignoreUnknownSignals: true
                function onLayoutSwitchRequested(target) { root.layoutSwitchRequested(target) }
                function onHideRequested() { root.hideRequested() }
            }
        }
    }
}
