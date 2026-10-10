import QtQuick
import M3Shapes

MaterialShape {
    id: root

    property list<int> shapes: [MaterialShape.SoftBurst, MaterialShape.Cookie9Sided, MaterialShape.Pentagon, MaterialShape.Pill, MaterialShape.Sunny, MaterialShape.Cookie4Sided, MaterialShape.Oval]
    property int shapeIndex
    property real cRotation
    property real lRotation
    property real thisLRotation

    property bool animated: true
    property int morphAnimRotation: 60
    property real morphScale: 0.14
    property int rotateAnimDuration: 4666

    property real stiffness: 180
    property real dampingRatio: 0.6
    property real visibilityThreshold: 0.075

    readonly property real springDuration: {
        const wn = Math.sqrt(stiffness);
        const r = -dampingRatio * wn;
        const c = 1 / Math.sqrt(1 - dampingRatio * dampingRatio);
        return Math.log(visibilityThreshold / c) / r;
    }
    readonly property real springMaxVelocity: {
        const wn = Math.sqrt(stiffness);
        const z = dampingRatio;
        const factor = Math.exp(-z * Math.acos(z) / Math.sqrt(1 - z * z));
        return wn * factor;
    }
    property bool springSettled: true
    property real startTime: 0

    function spring(t) {
        const wn = Math.sqrt(stiffness);
        const za = dampingRatio * wn;

        const wd = wn * Math.sqrt(1 - dampingRatio * dampingRatio);
        const r = za / wd;
        const pos = 1 - Math.exp(-za * t) * (Math.cos(wd * t) + r * Math.sin(wd * t));
        const vel = Math.exp(-za * t) * (wn * wn / wd) * Math.sin(wd * t);

        return [pos, vel];
    }

    implicitSize: 38
    toShape: shapes[0]

    FrameAnimation {
        running: root.animated && !root.springSettled
        onTriggered: {
            if (root.startTime === 0) root.startTime = Date.now();
            const t = (Date.now() - root.startTime) / 1000.0;

            if (t >= root.springDuration) {
                root.springSettled = true;
            } else {
                const arr = root.spring(t);
                const pos = arr[0];
                const vel = arr[1];
                root.morphProgress = Math.min(1, pos);
                root.thisLRotation = pos * root.morphAnimRotation;
                root.scale = 1 + vel * root.morphScale / root.springMaxVelocity;
            }
        }
    }

    Timer {
        interval: 650
        repeat: true
        triggeredOnStart: true
        running: root.animated
        onTriggered: {
            root.beginBatchUpdate();
            root.fromShape = root.toShape;
            root.shapeIndex = (root.shapeIndex + 1) % root.shapes.length;
            root.toShape = root.shapes[root.shapeIndex];
            root.morphProgress = 0;

            root.rotation = root.rotation;
            root.lRotation = (root.lRotation + root.thisLRotation) % 360;
            root.thisLRotation = 0;
            root.rotation = Qt.binding(() => root.cRotation + root.lRotation + root.thisLRotation);

            root.springSettled = false;
            root.startTime = 0; // restart custom timer
            root.endBatchUpdate();
        }
    }

    RotationAnimation on cRotation {
        id: rotateAnim
        running: root.animated
        from: 0
        to: 360
        easing.type: Easing.Linear
        loops: Animation.Infinite
        duration: root.rotateAnimDuration
    }

    Behavior on color {
        ColorAnimation { duration: 250 }
    }
}
