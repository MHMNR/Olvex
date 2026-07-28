pragma Singleton

import QtQuick
import "../modules/olvex" as Olvex

QtObject {
    id: root

    signal colorsGenerated(string data, bool isPreview)
    signal catalogChanged()

    readonly property string currentNamePath: Olvex.WallpapersOlvex.currentNamePath
    readonly property list<string> smartArg: Olvex.WallpapersOlvex.smartArg
    readonly property list<string> validVideoExtensions: Olvex.WallpapersOlvex.validVideoExtensions
    readonly property string liveWallpaperDir: Olvex.WallpapersOlvex.liveWallpaperDir
    readonly property string videoThumbnailDir: Olvex.WallpapersOlvex.videoThumbnailDir
    readonly property int thumbnailUpdateCount: Olvex.WallpapersOlvex.thumbnailUpdateCount
    readonly property string current: Olvex.WallpapersOlvex.current
    readonly property var list: Olvex.WallpapersOlvex.entries
    readonly property var entries: Olvex.WallpapersOlvex.entries
    readonly property var imageEntries: Olvex.WallpapersOlvex.imageEntries
    readonly property var staticEntries: Olvex.WallpapersOlvex.staticEntries
    readonly property var liveEntries: Olvex.WallpapersOlvex.liveEntries
    readonly property var entryObjects: Olvex.WallpapersOlvex.entryObjects
    readonly property var staticEntryObjects: Olvex.WallpapersOlvex.staticEntryObjects
    readonly property var liveEntryObjects: Olvex.WallpapersOlvex.liveEntryObjects
    readonly property var monitorWallpapers: Olvex.WallpapersOlvex.monitorWallpapers
    readonly property bool perMonitorWallpaper: Olvex.WallpapersOlvex.perMonitorWallpaper
    readonly property bool showPreview: Olvex.WallpapersOlvex.showPreview
    readonly property string previewPath: Olvex.WallpapersOlvex.previewPath
    readonly property string actualCurrent: Olvex.WallpapersOlvex.actualCurrent
    readonly property string committedColourSource: Olvex.WallpapersOlvex.committedColourSource
    readonly property bool bootstrapDone: Olvex.WallpapersOlvex.bootstrapDone
    property bool previewColourLock: Olvex.WallpapersOlvex.previewColourLock
    readonly property var videoThumbnailMap: Olvex.WallpapersOlvex.videoThumbnailMap

    function setWallpaper(path, manual) {
        Olvex.WallpapersOlvex.setWallpaper(path, manual);
    }

    function preview(path: string): void {
        Olvex.WallpapersOlvex.preview(path);
    }

    function stopPreview(): void {
        Olvex.WallpapersOlvex.stopPreview();
    }

    function getMonitorWallpaper(monitorName: string): string {
        return Olvex.WallpapersOlvex.getMonitorWallpaper(monitorName);
    }

    function isVideoPath(path: string): bool {
        return Olvex.WallpapersOlvex.isVideoPath(path);
    }

    function thumbnailPathFor(path: string): string {
        return Olvex.WallpapersOlvex.thumbnailPathFor(path);
    }

    function colourSourcePath(path: string): string {
        return Olvex.WallpapersOlvex.colourSourcePath(path); // Ensure this returns a file:// URL or a path that ImageAnalyser can handle
    }

    function queueThumbnail(path: string, prioritize): void {
        Olvex.WallpapersOlvex.queueThumbnail(path, prioritize);
    }

    function setMonitorWallpaper(monitorName: string, path: string): void {
        Olvex.WallpapersOlvex.setMonitorWallpaper(monitorName, path);
    }

    function ensureCatalog(): void {
        Olvex.WallpapersOlvex.ensureCatalog();
    }

    function query(search: string): var {
        return Olvex.WallpapersOlvex.query(search);
    }

    function requestAccentRefresh(path: string, isPreview: bool): void {
        Olvex.WallpapersOlvex.requestAccentRefresh(path, isPreview);
    }

    function forceAccentRefresh(path: string, isPreview: bool): void {
        Olvex.WallpapersOlvex.forceAccentRefresh(path, isPreview);
    }

    function dynamicPaletteCommand(cleanPath: string): list<string> {
        return Olvex.WallpapersOlvex.dynamicPaletteCommand(cleanPath);
    }

    onPreviewColourLockChanged: Olvex.WallpapersOlvex.previewColourLock = previewColourLock

    property var _colorConnection: Connections {
        target: Olvex.WallpapersOlvex
        function onColorsGenerated(data, isPreview) {
            root.colorsGenerated(data, isPreview);
        }
        function onCatalogChanged() {
            root.catalogChanged();
        }
    }
}
