import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var layoutData
    property real baseWidth
    property real baseHeight
    property real scaleFactor: 1.0
    property var wordEngine
    
    signal hideRequested()
    signal layoutSwitchRequested(string targetLayout)

    implicitWidth: rowLayoutRoot.implicitWidth
    implicitHeight: rowLayoutRoot.implicitHeight

    RowLayout {
        id: rowLayoutRoot
        // STABILITY FIX: Use width: root.width instead of anchors.fill to prevent implicitWidth loops
        width: root.width
        spacing: 27.5 * root.scaleFactor
        clip: false
        Layout.alignment: Qt.AlignHCenter
        
        Repeater {
            id: rowRepeater
            model: (root.layoutData && root.layoutData.blocks) ? root.layoutData.blocks : []
            delegate: Loader {
                required property var modelData
                sourceComponent: modelData.isGrid ? gridBlockComponent : columnBlockComponent
                property var blockData: modelData
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: modelData.id === "num" ? (root.baseHeight + 20) : 0
            }
        }
    }
    
    Component {
        id: columnBlockComponent
        ColumnLayout {
            id: colRoot
            property var blockData: parent.blockData
            spacing: 0
            Repeater {
                model: colRoot.blockData ? colRoot.blockData.rows : []
                delegate: RowLayout {
                    id: blockRow
                    required property int index
                    required property var modelData
                    spacing: 0
                    Layout.bottomMargin: index === 0 ? 20 : 0
                    Repeater {
                        model: blockRow.modelData || []
                        delegate: Loader {
                            required property var modelData
                            sourceComponent: (modelData && modelData.keytype === "spacer") ? spacerComponent : keyComponent
                            property var keyData: modelData
                        }
                    }
                }
            }
        }
    }
    
    Component {
        id: gridBlockComponent
        GridLayout {
            id: gridRoot
            property var blockData: parent.blockData
            columns: gridRoot.blockData ? gridRoot.blockData.width : 1
            rowSpacing: 0
            columnSpacing: 0
            Repeater {
                model: gridRoot.blockData ? gridRoot.blockData.keys : []
                delegate: Loader {
                    required property var modelData
                    sourceComponent: (modelData && modelData.keytype === "spacer") ? spacerComponent : keyComponent
                    property var keyData: modelData
                    Layout.row: modelData.y
                    Layout.column: modelData.x
                    Layout.rowSpan: modelData.height || 1
                    Layout.columnSpan: modelData.width || 1
                    Layout.fillWidth: true
                    Layout.fillHeight: true
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
            wordEngine: root.wordEngine
            onHideRequested: root.hideRequested()
            onLayoutSwitchRequested: (target) => root.layoutSwitchRequested(target)
        }
    }

    Component {
        id: spacerComponent
        Item {
            implicitWidth: root.baseWidth * (parent.keyData ? (parent.keyData.width || 1) : 1)
            implicitHeight: root.baseHeight * (parent.keyData ? (parent.keyData.height || 1) : 1)
        }
    }
}
