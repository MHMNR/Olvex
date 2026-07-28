pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex
import Olvex.Internal

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string bundledRoot: CUtils.toLocalFile(Qt.resolvedUrl("root:/assets/account-faces"))
    readonly property string defaultRel: "animal/raccoon.png"
    readonly property string customPath: `${home}/.face`
    property int faceRevision: 0

    signal faceChanged()

    property var faces: []
    readonly property var categories: ["animal", "emoji", "human", "illustration", "scenery"]

    readonly property var folderPreviews: ({
        animal: "animal/raccoon.png",
        emoji: "emoji/emoji_apple.png",
        human: "human/flat/blue_hair.png",
        illustration: "illustration/boat.png",
        scenery: "scenery/01.png",
        dimensional: "human/dimensional/baisuzhen.png",
        dimensional_v2: "human/dimensional_v2/01.png",
        flat: "human/flat/blue_hair.png"
    })

    readonly property var folderLabels: ({
        animal: qsTr("Animals"),
        emoji: qsTr("Emoji"),
        human: qsTr("People"),
        illustration: qsTr("Illustration"),
        scenery: qsTr("Scenery"),
        dimensional: qsTr("3D"),
        dimensional_v2: qsTr("3D v2"),
        flat: qsTr("Flat")
    })

    readonly property var folderCategoryIcons: ({
        animal: "pets",
        emoji: "mood",
        human: "groups",
        illustration: "palette",
        scenery: "landscape",
        dimensional: "view_in_ar",
        dimensional_v2: "view_in_ar",
        flat: "face"
    })

    FileView {
        id: manifestFile

        path: `${root.bundledRoot}/manifest.json`
        printErrors: false
        onLoaded: root.loadManifest()
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("[AccountFaces] manifest load failed:", err);
        }
    }

    FileView {
        id: customFaceFile

        path: root.customPath
        watchChanges: true
        printErrors: false

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.applyBundledFace(root.defaultRel);
            }
        }
    }

    readonly property bool hasCustomFace: customFaceFile.loaded

    function bundledPath(rel: string): string {
        return `${bundledRoot}/${rel}`
    }

    function isBundledPath(path: string): bool {
        return bundledRoot.length > 0 && path.startsWith(bundledRoot)
    }

    function folderCategoryIcon(name: string): string {
        return folderCategoryIcons[name] ?? "folder";
    }

    function folderPreviewFor(name: string, path: string): string {
        if (!isBundledPath(path))
            return "";

        if (folderPreviews[name])
            return bundledPath(folderPreviews[name]);

        const relPrefix = `${path.slice(bundledRoot.length + 1)}/`;
        for (const face of faces) {
            if (face.rel?.startsWith(relPrefix))
                return bundledPath(face.rel);
        }

        return "";
    }

    function formatLabel(label: string): string {
        if (!label)
            return "";
        return label.split(/[-_]/).map(word => word ? word.charAt(0).toUpperCase() + word.slice(1) : "").join(" ");
    }

    function relFromPath(path: string): string {
        if (!isBundledPath(path))
            return "";
        return path.slice(bundledRoot.length + 1);
    }

    function faceLabelForPath(path: string): string {
        const rel = relFromPath(path);
        if (!rel)
            return "";

        for (const face of faces) {
            if (face.rel === rel)
                return formatLabel(face.label);
        }

        return "";
    }

    function displayNameFor(name: string, path: string, isDir: bool): string {
        if (!isBundledPath(path) && !isBundledPath(isDir ? path : path.slice(0, path.lastIndexOf("/"))))
            return name;

        if (isDir) {
            if (folderLabels[name])
                return folderLabels[name];
            return formatLabel(name);
        }

        const label = faceLabelForPath(path);
        if (label)
            return label;

        let base = name.replace(/\.[^.]+$/, "");
        if (base.startsWith("emoji_"))
            base = base.slice(6);
        return formatLabel(base);
    }

    function cwdSegmentLabel(segment: string): string {
        if (segment === bundledRoot)
            return qsTr("Faces");
        if (folderLabels[segment])
            return folderLabels[segment];
        return formatLabel(segment);
    }

    function shouldHideEntry(name: string, path: string): bool {
        return isBundledPath(path) && name === "manifest.json";
    }

    function loadManifest(): void {
        if (!manifestFile.loaded)
            return;
        try {
            const data = JSON.parse(manifestFile.text());
            root.faces = data.faces ?? [];
        } catch (e) {
            console.warn("[AccountFaces] manifest parse failed:", e);
        }
    }

    function applyBundledFace(rel: string): bool {
        const src = bundledPath(rel);
        return CUtils.copyFile(Qt.resolvedUrl(src), Qt.resolvedUrl(customPath));
    }

    function ensureDefault(): void {
        if (!customFaceFile.loaded && customFaceFile.error === FileViewError.FileNotFound) {
            if (!applyBundledFace(defaultRel))
                console.warn("[AccountFaces] failed to install default face");
        }
    }

    Component.onCompleted: Qt.callLater(root.ensureDefault)
}