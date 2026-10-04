import "."
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

Item {
    id: root

    required property var monitor
    required property var allMonitors
    required property bool useDescription

    signal monitorUpdated(var updatedData)
    signal useDescriptionToggled(bool value)
    signal setAsPrimaryRequested()

    implicitWidth: parent ? parent.width : 500
    implicitHeight: mainCol.implicitHeight

    // Scale presets
    readonly property var scalePresets: [
        { label: "100%", val: 1.0 },
        { label: "125%", val: 1.25 },
        { label: "150%", val: 1.5 },
        { label: "175%", val: 1.75 },
        { label: "200%", val: 2.0 },
        { label: "250%", val: 2.5 }
    ]

    // Transforms list
    readonly property var transformOptions: [
        { label: "Normal (0°)", val: 0 },
        { label: "90° Clockwise", val: 1 },
        { label: "180° Inverted", val: 2 },
        { label: "270° Counter-Clockwise", val: 3 },
        { label: "Flipped (Horizontal)", val: 4 },
        { label: "Flipped 90°", val: 5 },
        { label: "Flipped 180°", val: 6 },
        { label: "Flipped 270°", val: 7 }
    ]

    // VRR options
    readonly property var vrrOptions: [
        { label: "Disabled (0)", val: 0 },
        { label: "Always On (1)", val: 1 },
        { label: "Fullscreen Only (2)", val: 2 }
    ]

    // Scale Filter options
    readonly property var scaleFilterOptions: [
        { label: "Linear (Default)", val: "linear" },
        { label: "Nearest (Pixel-Art)", val: "nearest" }
    ]

    // Color Management Preset
    readonly property var colorModeOptions: [
        { label: "sRGB (Default)", val: "srgb" },
        { label: "Auto", val: "auto" },
        { label: "Wide", val: "wide" },
        { label: "EDID", val: "edid" },
        { label: "HDR", val: "hdr" },
        { label: "HDR EDID", val: "hdredid" }
    ]

    function updateField(key, value) {
        if (!root.monitor) return;
        const copy = JSON.parse(JSON.stringify(root.monitor));
        copy[key] = value;

        // Recompute logical dimensions if width, height, scale, or transform changed
        const w = copy.width || 1920;
        const h = copy.height || 1080;
        const s = copy.scale || 1.0;
        const t = copy.transform || 0;
        const isRot = (t === 1 || t === 3 || t === 5 || t === 7);
        copy.logicalWidth = Math.round((isRot ? h : w) / s);
        copy.logicalHeight = Math.round((isRot ? w : h) / s);

        root.monitorUpdated(copy);
    }

    Column {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing ? Tokens.spacing.large : 16

        // ── Monitor Summary Card ────────────────────────────────────────────
        StyledRect {
            width: parent.width
            implicitHeight: headerRow.implicitHeight + (Tokens.padding ? Tokens.padding.normal : 12) * 2
            radius: Tokens.rounding ? Tokens.rounding.large : 16
            color: Colours.palette.m3surfaceContainerHigh

            RowLayout {
                id: headerRow
                anchors.fill: parent
                anchors.margins: Tokens.padding ? Tokens.padding.normal : 12
                spacing: Tokens.spacing ? Tokens.spacing.normal : 12

                MaterialIcon {
                    text: root.monitor && root.monitor.name.startsWith("eDP") ? "laptop" : "desktop_windows"
                    fill: 1
                    color: Colours.palette.m3primary
                    iconPointSize: Tokens.font ? Tokens.font.size.extraLarge : 20
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: root.monitor ? root.monitor.name : "Display"
                        font.weight: Font.Bold
                        textPointSize: Tokens.font ? Tokens.font.size.large : 16
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        text: root.monitor && root.monitor.description
                              ? root.monitor.description
                              : (root.monitor ? `${root.monitor.make} ${root.monitor.model}` : "")
                        textPointSize: Tokens.font ? Tokens.font.size.smaller : 11
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Layout containing switches
                ColumnLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    StyledSwitch {
                        Layout.alignment: Qt.AlignRight
                        checked: root.monitor ? !root.monitor.disabled : true
                        onToggled: {
                            root.updateField("disabled", !checked);
                        }
                    }
                    StyledText {
                        text: qsTr("Enabled")
                        color: Colours.palette.m3onSurfaceVariant
                        textPointSize: (Tokens.font ? Tokens.font.size.smaller : 11) - 2
                        Layout.alignment: Qt.AlignRight
                    }

                    StyledSwitch {
                        Layout.alignment: Qt.AlignRight
                        checked: root.monitor ? root.monitor.dpmsStatus : true
                        onToggled: {
                            root.updateField("dpmsStatus", checked);
                        }
                    }
                    StyledText {
                        text: qsTr("Screen Power")
                        color: Colours.palette.m3onSurfaceVariant
                        textPointSize: (Tokens.font ? Tokens.font.size.smaller : 11) - 2
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }
        }

        // ── Section 1: Resolution, Modes & Scaling ──────────────────────────
        Section {
            title: qsTr("Resolution & Display Modes")
            icon: "display_settings"
            accentColor: Colours.palette.m3primary

            // Modes Dropdown
            SettingRow {
                title: qsTr("Resolution & Refresh Rate")
                description: qsTr("Hardware-supported display modes")
                visible: !(root.monitor && root.monitor.customMode)

                OptionPicker {
                    id: modePicker
                    model: {
                        if (!root.monitor || !root.monitor.availableModes) return [];
                        return root.monitor.availableModes.map(m => ({ label: m, val: m }));
                    }
                    currentIndex: {
                        if (!root.monitor || !root.monitor.availableModes) return 0;
                        const target = `${root.monitor.width}x${root.monitor.height}@${Math.round(root.monitor.refreshRate)}.00Hz`;
                        const idx = root.monitor.availableModes.findIndex(m => m.startsWith(`${root.monitor.width}x${root.monitor.height}`));
                        return idx >= 0 ? idx : 0;
                    }
                    onSelected: (idx) => {
                        const mStr = root.monitor.availableModes[idx];
                        if (mStr) {
                            // Parse "1920x1080@144.00Hz"
                            const match = mStr.match(/^(\d+)x(\d+)@([0-9.]+)Hz/);
                            if (match) {
                                const copy = JSON.parse(JSON.stringify(root.monitor));
                                copy.width = parseInt(match[1]);
                                copy.height = parseInt(match[2]);
                                copy.refreshRate = parseFloat(match[3]);
                                const isRot = (copy.transform === 1 || copy.transform === 3 || copy.transform === 5 || copy.transform === 7);
                                copy.logicalWidth = Math.round((isRot ? copy.height : copy.width) / copy.scale);
                                copy.logicalHeight = Math.round((isRot ? copy.width : copy.height) / copy.scale);
                                root.monitorUpdated(copy);
                            }
                        }
                    }
                }
            }

            // Custom Mode Toggle
            SettingRow {
                title: qsTr("Custom Resolution Mode")
                description: qsTr("Manually specify resolution and refresh rate")

                StyledSwitch {
                    checked: root.monitor ? !!root.monitor.customMode : false
                    onToggled: root.updateField("customMode", checked)
                }
            }

            // Custom inputs row (Width, Height, Hz)
            Item {
                visible: root.monitor && root.monitor.customMode
                implicitWidth: parent.width
                implicitHeight: 48

                RowLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing ? Tokens.spacing.normal : 12

                    StyledTextField {
                        Layout.fillWidth: true
                        placeholderText: qsTr("Width (e.g. 1920)")
                        text: root.monitor ? String(root.monitor.width) : "1920"
                        onTextEdited: {
                            const v = parseInt(text);
                            if (v > 200) root.updateField("width", v);
                        }
                    }

                    StyledText {
                        text: "×"
                        font.weight: Font.Bold
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledTextField {
                        Layout.fillWidth: true
                        placeholderText: qsTr("Height (e.g. 1080)")
                        text: root.monitor ? String(root.monitor.height) : "1080"
                        onTextEdited: {
                            const v = parseInt(text);
                            if (v > 200) root.updateField("height", v);
                        }
                    }

                    StyledText {
                        text: "@"
                        font.weight: Font.Bold
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledTextField {
                        Layout.fillWidth: true
                        placeholderText: qsTr("Hz (e.g. 144)")
                        text: root.monitor ? String(root.monitor.refreshRate) : "60"
                        onTextEdited: {
                            const v = parseFloat(text);
                            if (v > 20) root.updateField("refreshRate", v);
                        }
                    }
                }
            }

            // Scaling Chips + Precision Slider
            SettingRow {
                title: qsTr("Display Scaling")
                description: qsTr("Fractional scale factor for high-DPI displays")

                RowLayout {
                    spacing: 6
                    Repeater {
                        model: root.scalePresets
                        delegate: StyledRect {
                            required property var modelData
                            implicitWidth: 46
                            implicitHeight: 32
                            radius: Tokens.rounding ? Tokens.rounding.small : 8
                            readonly property bool isSelected: root.monitor && Math.abs(root.monitor.scale - modelData.val) < 0.01

                            color: isSelected ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh
                            border.width: 1
                            border.color: isSelected ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.4)

                            StyledText {
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                textPointSize: (Tokens.font ? Tokens.font.size.smaller : 11) - 2
                                font.weight: parent.isSelected ? Font.Bold : Font.Normal
                                color: parent.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            }

                            StateLayer {
                                radius: parent.radius
                                onClicked: root.updateField("scale", parent.modelData.val)
                            }
                        }
                    }
                }
            }

            // Precision Scale Adjustment
            SettingRow {
                title: qsTr("Fine Scale Adjustment")
                description: qsTr("Adjust fractional scale factor")

                CustomSpinBox {
                    value: root.monitor ? Number(root.monitor.scale) : 1.0
                    min: 0.5
                    max: 4.0
                    step: 0.05
                    onValueModified: v => {
                        root.updateField("scale", Number(v.toFixed(2)));
                    }
                }
            }

            // Scale Filter
            SettingRow {
                title: qsTr("Scaling Filter")
                description: qsTr("Algorithm used for fractional scaling")

                OptionPicker {
                    model: root.scaleFilterOptions
                    currentIndex: {
                        if (!root.monitor || !root.monitor.scaleFilter) return 0;
                        const idx = root.scaleFilterOptions.findIndex(o => o.val === root.monitor.scaleFilter);
                        return idx >= 0 ? idx : 0;
                    }
                    onSelected: (idx) => {
                        root.updateField("scaleFilter", root.scaleFilterOptions[idx].val);
                    }
                }
            }
        }

        // ── Section 2: Layout, Orientation & Mirroring ──────────────────────
        Section {
            title: qsTr("Layout & Position")
            icon: "crop_rotate"
            accentColor: Colours.palette.m3secondary

            // Set Primary Button
            SettingRow {
                title: qsTr("Primary Display")
                description: (root.monitor && root.monitor.x === 0 && root.monitor.y === 0)
                             ? qsTr("This monitor is at the origin (0, 0)")
                             : qsTr("Set this monitor as primary origin")

                TextButton {
                    text: (root.monitor && root.monitor.x === 0 && root.monitor.y === 0) ? qsTr("Primary ★") : qsTr("Make Primary")
                    enabled: !(root.monitor && root.monitor.x === 0 && root.monitor.y === 0)
                    onClicked: root.setAsPrimaryRequested()
                }
            }

            // Manual Position X and Y
            SettingRow {
                title: qsTr("Coordinates (X, Y)")
                description: qsTr("Logical desktop layout offset in pixels")

                RowLayout {
                    spacing: Tokens.spacing ? Tokens.spacing.large : 16

                    RowLayout {
                        spacing: 6
                        StyledText {
                            text: "X:"
                            font.weight: Font.Bold
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        CustomSpinBox {
                            value: root.monitor ? Math.round(root.monitor["x"]) : 0
                            min: 0
                            max: 30000
                            step: 10
                            onValueModified: v => root.updateField("x", v)
                        }
                    }

                    RowLayout {
                        spacing: 6
                        StyledText {
                            text: "Y:"
                            font.weight: Font.Bold
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        CustomSpinBox {
                            value: root.monitor ? Math.round(root.monitor["y"]) : 0
                            min: 0
                            max: 30000
                            step: 10
                            onValueModified: v => root.updateField("y", v)
                        }
                    }
                }
            }

            // Orientation / Rotation
            SettingRow {
                title: qsTr("Orientation")
                description: qsTr("Display rotation and transform")

                OptionPicker {
                    model: root.transformOptions
                    currentIndex: {
                        if (!root.monitor) return 0;
                        const t = root.monitor.transform || 0;
                        const idx = root.transformOptions.findIndex(o => o.val === t);
                        return idx >= 0 ? idx : 0;
                    }
                    onSelected: (idx) => {
                        root.updateField("transform", root.transformOptions[idx].val);
                    }
                }
            }

            // Mirroring
            SettingRow {
                title: qsTr("Mirror Display")
                description: qsTr("Duplicate content from another connected monitor")

                OptionPicker {
                    model: {
                        const opts = [{ label: qsTr("None (Extended)"), val: "" }];
                        if (root.allMonitors) {
                            for (let i = 0; i < root.allMonitors.length; i++) {
                                const m = root.allMonitors[i];
                                if (root.monitor && m.name !== root.monitor.name) {
                                    opts.push({ label: m.name, val: m.name });
                                }
                            }
                        }
                        return opts;
                    }
                    currentIndex: {
                        if (!root.monitor || !root.monitor.mirrorOf) return 0;
                        if (!root.allMonitors) return 0;
                        let found = 0;
                        for (let i = 0; i < root.allMonitors.length; i++) {
                            if (root.allMonitors[i].name === root.monitor.mirrorOf) {
                                found = i + 1;
                                break;
                            }
                        }
                        return found;
                    }
                    onSelected: (idx) => {
                        if (idx === 0) {
                            root.updateField("mirrorOf", "");
                        } else {
                            const opt = model[idx];
                            root.updateField("mirrorOf", opt ? opt.val : "");
                        }
                    }
                }
            }
        }

        // ── Section 3: Advanced, VRR & Identification ───────────────────────
        Section {
            title: qsTr("Advanced & Color")
            icon: "tune"
            accentColor: Colours.palette.m3tertiary

            // Variable Refresh Rate (VRR / Adaptive Sync)
            SettingRow {
                title: qsTr("Variable Refresh Rate (VRR)")
                description: qsTr("Adaptive sync / FreeSync / G-Sync mode")

                OptionPicker {
                    model: root.vrrOptions
                    currentIndex: {
                        if (!root.monitor) return 0;
                        const v = root.monitor.vrr || 0;
                        const idx = root.vrrOptions.findIndex(o => o.val === v);
                        return idx >= 0 ? idx : 0;
                    }
                    onSelected: (idx) => {
                        root.updateField("vrr", root.vrrOptions[idx].val);
                    }
                }
            }

            // Description matching
            SettingRow {
                title: qsTr("Identify by Description")
                description: qsTr("Save config using hardware description instead of port name (prevents dock swap)")

                StyledSwitch {
                    checked: root.useDescription
                    onToggled: root.useDescriptionToggled(checked)
                }
            }

            // Color Management Preset
            SettingRow {
                title: qsTr("Color Management Mode")
                description: qsTr("Hyprland experimental color profiles (cm)")

                OptionPicker {
                    model: root.colorModeOptions
                    currentIndex: {
                        if (!root.monitor || !root.monitor.colorManagementPreset) return 0;
                        const idx = root.colorModeOptions.findIndex(o => o.val === root.monitor.colorManagementPreset);
                        return idx >= 0 ? idx : 0;
                    }
                    onSelected: (idx) => {
                        root.updateField("colorManagementPreset", root.colorModeOptions[idx].val);
                    }
                }
            }

            // 10-bit color
            SettingRow {
                title: qsTr("10-Bit Color Depth")
                description: qsTr("Enable high dynamic range 10-bit buffer format (bitdepth, 10)")

                StyledSwitch {
                    checked: root.monitor ? !!root.monitor.tenBit : false
                    onToggled: root.updateField("tenBit", checked)
                }
            }

            // SDR Brightness
            SettingRow {
                title: qsTr("SDR Brightness Factor")
                description: `${root.monitor ? (root.monitor.sdrBrightness || 1.0).toFixed(2) : "1.00"}x`

                StyledSlider {
                    implicitWidth: 200
                    from: 0.2
                    to: 2.0
                    stepSize: 0.05
                    value: root.monitor ? (root.monitor.sdrBrightness || 1.0) : 1.0
                    onMoved: root.updateField("sdrBrightness", Number(value.toFixed(2)))
                }
            }

            // SDR Saturation
            SettingRow {
                title: qsTr("SDR Saturation Factor")
                description: `${root.monitor ? (root.monitor.sdrSaturation || 1.0).toFixed(2) : "1.00"}x`

                StyledSlider {
                    implicitWidth: 200
                    from: 0.0
                    to: 2.0
                    stepSize: 0.05
                    value: root.monitor ? (root.monitor.sdrSaturation || 1.0) : 1.0
                    onMoved: root.updateField("sdrSaturation", Number(value.toFixed(2)))
                }
            }
        }
    }
}
