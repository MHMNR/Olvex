pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtMultimedia
import Olvex.Config
import qs.components
import qs.components.filedialog
import qs.services
import qs.utils
import "../../../services" as LocalServices

Item {
    id: root

    required property var screen

    property string source: Wallpapers.perMonitorWallpaper
        ? (Wallpapers.monitorWallpapers[screen?.name ?? ""] ?? Wallpapers.actualCurrent)
        : Wallpapers.actualCurrent
    readonly property bool sourceIsVideo: Wallpapers.isVideoPath(source)
    readonly property bool liveWallpaperActive: sourceIsVideo && Config.background.liveWallpaper.enabled
    property string actualTransitionType: Config.background.wallpaperTransition.type
    property real transitionProgress: 0
    property bool effectActive: false
    property bool showingPrimary: true
    property bool holdingLiveFrame: false
    property bool previousSourceWasVideo: sourceIsVideo
    property string lastVideoSource: ""
    property string pendingWallpaper: ""
    property bool debugLogging: true
    property real edgeSmoothness: Config.background.wallpaperTransition.edgeSmoothness
    readonly property int wallpaperTransitionDuration: GlobalConfig.background?.wallpaperTransition?.duration ?? 1000
    property real wipeDirection: 0
    property real discCenterX: 0.5
    property real discCenterY: 0.5
    property real stripesCount: 16
    property real stripesAngle: 0
    property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
    property real screenScale: screen?.devicePixelRatio ?? 1
    property int textureWidth: Math.min(Math.max(Math.round((screen?.width ?? width) / screenScale), 1), 2048)
    property int textureHeight: Math.min(Math.max(Math.round((screen?.height ?? height) / screenScale), 1), 2048)
    readonly property list<string> randomPool: ["fade", "wipe", "disc", "stripes", "iris bloom", "pixelate", "portal"]
    readonly property var currentImage: showingPrimary ? primaryImage : secondaryImage
    readonly property var nextImage: showingPrimary ? secondaryImage : primaryImage

    function debug(message: string): void {
        if (debugLogging)
            console.log(`[Wallpaper ${screen?.name ?? "unknown"}] ${message}`);
    }

    function encodeFileUrl(path) {
        if (!path)
            return "";
        if (path.startsWith("file://"))
            return path;
        return "file://" + path.split("/").map(segment => encodeURIComponent(segment)).join("/");
    }

    function imageSourceUrl(image: Image): string {
        return image?.source ? image.source.toString() : "";
    }

    function pickRandom(): string {
        return randomPool.length > 0 ? randomPool[Math.floor(Math.random() * randomPool.length)] : "fade";
    }

    function resetImageState(): void {
        transitionAnim.stop();
        effectActive = false;
        transitionProgress = 0;
        pendingWallpaper = "";
        primaryImage.source = "";
        secondaryImage.source = "";
    }

    function handleSourceChange() {
        const isVid = Wallpapers.isVideoPath(source);
        if (isVid) {
            resetImageState();
            return;
        }

        const currentSource = imageSourceUrl(currentImage);
        const nextSource = imageSourceUrl(nextImage);
        debug(`handleSourceChange source=${source} current=${currentSource} next=${nextSource} effectActive=${effectActive} animRunning=${transitionAnim.running} showingPrimary=${showingPrimary}`);
        if (!source) {
            resetImageState();
            debug("cleared all wallpaper state because source is empty");
            return;
        }

        const formattedSource = encodeFileUrl(source);
        if (formattedSource === currentSource) {
            debug("ignoring source change because current image already matches");
            // If we were holding a live frame, clear that flag now since the
            // correct image is already in the current slot and visible.
            if (holdingLiveFrame)
                holdingLiveFrame = false;
            return;
        }

        if (!currentSource) {
            currentImage.source = formattedSource;
            debug(`primed current slot with ${formattedSource}`);
            return;
        }

        if (effectActive || transitionAnim.running) {
            pendingWallpaper = source;
            debug(`queued pending wallpaper ${pendingWallpaper}`);
            return;
        }

        let type = Config.background.wallpaperTransition.type;
        if (type === "random")
            type = pickRandom();

        actualTransitionType = type;

        if (type === "none") {
            currentImage.source = formattedSource;
            nextImage.source = "";
            debug(`applied non-transition swap to ${formattedSource}`);
            return;
        }

        if (type === "wipe")
            wipeDirection = Math.floor(Math.random() * 4);
        else if (type === "disc" || type === "pixelate" || type === "portal") {
            discCenterX = Math.random();
            discCenterY = Math.random();
        } else if (type === "stripes") {
            stripesCount = Math.round(Math.random() * 20 + 4);
            stripesAngle = Math.random() * 360;
        }

        nextImage.source = formattedSource;
        debug(`prepared next slot ${formattedSource} status=${nextImage.status}`);
        if (nextImage.status === Image.Ready)
            startTransition();
    }

    function startTransition() {
        const nextSource = imageSourceUrl(nextImage);
        debug(`startTransition next=${nextSource} type=${actualTransitionType}`);
        if (!nextSource || actualTransitionType === "none") {
            if (nextSource) {
                showingPrimary = !showingPrimary;
                nextImage.source = "";
                debug("completed direct slot flip without shader");
            }
            return;
        }

        effectActive = true;
        if (srcCurrent.scheduleUpdate)
            srcCurrent.scheduleUpdate();
        if (srcNext.scheduleUpdate)
            srcNext.scheduleUpdate();
        transitionAnim.restart();
    }

    function finishTransition() {
        debug(`finishTransition before flip showingPrimary=${showingPrimary} current=${imageSourceUrl(currentImage)} next=${imageSourceUrl(nextImage)} pending=${pendingWallpaper}`);
        showingPrimary = !showingPrimary;
        effectActive = false;
        transitionProgress = 0;
        debug(`finishTransition after flip showingPrimary=${showingPrimary} current=${imageSourceUrl(currentImage)} next=${imageSourceUrl(nextImage)}`);

        if (pendingWallpaper) {
            pendingWallpaper = "";
            debug(`flushing pending wallpaper ${source}`);
            Qt.callLater(() => root.handleSourceChange());
        }
    }

    function maybeStartPreparedTransition(image: Image): void {
        const imageSource = imageSourceUrl(image);
        const rootSource = encodeFileUrl(root.source);
        const currentSource = imageSourceUrl(currentImage);
        const nextSource = imageSourceUrl(nextImage);
        debug(`statusChanged image=${image === primaryImage ? "primary" : "secondary"} status=${image.status} imageSource=${imageSource} rootSource=${rootSource} current=${currentSource} next=${nextSource}`);
        if (holdingLiveFrame && image.status === Image.Ready && imageSource === rootSource) {
            if (liveWallpaperLoader.item?.beginStaticHandoffCleanup)
                liveWallpaperLoader.item.beginStaticHandoffCleanup();
            holdingLiveFrame = false;
        }
        if (image.status === Image.Ready && !effectActive && image === nextImage && imageSource === rootSource && imageSource !== currentSource)
            startTransition();
    }

    onSourceChanged: {
        const isVid = Wallpapers.isVideoPath(source);
        if (isVid)
            lastVideoSource = encodeFileUrl(source);
        debug(`onSourceChanged -> ${source}`);
        if (previousSourceWasVideo && !isVid) {
            holdingLiveFrame = true;
            nextImage.source = "";
        }
        if (isVid)
            holdingLiveFrame = false;
        previousSourceWasVideo = isVid;
        handleSourceChange();
    }

    onSourceIsVideoChanged: {
        if (sourceIsVideo) {
            // Do NOT clear image slots here.
            // Keeping the last static image in primaryImage/secondaryImage means
            // when we switch back to static, that image stays visible as a backdrop
            // during the brief gap between video-hidden and new-static-loaded.
            // This prevents the black flash caused by both the video player and
            // the image slots being empty at the same time.
            transitionAnim.stop();
            effectActive = false;
            transitionProgress = 0;
            pendingWallpaper = "";
            // Note: primaryImage.source and secondaryImage.source intentionally NOT cleared
        }
    }

    Component.onCompleted: {
        debug(`component completed initialSource=${source}`);
        Qt.callLater(() => handleSourceChange());
    }

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Tokens.spacing.large

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    iconPointSize: Tokens.font.size.extraLarge * 5
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        textPointSize: Tokens.font.size.extraLarge * 2
                        font.bold: true
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Tokens.padding.large * 2
                        implicitHeight: selectWallText.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: qsTr("Select wallpaper media")
                            filterLabel: qsTr("Image/video files")
                            filters: Images.validImageExtensions.concat(Wallpapers.validVideoExtensions)
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            function onClicked(): void {
                                dialog.open();
                            }

                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent
                            text: qsTr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            textPointSize: Tokens.font.size.large
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: liveWallpaperLoader

        anchors.fill: parent
        active: root.liveWallpaperActive
        visible: root.sourceIsVideo || root.holdingLiveFrame
        asynchronous: true

        sourceComponent: liveWallpaperComponent
    }

    Rectangle {
        anchors.fill: parent
        z: -1
        color: "transparent"
    }

    Image {
        id: primaryImage
        anchors.fill: parent
        visible: (!root.sourceIsVideo || !liveWallpaperLoader.item?.currentPlayerReady)
                 && !root.effectActive
                 && root.showingPrimary
                 && source !== ""
                 && (!root.holdingLiveFrame || status === Image.Ready)
        source: ""
        sourceSize: Qt.size(root.textureWidth, root.textureHeight)
        asynchronous: true
        cache: true
        smooth: false
        retainWhileLoading: true
        fillMode: Image.PreserveAspectCrop

        onStatusChanged: root.maybeStartPreparedTransition(primaryImage)
    }

    Image {
        id: secondaryImage

        anchors.fill: parent
        visible: (!root.sourceIsVideo || !liveWallpaperLoader.item?.currentPlayerReady)
                 && !root.effectActive
                 && !root.showingPrimary
                 && source !== ""
                 && (!root.holdingLiveFrame || status === Image.Ready)
        source: ""
        sourceSize: Qt.size(root.textureWidth, root.textureHeight)
        asynchronous: true
        cache: true
        smooth: false
        retainWhileLoading: true
        fillMode: Image.PreserveAspectCrop

        onStatusChanged: root.maybeStartPreparedTransition(secondaryImage)
    }

    ShaderEffectSource {
        id: srcCurrent
        sourceItem: root.effectActive ? currentImage : null
        hideSource: root.effectActive
        live: root.effectActive
        mipmap: false
        recursive: false
        textureSize: Qt.size(root.textureWidth, root.textureHeight)
    }

    ShaderEffectSource {
        id: srcNext
        sourceItem: root.effectActive ? nextImage : null
        hideSource: root.effectActive
        live: root.effectActive
        mipmap: false
        recursive: false
        textureSize: Qt.size(root.textureWidth, root.textureHeight)
    }

    Rectangle {
        id: dummyRect
        width: 1
        height: 1
        visible: false
        color: "transparent"
    }

    ShaderEffectSource {
        id: srcDummy
        sourceItem: dummyRect
        hideSource: true
        live: false
        mipmap: false
        recursive: false
    }

    Loader {
        id: effectLoader

        anchors.fill: parent
        active: root.effectActive && !root.sourceIsVideo

        function getShader(type) {
            switch (type) {
            case "fade":
                return fadeComp;
            case "wipe":
                return wipeComp;
            case "disc":
                return discComp;
            case "stripes":
                return stripesComp;
            case "iris bloom":
                return irisComp;
            case "pixelate":
                return pixelComp;
            case "portal":
                return portalComp;
            default:
                return fadeComp;
            }
        }

        sourceComponent: getShader(root.actualTransitionType)
    }

    Component {
        id: fadeComp

                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: srcCurrent
                    property variant source2: srcNext
            property real progress: root.transitionProgress
            property real fillMode: Image.PreserveAspectCrop
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            fragmentShader: Qt.resolvedUrl("../../../assets/shaders/wallpaper/wp_fade.frag.qsb")
        }
    }

    Component {
        id: wipeComp

        ShaderEffect {
            anchors.fill: parent
            property variant source1: srcCurrent
            property variant source2: srcNext
            property real progress: root.transitionProgress
            property real direction: root.wipeDirection
            property real smoothness: root.edgeSmoothness
            property real fillMode: Image.PreserveAspectCrop
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            fragmentShader: Qt.resolvedUrl("../../../assets/shaders/wallpaper/wp_wipe.frag.qsb")
        }
    }

    Component {
        id: discComp

        ShaderEffect {
            anchors.fill: parent
            property variant source1: srcCurrent
            property variant source2: srcNext
            property real progress: root.transitionProgress
            property real centerX: root.discCenterX
            property real centerY: root.discCenterY
            property real smoothness: root.edgeSmoothness
            property real aspectRatio: root.width / Math.max(1, root.height)
            property real fillMode: Image.PreserveAspectCrop
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            fragmentShader: Qt.resolvedUrl("../../../assets/shaders/wallpaper/wp_disc.frag.qsb")
        }
    }

    Component {
        id: stripesComp

        ShaderEffect {
            anchors.fill: parent
            property variant source1: srcCurrent
            property variant source2: srcNext
            property real progress: root.transitionProgress
            property real stripeCount: root.stripesCount
            property real angle: root.stripesAngle
            property real smoothness: root.edgeSmoothness
            property real aspectRatio: root.width / Math.max(1, root.height)
            property real fillMode: Image.PreserveAspectCrop
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            fragmentShader: Qt.resolvedUrl("../../../assets/shaders/wallpaper/wp_stripes.frag.qsb")
        }
    }

    Component {
        id: irisComp

        ShaderEffect {
            anchors.fill: parent
            property variant source1: srcCurrent
            property variant source2: srcNext
            property real progress: root.transitionProgress
            property real centerX: root.discCenterX
            property real centerY: root.discCenterY
            property real smoothness: root.edgeSmoothness
            property real aspectRatio: root.width / Math.max(1, root.height)
            property real fillMode: Image.PreserveAspectCrop
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            fragmentShader: Qt.resolvedUrl("../../../assets/shaders/wallpaper/wp_iris_bloom.frag.qsb")
        }
    }

    Component {
        id: pixelComp

        ShaderEffect {
            anchors.fill: parent
            property variant source1: srcCurrent
            property variant source2: srcNext
            property real progress: root.transitionProgress
            property real centerX: root.discCenterX
            property real centerY: root.discCenterY
            property real smoothness: root.edgeSmoothness
            property real aspectRatio: root.width / Math.max(1, root.height)
            property real fillMode: Image.PreserveAspectCrop
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            fragmentShader: Qt.resolvedUrl("../../../assets/shaders/wallpaper/wp_pixelate.frag.qsb")
        }
    }

    Component {
        id: portalComp

        ShaderEffect {
            anchors.fill: parent
            property variant source1: srcCurrent
            property variant source2: srcNext
            property real progress: root.transitionProgress
            property real centerX: root.discCenterX
            property real centerY: root.discCenterY
            property real smoothness: root.edgeSmoothness
            property real aspectRatio: root.width / Math.max(1, root.height)
            property real fillMode: Image.PreserveAspectCrop
            property vector4d fillColor: root.fillColor
            property real imageWidth1: root.width
            property real imageHeight1: root.height
            property real imageWidth2: root.width
            property real imageHeight2: root.height
            property real screenWidth: root.width
            property real screenHeight: root.height
            fragmentShader: Qt.resolvedUrl("../../../assets/shaders/wallpaper/wp_portal.frag.qsb")
        }
    }

    NumberAnimation {
        id: transitionAnim

        target: root
        property: "transitionProgress"
        from: 0
        to: 1
        duration: root.wallpaperTransitionDuration
        easing.type: Easing.InOutCubic

        onFinished: {
            Qt.callLater(() => root.finishTransition());
        }
    }

    Component {
        id: unsupportedLiveWallpaperComponent

        StyledRect {
            anchors.fill: parent
            color: Colours.palette.m3surfaceContainer

            Column {
                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "video_library"
                    color: Colours.palette.m3primary
                    iconPointSize: Tokens.font.size.extraLarge * 2
                }

                StyledText {
                    horizontalAlignment: Text.AlignHCenter
                    text: Config.background.liveWallpaper.enabled ? qsTr("QtMultimedia is required for live wallpapers") : qsTr("Enable live wallpapers to play video files")
                }

                StyledText {
                    visible: Config.background.liveWallpaper.enabled && !!LocalServices.Multimedia.installPackage
                    horizontalAlignment: Text.AlignHCenter
                    color: Colours.palette.m3outline
                    text: qsTr("Missing package: %1").arg(LocalServices.Multimedia.installPackage)
                }

                StyledText {
                    visible: Config.background.liveWallpaper.enabled && !!LocalServices.Multimedia.installCommand
                    horizontalAlignment: Text.AlignHCenter
                    color: Colours.palette.m3outline
                    text: LocalServices.Multimedia.installCommand
                    font.family: Config.appearance.font.family.mono
                }
            }
        }
    }

    Component {
        id: liveWallpaperComponent

        Item {
            id: liveRoot
            anchors.fill: parent
            property var primaryPlayer: null
            property var secondaryPlayer: null
            property var currentPlayer: null
            property var standbyPlayer: null
            property var retiringPlayer: null
            readonly property bool currentPlayerReady: isReady(currentPlayer)
            property string wallpaperSource: {
                if (root.sourceIsVideo)
                    return root.encodeFileUrl(root.source);
                if (root.holdingLiveFrame)
                    return root.lastVideoSource;
                return "";
            }
            property bool wallpaperMuted: Config.background.liveWallpaper.muted
            property bool playbackActive: liveRoot.visible && opacity > 0 && !!wallpaperSource

            opacity: wallpaperSource ? 1 : 0

            function createPlayer(name: string): var {
                return Qt.createQmlObject(`
                    import QtQuick
                    import QtMultimedia
                    Video {
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectCrop
                        loops: MediaPlayer.Infinite
                        playbackRate: 1.0
                        muted: true
                        volume: 0
                        visible: false
                        opacity: 0
                        layer.enabled: false
                        smooth: false

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                `, liveRoot, name);
            }

            function isReady(player: var): bool {
                if (!player)
                    return false;

                return player.mediaStatus === MediaPlayer.LoadedMedia
                    || player.mediaStatus === MediaPlayer.BufferedMedia
                    || player.mediaStatus === MediaPlayer.BufferingMedia
                    || (player.playbackState === MediaPlayer.PlayingState && player.position >= 0);
            }

            function playerSource(player: var): string {
                return player?.source ? player.source.toString() : "";
            }

            function syncAudio(): void {
                for (const player of [primaryPlayer, secondaryPlayer]) {
                    if (!player)
                        continue;
                    player.muted = wallpaperMuted;
                    player.volume = wallpaperMuted ? 0 : 1;
                }
            }

            function syncPlayback(): void {
                for (const player of [primaryPlayer, secondaryPlayer]) {
                    if (!player || !player.source)
                        continue;

                    if (playbackActive) {
                        if (player.play)
                            player.play();
                    } else if (player.pause) {
                        player.pause();
                    }
                }
            }

            function promotePlayer(player: var): void {
                if (!player || currentPlayer === player)
                    return;

                const previous = currentPlayer;
                currentPlayer = player;
                standbyPlayer = previous;

                player.z = 2;
                player.visible = true;
                player.opacity = 1;

                if (previous) {
                    previous.z = 1;
                    previous.opacity = 1;
                    retiringPlayer = previous;
                    cleanupTimer.restart();
                }
            }

            function applySource(path: string): void {
                ensurePlayers();
                syncAudio();

                if (!path) {
                    if (root.holdingLiveFrame && currentPlayer && currentPlayer.pause)
                        currentPlayer.pause();
                    return;
                }

                if (!playerSource(currentPlayer)) {
                    currentPlayer.source = path;
                    currentPlayer.visible = true;
                    currentPlayer.opacity = 1;
                    currentPlayer.z = 1;
                    if (playbackActive && currentPlayer.play)
                        currentPlayer.play();
                    return;
                }

                if (playerSource(currentPlayer) === path) {
                    syncPlayback();
                    return;
                }

                cleanupTimer.stop();
                retiringPlayer = null;

                standbyPlayer.visible = false;
                standbyPlayer.opacity = 0;
                standbyPlayer.z = 0;
                standbyPlayer.source = path;
                if (playbackActive && standbyPlayer.play)
                    standbyPlayer.play();
            }

            Timer {
                interval: 80
                repeat: true
                running: liveRoot.visible && !!liveRoot.wallpaperSource
                onTriggered: {
                    CpuProfile.bump("livePromoteTimer");
                    if (liveRoot.standbyPlayer
                            && liveRoot.playerSource(liveRoot.standbyPlayer) === liveRoot.wallpaperSource
                            && liveRoot.isReady(liveRoot.standbyPlayer))
                        liveRoot.promotePlayer(liveRoot.standbyPlayer);
                }
            }

            Timer {
                id: cleanupTimer
                interval: 220
                repeat: false
                onTriggered: {
                    if (liveRoot.retiringPlayer && liveRoot.retiringPlayer !== liveRoot.currentPlayer) {
                        liveRoot.retiringPlayer.opacity = 0;
                        liveRoot.retiringPlayer.visible = false;
                        liveRoot.retiringPlayer.z = 0;
                        if (liveRoot.retiringPlayer.stop)
                            liveRoot.retiringPlayer.stop();
                        liveRoot.retiringPlayer = null;
                    }

                    if (!liveRoot.wallpaperSource) {
                        for (const player of [liveRoot.primaryPlayer, liveRoot.secondaryPlayer]) {
                            if (!player)
                                continue;
                            player.visible = false;
                            player.z = 0;
                            if (player.stop)
                                player.stop();
                        }
                    }
                }
            }

            function ensurePlayers(): void {
                if (primaryPlayer && secondaryPlayer)
                    return;

                primaryPlayer = createPlayer("Wallpaper.LiveVideo.Primary");
                secondaryPlayer = createPlayer("Wallpaper.LiveVideo.Secondary");
                currentPlayer = primaryPlayer;
                standbyPlayer = secondaryPlayer;
                applySource(wallpaperSource);
            }

            function beginStaticHandoffCleanup(): void {
                for (const player of [primaryPlayer, secondaryPlayer]) {
                    if (!player)
                        continue;
                    player.opacity = 0;
                    player.z = 0;
                }
                cleanupTimer.restart();
            }

            onWallpaperSourceChanged: {
                if (wallpaperSource)
                    applySource(wallpaperSource);
            }

            onWallpaperMutedChanged: syncAudio()
            onPlaybackActiveChanged: syncPlayback()

            Component.onCompleted: {
                ensurePlayers();
                applySource(wallpaperSource);
            }

            Component.onDestruction: {
                for (const player of [primaryPlayer, secondaryPlayer]) {
                    if (!player)
                        continue;
                    if (player.stop)
                        player.stop();
                    player.destroy();
                }
            }
        }
    }
}
