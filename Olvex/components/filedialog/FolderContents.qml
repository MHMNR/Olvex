pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import Olvex.Models
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property var dialog
    readonly property FileEntry currentItem: view.currentItem as FileEntry

    StyledRect {
        anchors.fill: parent
        color: Colours.tPalette.m3surfaceContainer

        layer.enabled: true
        layer.effect: MultiEffect {
            maskSource: mask
            maskEnabled: true
            maskInverted: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Item {
        id: mask

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            radius: Tokens.rounding.small
        }
    }

    Loader {
        asynchronous: true
        anchors.centerIn: parent

        opacity: view.count === 0 ? 1 : 0
        active: opacity > 0

        sourceComponent: ColumnLayout {
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "scan_delete"
                color: Colours.palette.m3outline
                iconPointSize: Tokens.font.size.extraLarge * 2
                font.weight: 500
            }

            StyledText {
                text: qsTr("This folder is empty")
                color: Colours.palette.m3outline
                textPointSize: Tokens.font.size.large
                font.weight: 500
            }
        }

        Behavior on opacity {
            Anim {}
        }
    }

    GridView {
        id: view

        anchors.fill: parent
        anchors.margins: Tokens.padding.small + Tokens.padding.normal

        cellWidth: Sizes.itemWidth + Tokens.spacing.small
        cellHeight: Sizes.itemWidth + Tokens.spacing.small * 2 + Tokens.padding.normal * 2 + 1

        clip: true
        focus: true
        currentIndex: -1
        Keys.onEscapePressed: currentIndex = -1

        Keys.onReturnPressed: {
            const file = (currentItem as FileEntry)?.modelData;
            if (root.dialog.selectionValid && file)
                root.dialog.accepted(file.path);
        }
        Keys.onEnterPressed: {
            const file = (currentItem as FileEntry)?.modelData;
            if (root.dialog.selectionValid && file)
                root.dialog.accepted(file.path);
        }

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: view
        }

        model: FileSystemModel {
            id: fsModel

            path: {
                if (root.dialog.cwd[0] === "Home")
                    return Paths.home + `/${root.dialog.cwd.slice(1).join("/")}`;
                else
                    return root.dialog.cwd.join("/");
            }
            onPathChanged: view.currentIndex = -1
        }

        delegate: FileEntry {}

        add: Transition {
            Anim {
                properties: "opacity,scale"
                from: 0
                to: 1
                type: Anim.DefaultSpatial
            }
        }

        remove: Transition {
            Anim {
                property: "opacity"
                to: 0
            }
            Anim {
                property: "scale"
                to: 0.5
            }
        }

        displaced: Transition {
            Anim {
                properties: "opacity,scale"
                to: 1
                easing: Tokens.anim.standardDecel
            }
            Anim {
                properties: "x,y"
                type: Anim.DefaultSpatial
            }
        }
    }

    CurrentItem {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.small

        currentItem: view.currentItem
    }

    component FileEntry: StyledRect {
        id: item

        required property int index
        required property FileSystemEntry modelData

        readonly property bool hasEntry: item.modelData !== null && item.modelData !== undefined
        readonly property bool hidden: {
            const entry = item.modelData;
            if (!entry)
                return true;
            if (AccountFaces.shouldHideEntry(entry.name, entry.path))
                return true;
            return !root.dialog.matchesFilter(entry);
        }
        readonly property string displayName: {
            const entry = item.modelData;
            if (!entry)
                return "";
            return AccountFaces.displayNameFor(entry.name, entry.path, entry.isDir);
        }
        readonly property real nonAnimHeight: iconFrame.implicitHeight + name.anchors.topMargin + name.implicitHeight + Tokens.padding.normal * 2

        implicitWidth: hidden ? 0 : Sizes.itemWidth
        implicitHeight: hidden ? 0 : nonAnimHeight
        visible: !hidden

        radius: Tokens.rounding.normal
        color: Qt.alpha(Colours.tPalette.m3surfaceContainerHighest, GridView.isCurrentItem ? Colours.tPalette.m3surfaceContainerHighest.a : 0)
        z: GridView.isCurrentItem || implicitHeight !== nonAnimHeight ? 1 : 0
        clip: true

        StateLayer {
            interactive: item.hasEntry
            onClicked: view.currentIndex = item.index
            onDoubleClicked: {
                if (!item.hasEntry)
                    return;
                if (item.modelData.isDir)
                    root.dialog.enterDirectory(item.modelData.name);
                else if (root.dialog.selectionValid)
                    root.dialog.accepted(item.modelData.path);
            }
        }

        Item {
            id: iconFrame

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Tokens.padding.normal

            implicitWidth: Sizes.itemWidth - Tokens.padding.normal * 2
            implicitHeight: implicitWidth

            readonly property bool isDirEntry: item.hasEntry && item.modelData.isDir
            readonly property bool isBundledDir: iconFrame.isDirEntry
                                                 && AccountFaces.isBundledPath(item.modelData.path)
            readonly property string bundledPreview: iconFrame.isBundledDir
                                                     ? AccountFaces.folderPreviewFor(item.modelData.name, item.modelData.path)
                                                     : ""
            FolderShapeIcon {
                anchors.fill: parent
                visible: iconFrame.isDirEntry
                glyphIcon: "folder"
                previewPath: iconFrame.bundledPreview
                badgeIcon: iconFrame.isBundledDir && item.hasEntry
                    ? AccountFaces.folderCategoryIcon(item.modelData.name) : ""
            }

            StyledClippingRect {
                anchors.fill: parent
                visible: item.hasEntry && !item.modelData.isDir
                radius: Tokens.rounding.normal
                color: Colours.tPalette.m3surfaceContainerHigh

                CachingIconImage {
                    id: icon

                    anchors.fill: parent
                    implicitSize: parent.width

                    function refreshSource(): void {
                        const file = item.modelData;
                        if (!file || file.isDir) {
                            source = "";
                            return;
                        }
                        if (file.isImage) {
                            source = Qt.resolvedUrl(file.path);
                            return;
                        }
                        const mimeIcon = file.mimeType.replace("/", "-");
                        const suffixIcon = file.suffix.length
                            ? `application-x-${file.suffix.toLowerCase()}`
                            : "application-x-zerosize";
                        source = Quickshell.iconPath(mimeIcon, suffixIcon);
                    }

                    Component.onCompleted: refreshSource()

                    Connections {
                        target: item
                        function onModelDataChanged(): void {
                            icon.refreshSource();
                        }
                    }

                    Connections {
                        target: icon
                        function onStatusChanged(): void {
                            if (icon.status !== Image.Error || !item.hasEntry || item.modelData.isDir)
                                return;
                            const file = item.modelData;
                            const fallback = Quickshell.iconPath("application-x-zerosize", "text-x-generic");
                            if (icon.source.toString() !== fallback.toString())
                                icon.source = fallback;
                        }
                    }
                }
            }
        }

        StyledText {
            id: name

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: iconFrame.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.margins: Tokens.padding.normal

            horizontalAlignment: Text.AlignHCenter
            elide: item.GridView.isCurrentItem ? Text.ElideNone : Text.ElideRight
            wrapMode: item.GridView.isCurrentItem ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap

            text: item.displayName
        }

        Behavior on implicitHeight {
            Anim {}
        }
    }

}
