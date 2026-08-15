
import QtQuick
import QtQuick.Layouts
import QtCore
import Quickshell.Services.UPower
import Olvex.Config
import Olvex.Internal
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services
import qs.utils

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property bool dashboardActive
    property int batteryUiEpoch: 0

    readonly property var m3Emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]
    readonly property real arcStart: 0.75 * Math.PI
    readonly property real arcSweep: 1.5 * Math.PI
    readonly property real headerH: 18
    readonly property real footerH: 28
    readonly property real batteryBarH: 30
    readonly property real batteryLevel: UPower.displayDevice.percentage
    property real batteryMeterAnim: 0

    function displayTemp(temp) {
        var v = Math.ceil(GlobalConfig.services.useFahrenheitPerformance ? temp * 1.8 + 32 : temp);
        var u = GlobalConfig.services.useFahrenheitPerformance ? "F" : "C";
        return v + "°" + u;
    }

    function formatSpeedCompact(b) {
        var f = NetworkUsage.formatBytes(b ? b : 0);
        if (!f)
            return "0";
        var d = f.value >= 100 ? 0 : (f.value >= 10 ? 1 : 2);
        return f.value.toFixed(d) + f.unit.replace("/s", "");
    }

    function formatTotalCompact(b) {
        var f = NetworkUsage.formatBytesTotal(b ? b : 0);
        if (!f)
            return "0";
        var d = f.value >= 100 ? 0 : 1;
        return f.value.toFixed(d) + f.unit;
    }

    readonly property bool showCpu: Config.dashboard.performance.showCpu
    readonly property bool showGpu: Config.dashboard.performance.showGpu && SystemUsage.gpuType !== "NONE"
    readonly property bool showMemory: Config.dashboard.performance.showMemory
    readonly property bool showStorage: Config.dashboard.performance.showStorage
    readonly property bool showNetwork: Config.dashboard.performance.showNetwork
    readonly property bool showBattery: UPower.displayDevice.isLaptopBattery && Config.dashboard.performance.showBattery
    readonly property bool hasContent: showCpu || showGpu || showMemory || showStorage || showNetwork || showBattery

    // Live-synced power state — imperative visuals; passive bindings stall in open dashboard
    property bool batOnBattery: false
    property int batDeviceState: UPowerDeviceState.Unknown
    property int batTimeToEmpty: 0
    property int batTimeToFull: 0
    property int batPowerRevision: 0
    property color batOnFillColor: Colours.palette.m3onSurface
    property bool batShowChargingBolt: false

    readonly property bool batteryPlugged: !batOnBattery
    readonly property bool batteryCharging: [UPowerDeviceState.Charging, UPowerDeviceState.PendingCharge].includes(batDeviceState)
    readonly property bool batteryFull: batDeviceState === UPowerDeviceState.FullyCharged || batteryLevel >= 0.995
    readonly property real batteryMeter: Math.min(1, Math.max(0, batteryLevel))
    readonly property bool batteryIconCharging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(batDeviceState)

    property int diskIdx: 0
    property real stableDiskPerc: 0
    property string stableDiskMount: ""
    readonly property var disk: SystemUsage.disks.length > 0 ? SystemUsage.disks[diskIdx] : null
    readonly property int diskCount: SystemUsage.disks.length
    readonly property real diskPerc: disk ? disk.perc : stableDiskPerc
    readonly property string diskMount: disk ? disk.mount : stableDiskMount
    readonly property string diskLabel: disk?.label ?? storageMountLabel(diskMount)
    readonly property string diskHint: storageVolumeHint(diskLabel, disk?.total ?? 0)

    property int gpuIdx: 0
    property real stableGpuPerc: 0
    property real stableGpuTemp: 0
    readonly property var gpu: SystemUsage.gpus.length > 0 ? SystemUsage.gpus[gpuIdx] : null
    readonly property int gpuCount: SystemUsage.gpus.length
    readonly property real gpuPerc: gpu ? gpu.perc : stableGpuPerc
    readonly property real gpuTemp: gpu ? gpu.temp : stableGpuTemp
    readonly property string gpuLabel: gpu?.label ?? (gpu?.name ?? "")
    readonly property string gpuTempText: gpuTemp > 0 ? displayTemp(gpuTemp) : ""

    Settings {
        id: resourceGpuSettings

        category: "DashboardResources"
        property alias selectedGpuIdx: root.gpuIdx
    }

    Ref {
        service: SystemUsage
        active: root.dashboardActive
    }

    function applyBatteryVisuals() {
        batOnBattery = UPower.onBattery;
        batDeviceState = UPower.displayDevice.state;
        batTimeToEmpty = UPower.displayDevice.timeToEmpty;
        batTimeToFull = UPower.displayDevice.timeToFull;

        var plugged = !batOnBattery;
        var lowPower = PowerProfiles.profile === PowerProfile.PowerSaver;
        var low = batteryLevel <= 0.20 && !plugged;
        var charging = [UPowerDeviceState.Charging, UPowerDeviceState.PendingCharge].includes(batDeviceState);

        var shell = Colours.light ? Colours.tileFillSubtle : Qt.alpha(Colours.palette.m3onSurface, 0.06);
        var track = Colours.light ? Colours.tileFill : Qt.alpha(Colours.palette.m3onSurface, 0.14);
        var outline = Qt.alpha(Colours.palette.m3outline, 0.50);
        var fill = Colours.palette.m3primary;
        var onFill = Colours.palette.m3onPrimary;
        var fillOp = 0.48;

        if (plugged) {
            outline = Qt.alpha(batIosGreen, 0.55);
            fill = batIosGreen;
            onFill = "#ffffff";
            fillOp = 0.62;
        } else if (lowPower) {
            fill = batIosYellow;
            onFill = "#1c1c1e";
        } else if (low) {
            shell = Qt.alpha(Colours.palette.m3error, 0.10);
            track = Qt.alpha(Colours.palette.m3error, 0.16);
            outline = Qt.alpha(Colours.palette.m3error, 0.55);
            fill = Colours.palette.m3error;
            onFill = Colours.palette.m3onError;
        }

        batOnFillColor = onFill;
        batShowChargingBolt = charging;

        if (batBody) {
            batBody.color = shell;
            batBody.border.color = outline;
        }
        if (batCap)
            batCap.color = outline;
        if (batTrack)
            batTrack.color = track;
        if (batFill) {
            batFill.color = fill;
            batFill.opacity = fillOp;
        }

        batPowerRevision++;
    }

    Component.onCompleted: {
        applyBatteryVisuals();
        batteryMeterAnim = batteryMeter;
        if (disk) {
            stableDiskPerc = disk.perc;
            stableDiskMount = disk.mount;
        }
        if (gpu) {
            stableGpuPerc = gpu.perc;
            stableGpuTemp = gpu.temp;
        }
    }

    onBatteryLevelChanged: {
        batteryMeterAnim = batteryMeter;
        applyBatteryVisuals();
    }

    onBatteryUiEpochChanged: applyBatteryVisuals()

    Connections {
        target: UPower
        function onOnBatteryChanged(): void {
            Qt.callLater(root.applyBatteryVisuals);
        }
    }

    Connections {
        target: UPower.displayDevice
        function onPercentageChanged(): void {
            root.batteryMeterAnim = root.batteryMeter;
            Qt.callLater(root.applyBatteryVisuals);
        }
        function onStateChanged(): void {
            Qt.callLater(root.applyBatteryVisuals);
        }
        function onPowerSupplyChanged(): void {
            Qt.callLater(root.applyBatteryVisuals);
        }
        function onTimeToEmptyChanged(): void {
            root.batTimeToEmpty = UPower.displayDevice.timeToEmpty;
            root.batPowerRevision++;
        }
        function onTimeToFullChanged(): void {
            root.batTimeToFull = UPower.displayDevice.timeToFull;
            root.batPowerRevision++;
        }
    }

    Connections {
        target: PowerProfiles
        function onProfileChanged(): void {
            Qt.callLater(root.applyBatteryVisuals);
        }
    }

    Connections {
        target: visibilities
        function onDashboardChanged(): void {
            if (root.dashboardActive)
                Qt.callLater(root.applyBatteryVisuals);
        }
    }

    Connections {
        function onDisksChanged() {
            if (diskIdx >= SystemUsage.disks.length)
                diskIdx = Math.max(0, SystemUsage.disks.length - 1);
            if (root.disk) {
                root.stableDiskPerc = root.disk.perc;
                root.stableDiskMount = root.disk.mount;
            }
        }
        function onGpusChanged() {
            if (gpuIdx >= SystemUsage.gpus.length)
                gpuIdx = Math.max(0, SystemUsage.gpus.length - 1);
            if (root.gpu) {
                root.stableGpuPerc = root.gpu.perc;
                root.stableGpuTemp = root.gpu.temp;
            }
        }
        target: SystemUsage
    }

    onDiskChanged: {
        if (disk) {
            stableDiskPerc = disk.perc;
            stableDiskMount = disk.mount;
        }
    }

    onGpuChanged: {
        if (gpu) {
            stableGpuPerc = gpu.perc;
            stableGpuTemp = gpu.temp;
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: !hasContent
        text: qsTr("No monitors enabled")
        textPointSize: Tokens.font.size.small
        color: Colours.palette.m3onSurfaceVariant
        opacity: 0.55
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6
        visible: hasContent

        Item {
            id: batBar

            visible: showBattery
            Layout.fillWidth: true
            Layout.preferredHeight: batteryBarH

            readonly property real capW: 4
            readonly property real inset: 2
            readonly property int bodyRadius: 7
            Rectangle {
                id: batCap

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: batBar.capW
                height: parent.height * 0.34
                radius: 2
                color: Qt.alpha(Colours.palette.m3outline, 0.50)
            }

            StyledClippingRect {
                id: batBody

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: batCap.left
                radius: batBar.bodyRadius
                color: Colours.light ? Colours.tileFillSubtle : Qt.alpha(Colours.palette.m3onSurface, 0.06)
                border.width: 1
                border.color: Colours.light ? Colours.tileStrokeSubtle : Qt.alpha(Colours.palette.m3outline, 0.50)
                clip: true

                readonly property real innerW: Math.max(0, width - batBar.inset * 2)
                readonly property real fillW: innerW * root.batteryMeterAnim

                StyledRect {
                    id: batTrack

                    anchors.fill: parent
                    anchors.margins: batBar.inset
                    radius: Math.max(2, batBar.bodyRadius - batBar.inset)
                    color: Colours.light ? Colours.tileFill : Qt.alpha(Colours.palette.m3onSurface, 0.14)
                    z: 0
                }

                StyledRect {
                    id: batFill

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.topMargin: batBar.inset
                    anchors.bottomMargin: batBar.inset
                    anchors.leftMargin: batBar.inset
                    width: root.batteryMeterAnim > 0 ? Math.max(6, batBody.fillW) : 0
                    radius: Math.max(2, batBar.bodyRadius - batBar.inset)
                    color: Colours.palette.m3primary
                    opacity: 0.48
                    z: 1

                    Behavior on width {
                        Anim {
                            type: Anim.StandardLarge
                        }
                    }
                }

                MaterialIcon {
                    visible: batShowChargingBolt
                    anchors.centerIn: parent
                    text: "bolt"
                    iconPointSize: 12
                    color: "#ffffff"
                    fill: 1
                    opacity: 0.95
                    z: 1
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 6
                    z: 2

                    StyledText {
                        id: batPctText

                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignVCenter
                        maximumLineCount: 1
                        text: batRemainingText()
                        textPointSize: Tokens.font.size.smaller
                        font.family: Tokens.font.family.mono
                        font.weight: Font.Medium
                        color: batBar.inset + batFill.width > (10 + implicitWidth) ? batOnFillColor : Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignRight
                        maximumLineCount: 1
                        text: batTimeText(batPowerRevision)
                        textPointSize: Tokens.font.size.smaller
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurfaceVariant
                        opacity: 0.88
                        elide: Text.ElideLeft
                    }
                }
            }
        }

        RowLayout {
            id: deckRow

            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            readonly property int deckCellCount: (showCpu ? 1 : 0) + (showGpu ? 1 : 0) + (showMemory ? 1 : 0) + (showStorage ? 1 : 0) + (showNetwork ? 1 : 0)
            readonly property int deckSepCount: Math.max(0, deckCellCount - 1)
            readonly property int deckSlotCount: deckCellCount + deckSepCount
            readonly property real deckAvailW: Math.max(0, root.width - 16)
            readonly property real deckGapW: deckSlotCount > 1 ? (deckSlotCount - 1) * spacing : 0
            readonly property real deckUnitW: deckCellCount > 0 ? Math.max(52, (deckAvailW - deckGapW - deckSepCount) / deckCellCount) : 0
            readonly property real deckCompactW: Math.max(44, deckUnitW * 0.72)
            readonly property real deckNetW: Math.max(88, deckUnitW * 1.65)

            CpuVial {
                visible: showCpu
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 44
                Layout.preferredWidth: deckRow.deckCompactW
                Layout.horizontalStretchFactor: 1
                value: SystemUsage.cpuPerc
                hint: displayTemp(SystemUsage.cpuTemp)
            }

            DeckSep {
                visible: showCpu && (showGpu || showMemory || showStorage || showNetwork)
            }

            GpuArc {
                visible: showGpu
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 44
                Layout.preferredWidth: deckRow.deckCompactW
                Layout.horizontalStretchFactor: 1
                value: root.gpuPerc
                nameText: root.gpuLabel
                tempText: root.gpuTempText
                showScrollHint: root.gpuCount > 1
                gpuCount: root.gpuCount
                onScrollGpu: function (delta) {
                    if (delta > 0)
                        root.gpuIdx = (root.gpuIdx - 1 + root.gpuCount) % root.gpuCount;
                    else if (delta < 0)
                        root.gpuIdx = (root.gpuIdx + 1) % root.gpuCount;
                }
            }

            DeckSep {
                visible: showGpu && (showMemory || showStorage || showNetwork)
            }

            RamTank {
                visible: showMemory
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 44
                Layout.preferredWidth: deckRow.deckCompactW
                Layout.horizontalStretchFactor: 1
                value: SystemUsage.memPerc
                hint: {
                    var u = SystemUsage.formatKib(SystemUsage.memUsed);
                    var t = SystemUsage.formatKib(SystemUsage.memTotal);
                    return u.value.toFixed(0) + "/" + Math.floor(t.value) + t.unit;
                }
            }

            DeckSep {
                visible: showMemory && (showStorage || showNetwork)
            }

            DiskDotMatrix {
                visible: showStorage
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 52
                Layout.preferredWidth: deckRow.deckUnitW
                Layout.horizontalStretchFactor: 1
                value: diskPerc
                detail: diskMount
                hint: diskHint
                showScrollHint: root.diskCount > 1
                diskCount: root.diskCount
                onScrollDisk: function (delta) {
                    if (delta > 0)
                        root.diskIdx = (root.diskIdx - 1 + root.diskCount) % root.diskCount;
                    else if (delta < 0)
                        root.diskIdx = (root.diskIdx + 1) % root.diskCount;
                }
            }

            DeckSep {
                visible: showStorage && showNetwork
            }

            NetGauge {
                visible: showNetwork
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 72
                Layout.preferredWidth: deckRow.deckNetW
                Layout.horizontalStretchFactor: 3
            }
        }
    }

    readonly property color batIosGreen: "#34C759"
    readonly property color batIosYellow: "#FFD60A"

    function formatBatDuration(s, fallback) {
        if (!s)
            return fallback;
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    function batRemainingText() {
        return Math.round(batteryLevel * 100) + "%";
    }

    function batTimeText(rev) {
        void rev;
        var label = batOnBattery ? qsTr("remaining") : qsTr("until charged");
        var seconds = batOnBattery ? batTimeToEmpty : batTimeToFull;
        var fallback = batOnBattery ? qsTr("Calculating…") : qsTr("Fully charged!");
        return qsTr("Time %1: %2").arg(label).arg(formatBatDuration(seconds, fallback));
    }

    component DeckSep: Rectangle {
        Layout.fillWidth: false
        Layout.preferredWidth: 1
        Layout.minimumWidth: 1
        Layout.maximumWidth: 1
        Layout.fillHeight: true
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.14)
    }

    component InstrumentHeader: RowLayout {
        property string icon: ""
        property string label: ""
        property color accent: Colours.palette.m3primary
        property bool showScrollHint: false

        Layout.fillWidth: true
        Layout.preferredHeight: headerH
        spacing: 4

        MaterialIcon {
            text: parent.icon
            iconPointSize: 14
            color: parent.accent
            fill: 1
        }

        StyledText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            maximumLineCount: 1
            text: parent.label
            textPointSize: Tokens.font.size.smaller
            font.weight: Font.DemiBold
            color: Colours.palette.m3onSurface
            elide: Text.ElideRight
        }

        MaterialIcon {
            visible: parent.showScrollHint
            text: "unfold_more"
            iconPointSize: 12
            color: Colours.palette.m3onSurfaceVariant
            opacity: 0.45
        }
    }

    component MarqueeLabel: Item {
        id: marqueeRoot

        property string text: ""

        readonly property real speed: 28
        readonly property bool needsMarquee: width > 0 && labelText.implicitWidth > width + 1
        implicitHeight: labelText.implicitHeight > 0 ? labelText.implicitHeight : Math.round(Tokens.font.size.smaller * 96 / 72)

        clip: true

        Row {
            id: marqueeRow

            spacing: 32
            property real scrollX: 0

            height: parent.height
            y: 0
            x: marqueeRoot.needsMarquee ? marqueeRow.scrollX : Math.max(0, (marqueeRoot.width - marqueeRow.width) / 2)

            StyledText {
                id: labelText

                text: marqueeRoot.text
                textPointSize: Tokens.font.size.smaller
                color: Colours.palette.m3onSurfaceVariant
                opacity: 0.58
                height: parent.height
                verticalAlignment: Text.AlignVCenter
            }

            StyledText {
                text: labelText.text
                textPointSize: labelText.textPointSize
                color: labelText.color
                opacity: labelText.opacity
                visible: marqueeRoot.needsMarquee
                height: parent.height
                verticalAlignment: Text.AlignVCenter
            }
        }

        SequentialAnimation {
            id: marqueeAnim

            running: marqueeRoot.needsMarquee && marqueeRoot.visible && marqueeRoot.width > 0
            loops: Animation.Infinite

            PauseAnimation {
                duration: 2000
            }

            NumberAnimation {
                target: marqueeRow
                property: "scrollX"
                from: 0
                to: -(labelText.implicitWidth + marqueeRow.spacing)
                duration: Math.max(3000, labelText.implicitWidth * 1000 / marqueeRoot.speed)
                easing.type: Easing.Linear
            }

            PauseAnimation {
                duration: 1200
            }

            PropertyAction {
                target: marqueeRow
                property: "scrollX"
                value: 0
            }
        }

        function restartMarquee() {
            if (!needsMarquee)
                return;
            marqueeAnim.stop();
            marqueeRow.scrollX = 0;
            marqueeAnim.start();
        }

        onTextChanged: Qt.callLater(restartMarquee)
        onWidthChanged: Qt.callLater(restartMarquee)
        onNeedsMarqueeChanged: Qt.callLater(restartMarquee)
    }

    component StatFooter: ColumnLayout {
        property string valueText: ""
        property string hintText: ""
        property bool marqueeHint: false
        property color accent: Colours.palette.m3onSurface

        Layout.fillWidth: true
        Layout.preferredHeight: footerH
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: valueText !== ""
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 1
            text: valueText
            textPointSize: Tokens.font.size.small
            font.weight: Font.Medium
            font.family: Tokens.font.family.mono
            color: accent
            elide: Text.ElideRight
        }

        MarqueeLabel {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: marqueeHint && hintText !== ""
            text: hintText
        }

        StyledText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: !marqueeHint && hintText !== ""
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 1
            text: hintText
            textPointSize: Tokens.font.size.smaller
            color: Colours.palette.m3onSurfaceVariant
            opacity: 0.58
            elide: Text.ElideRight
        }
    }

    component CpuVial: ColumnLayout {
        id: cpuCell

        property real value: 0
        property string hint: ""

        clip: true
        implicitWidth: 0
        spacing: 4

        InstrumentHeader {
            icon: "memory"
            label: qsTr("CPU")
            accent: Colours.palette.m3primary
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 40
            clip: true

            StyledClippingRect {
                anchors.centerIn: parent
                width: Math.min(22, parent.width - 4)
                height: Math.max(0, parent.height - 2)
                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3primary, 0.08)

                StyledRect {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * Math.max(0, Math.min(1, cpuCell.value))
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primary

                    Behavior on height {
                        Anim {
                            type: Anim.StandardLarge
                        }
                    }
                }
            }
        }

        StatFooter {
            valueText: Math.round(cpuCell.value * 100) + "%"
            hintText: qsTr("Temp %1").arg(hint)
            accent: Colours.palette.m3primary
        }
    }

    component GpuArc: ColumnLayout {
        id: gpuCell

        property real value: 0
        property real animatedValue: 0
        property string nameText: ""
        property string tempText: ""
        property bool showScrollHint: false
        property int gpuCount: 0
        signal scrollGpu(real delta)

        clip: true
        implicitWidth: 0
        spacing: 4

        Component.onCompleted: gpuCell.animatedValue = gpuCell.value
        onValueChanged: gpuCell.animatedValue = gpuCell.value

        Behavior on animatedValue {
            Anim {
                type: Anim.StandardLarge
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            blocking: true
            enabled: gpuCell.showScrollHint && gpuCell.gpuCount > 1
            onWheel: function (event) {
                if (event.angleDelta.y > 0)
                    gpuCell.scrollGpu(1);
                else if (event.angleDelta.y < 0)
                    gpuCell.scrollGpu(-1);
                event.accepted = true;
            }
        }

        InstrumentHeader {
            icon: "desktop_windows"
            label: qsTr("GPU")
            accent: Colours.palette.m3secondary
            showScrollHint: gpuCell.showScrollHint
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 40
            clip: true

            readonly property real dia: Math.max(28, Math.min(width, height) - 4)

            ArcGauge {
                anchors.centerIn: parent
                width: parent.dia
                height: parent.dia
                percentage: gpuCell.animatedValue
                accentColor: Colours.palette.m3secondary
                trackColor: Qt.alpha(Colours.palette.m3outlineVariant, 0.12)
                startAngle: root.arcStart
                sweepAngle: root.arcSweep
                lineWidth: Tokens.sizes.dashboard.resourceProgressThickness
            }

            StyledText {
                anchors.centerIn: parent
                text: Math.round(gpuCell.animatedValue * 100) + "%"
                textPointSize: Tokens.font.size.small
                font.weight: Font.Medium
                font.family: Tokens.font.family.mono
                color: Colours.palette.m3secondary
            }
        }

        StatFooter {
            valueText: gpuCell.tempText !== "" ? qsTr("Temp %1").arg(gpuCell.tempText) : ""
            hintText: gpuCell.nameText
            marqueeHint: true
            accent: Colours.palette.m3secondary
        }
    }

    component RamTank: ColumnLayout {
        id: ramCell

        property real value: 0
        property string hint: ""

        readonly property int tiers: 5

        clip: true
        implicitWidth: 0
        spacing: 4

        InstrumentHeader {
            icon: "memory_alt"
            label: qsTr("RAM")
            accent: Colours.palette.m3tertiary
        }

        Item {
            id: ramBody
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 40
            clip: true

            readonly property real rowH: Math.max(4, (height - (ramCell.tiers - 1) * 3) / ramCell.tiers)

            Column {
                anchors.fill: parent
                spacing: 3

                Repeater {
                    model: ramCell.tiers

                    Item {
                        required property int index

                        width: ramBody.width
                        height: ramBody.rowH

                        readonly property real tierFill: Math.max(0, Math.min(1, ramCell.value * ramCell.tiers - index))

                        StyledRect {
                            anchors.fill: parent
                            radius: 3
                            color: Qt.alpha(Colours.palette.m3tertiary, 0.09)
                        }

                        StyledRect {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * parent.tierFill
                            height: parent.height
                            radius: 3
                            color: Colours.palette.m3tertiary

                            Behavior on width {
                                Anim {
                                    type: Anim.StandardLarge
                                }
                            }
                        }
                    }
                }
            }
        }

        StatFooter {
            valueText: Math.round(ramCell.value * 100) + "%"
            hintText: hint
            accent: Colours.palette.m3tertiary
        }
    }

    function storageMountLabel(mount) {
        if (!mount || mount === "/")
            return "root";
        var name = mount.replace(/\/$/, "").split("/").pop();
        return name !== "" ? name : mount;
    }

    function storageVolumeHint(label, totalKib) {
        if (!label)
            return "";
        if (!totalKib)
            return label;
        const f = SystemUsage.formatKib(totalKib);
        const d = f.value >= 100 ? 0 : (f.value >= 10 ? 1 : 2);
        return label + " · " + f.value.toFixed(d) + " " + f.unit;
    }

    component DiskDotMatrix: ColumnLayout {
        id: diskCell

        property real value: 0
        property string detail: ""
        property string hint: ""
        property bool showScrollHint: false
        property int diskCount: 0
        signal scrollDisk(real delta)

        readonly property int dotCols: 7
        readonly property int dotRows: 7
        readonly property int dotGap: 2
        readonly property int dotCount: dotCols * dotRows
        readonly property int litDots: Math.round(diskCell.value * diskCell.dotCount)

        clip: true
        implicitWidth: 0
        spacing: 4

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            blocking: true
            enabled: diskCell.showScrollHint && diskCell.diskCount > 1
            onWheel: function (event) {
                if (event.angleDelta.y > 0)
                    diskCell.scrollDisk(1);
                else if (event.angleDelta.y < 0)
                    diskCell.scrollDisk(-1);
                event.accepted = true;
            }
        }

        InstrumentHeader {
            icon: "hard_disk"
            label: qsTr("Storage")
            accent: Colours.palette.m3secondary
            showScrollHint: showScrollHint
        }

        Item {
            id: diskBody
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 46

            readonly property real pad: 3
            readonly property real dotSize: Math.max(2, Math.min((width - pad * 2 - (diskCell.dotCols - 1) * diskCell.dotGap) / diskCell.dotCols, (height - pad * 2 - (diskCell.dotRows - 1) * diskCell.dotGap) / diskCell.dotRows))

            readonly property real gridW: diskCell.dotCols * dotSize + (diskCell.dotCols - 1) * diskCell.dotGap
            readonly property real gridH: diskCell.dotRows * dotSize + (diskCell.dotRows - 1) * diskCell.dotGap
            readonly property real originX: Math.max(pad, (width - gridW) / 2)
            readonly property real originY: Math.max(pad, (height - gridH) / 2)

            Repeater {
                model: diskCell.dotCount

                StyledRect {
                    required property int index

                    readonly property bool lit: index < diskCell.litDots
                    readonly property int row: Math.floor(index / diskCell.dotCols)
                    readonly property int col: index % diskCell.dotCols

                    x: diskBody.originX + col * (diskBody.dotSize + diskCell.dotGap)
                    y: diskBody.originY + row * (diskBody.dotSize + diskCell.dotGap)
                    width: diskBody.dotSize
                    height: diskBody.dotSize
                    radius: Math.max(1, diskBody.dotSize * 0.22)
                    color: lit ? Colours.palette.m3secondary : Qt.alpha(Colours.palette.m3outlineVariant, 0.14)
                    border.width: lit ? 0 : 1
                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.32)
                    opacity: lit ? 1.0 : 0.88
                }
            }
        }

        StatFooter {
            valueText: Math.round(diskCell.value * 100) + "%"
            hintText: hint !== "" ? hint : storageMountLabel(detail)
            accent: Colours.palette.m3secondary
        }
    }

    component NetFooter: GridLayout {
        id: netFoot

        Layout.fillWidth: true
        Layout.preferredHeight: footerH
        columns: 3
        columnSpacing: 4
        rowSpacing: 2

        readonly property real iconColW: 13
        readonly property real totalColW: 64

        MaterialIcon {
            Layout.row: 0
            Layout.column: 0
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: netFoot.iconColW
            Layout.maximumWidth: netFoot.iconColW
            text: "upload"
            iconPointSize: 11
            color: Colours.palette.m3secondary
            fill: 1
        }

        StyledText {
            Layout.row: 0
            Layout.column: 1
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            maximumLineCount: 1
            text: formatSpeedCompact(NetworkUsage.uploadSpeed)
            textPointSize: Tokens.font.size.smaller
            font.family: Tokens.font.family.mono
            font.weight: Font.Medium
            color: Colours.palette.m3secondary
            elide: Text.ElideRight
        }

        StyledText {
            Layout.row: 0
            Layout.column: 2
            Layout.preferredWidth: netFoot.totalColW
            Layout.minimumWidth: netFoot.totalColW
            Layout.maximumWidth: netFoot.totalColW
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            horizontalAlignment: Text.AlignRight
            maximumLineCount: 1
            text: formatTotalCompact(NetworkUsage.uploadTotal)
            textPointSize: Tokens.font.size.smaller
            font.family: Tokens.font.family.mono
            color: Colours.palette.m3onSurfaceVariant
            opacity: 0.58
            elide: Text.ElideLeft
        }

        MaterialIcon {
            Layout.row: 1
            Layout.column: 0
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: netFoot.iconColW
            Layout.maximumWidth: netFoot.iconColW
            text: "download"
            iconPointSize: 11
            color: Colours.palette.m3tertiary
            fill: 1
        }

        StyledText {
            Layout.row: 1
            Layout.column: 1
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            maximumLineCount: 1
            text: formatSpeedCompact(NetworkUsage.downloadSpeed)
            textPointSize: Tokens.font.size.smaller
            font.family: Tokens.font.family.mono
            font.weight: Font.Medium
            color: Colours.palette.m3tertiary
            elide: Text.ElideRight
        }

        StyledText {
            Layout.row: 1
            Layout.column: 2
            Layout.preferredWidth: netFoot.totalColW
            Layout.minimumWidth: netFoot.totalColW
            Layout.maximumWidth: netFoot.totalColW
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            horizontalAlignment: Text.AlignRight
            maximumLineCount: 1
            text: formatTotalCompact(NetworkUsage.downloadTotal)
            textPointSize: Tokens.font.size.smaller
            font.family: Tokens.font.family.mono
            color: Colours.palette.m3onSurfaceVariant
            opacity: 0.58
            elide: Text.ElideLeft
        }
    }

    component NetPulseBar: StyledRect {
        property real value: 0
        property real maxValue: 1024
        property color accent: Colours.palette.m3tertiary

        Layout.fillWidth: true
        Layout.preferredHeight: 2
        radius: 1
        color: Qt.alpha(accent, 0.14)

        StyledRect {
            anchors.left: parent.left
            height: parent.height
            width: parent.width * Math.min(1, value / Math.max(maxValue, 1))
            radius: parent.radius
            color: accent

            Behavior on width {
                Anim {
                    type: Anim.StandardLarge
                }
            }
        }
    }

    component NetGauge: ColumnLayout {
        clip: true
        implicitWidth: 0
        spacing: 4

        InstrumentHeader {
            icon: "swap_vert"
            label: qsTr("Network")
            accent: Colours.palette.m3tertiary
        }

        Item {
            id: netBody
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 44

            Ref {
                service: NetworkUsage
                active: root.dashboardActive
            }

            SparklineItem {
                id: netSpark

                property real targetMax: 1024
                property real smoothMax: netSpark.targetMax

                anchors.fill: parent
                anchors.bottomMargin: 6
                line1: NetworkUsage.uploadBuffer
                line1Color: Colours.palette.m3secondary
                line1FillAlpha: 0.08
                line2: NetworkUsage.downloadBuffer
                line2Color: Colours.palette.m3tertiary
                line2FillAlpha: 0.12
                maxValue: smoothMax
                historyLength: NetworkUsage.historyLength
                lineWidth: 1.5

                Connections {
                    enabled: root.dashboardActive
                    target: NetworkUsage.downloadBuffer
                    function onValuesChanged() {
                        netSpark.targetMax = Math.max(NetworkUsage.downloadBuffer.maximum, NetworkUsage.uploadBuffer.maximum, 1024);
                        if (root.dashboardActive)
                            netSlide.restart();
                    }
                }

                NumberAnimation {
                    id: netSlide
                    target: netSpark
                    property: "slideProgress"
                    from: 0
                    to: 1
                    duration: GlobalConfig.dashboard.resourceUpdateInterval
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.m3Emphasized
                }

                Behavior on smoothMax {
                    Anim {
                        type: Anim.StandardLarge
                    }
                }
            }

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 1

                NetPulseBar {
                    value: NetworkUsage.uploadSpeed
                    maxValue: netSpark.smoothMax
                    accent: Colours.palette.m3secondary
                }

                NetPulseBar {
                    value: NetworkUsage.downloadSpeed
                    maxValue: netSpark.smoothMax
                    accent: Colours.palette.m3tertiary
                }
            }
        }

        NetFooter {}
    }
}
