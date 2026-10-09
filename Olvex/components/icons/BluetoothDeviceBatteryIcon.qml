import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Olvex.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    property BluetoothDevice device: null
    property string icon: Icons.getBluetoothIcon(device?.icon)
    property real battery: (device && device.batteryAvailable) ? device.battery : -1
    property bool batteryAvailable: device ? device.batteryAvailable : (battery >= 0)

    property color color: Colours.palette.m3primary
    property color trackColor: Qt.alpha(Colours.palette.m3onSurface, 0.16)
    property color lowBatteryColor: Colours.palette.m3error

    property real size: 20
    property real strokeWidth: 1.8

    readonly property bool isConnecting: device ? (device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting) : false

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    // Smooth level animation
    property real smoothLevel: batteryAvailable ? Math.max(0.0, Math.min(1.0, battery)) : 1.0
    Behavior on smoothLevel {
        NumberAnimation {
            duration: 350
            easing.type: Easing.OutCubic
        }
    }

    onSmoothLevelChanged: canvas.requestPaint()
    onBatteryAvailableChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onLowBatteryColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            if (!root.batteryAvailable) return;

            var cx = width / 2.0;
            var cy = height / 2.0;
            var r = (Math.min(width, height) - root.strokeWidth) / 2.0 - 0.4;
            // Active Progress Arc (no harsh background track outline)
            var val = Math.max(0.01, Math.min(1.0, root.smoothLevel));
            var startAngle = -Math.PI / 2.0; // 12 o'clock top
            var endAngle = startAngle + (Math.PI * 2.0 * val);

            ctx.lineWidth = root.strokeWidth;
            ctx.lineCap = "round";
            ctx.strokeStyle = (root.smoothLevel <= 0.20) ? root.lowBatteryColor : root.color;
            ctx.beginPath();
            ctx.arc(cx, cy, r, startAngle, endAngle, false);
            ctx.stroke();
        }
    }

    MaterialIcon {
        id: devIcon
        anchors.centerIn: parent
        text: root.icon
        fill: 1
        iconPointSize: Math.max(8, root.size - 8)
        color: (root.batteryAvailable && root.smoothLevel <= 0.20) ? root.lowBatteryColor : root.color
        animate: true

        SequentialAnimation on opacity {
            running: root.isConnecting
            alwaysRunToEnd: true
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.3; duration: 450; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.3; to: 1.0; duration: 450; easing.type: Easing.InOutQuad }
        }
    }
}
