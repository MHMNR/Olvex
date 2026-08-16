import QtQuick
import Quickshell
import Olvex
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    readonly property int spacing: 8
    property bool flag

    function shouldShowToast(toast: Toast): bool {
        if (!Notifs.hasFullscreen())
            return true;
        if (Config.qspanel.toasts.fullscreen === "all")
            return true;
        if (Config.qspanel.toasts.fullscreen === "important")
            return toast.type === Toast.Warning || toast.type === Toast.Error;
        return false;
    }

    implicitWidth: 380
    implicitHeight: {
        let h = -spacing;
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i) as ToastWrapper;
            if (item && !item.modelData.closed && !item.previewHidden)
                h += item.implicitHeight + spacing;
        }
        return Math.max(0, h);
    }
    width: implicitWidth
    height: implicitHeight
    visible: implicitHeight > 0

    Repeater {
        id: repeater

        model: ScriptModel {
            values: {
                const toasts = [];
                let count = 0;
                for (const toast of Toaster.toasts) {
                    if (!root.shouldShowToast(toast))
                        continue;
                    toasts.push(toast);
                    if (!toast.closed) {
                        count++;
                        if (count > root.Config.qspanel.maxToasts)
                            break;
                    }
                }
                return toasts;
            }
            onValuesChanged: root.flagChanged()
        }

        ToastWrapper {}
    }

    component ToastWrapper: Item {
        id: toast

        required property int index
        required property Toast modelData

        readonly property bool previewHidden: {
            let extraHidden = 0;
            for (let i = 0; i < index; i++)
                if (Toaster.toasts[i].closed)
                    extraHidden++;
            return index >= Config.qspanel.maxToasts + extraHidden;
        }

        // Animated entrance/exit properties
        property real offsetY: 16
        property real toastOpacity: 0
        property real toastScale: 0.94

        opacity: toastOpacity
        scale: toastScale
        transform: Translate {
            y: toast.offsetY
        }

        // Hardware texture smoothing during motion to prevent text jitter
        layer.enabled: enterAnim.running || exitAnim.running
        layer.smooth: true

        anchors.bottomMargin: {
            root.flag; // Force update
            let y = 0;
            for (let i = 0; i < index; i++) {
                const item = repeater.itemAt(i) as ToastWrapper;
                if (item && !item.modelData.closed && !item.previewHidden)
                    y += item.implicitHeight + root.spacing;
            }
            return y;
        }

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: toastInner.implicitWidth
        implicitHeight: toastInner.implicitHeight
        height: implicitHeight

        Component.onCompleted: {
            modelData.lock(this);
            enterAnim.start();
        }

        // M3 Emphasized Decelerate Spline: [0.05, 0.7, 0.1, 1.0]
        readonly property var m3Decel: [0.05, 0.7, 0.1, 1.0, 1, 1]

        ParallelAnimation {
            id: enterAnim

            NumberAnimation {
                target: toast
                property: "toastOpacity"
                from: 0
                to: 1
                duration: 320
                easing.type: Easing.BezierSpline
                easing.bezierCurve: toast.m3Decel
            }

            NumberAnimation {
                target: toast
                property: "offsetY"
                from: 16
                to: 0
                duration: 340
                easing.type: Easing.BezierSpline
                easing.bezierCurve: toast.m3Decel
            }

            NumberAnimation {
                target: toast
                property: "toastScale"
                from: 0.94
                to: 1.0
                duration: 340
                easing.type: Easing.BezierSpline
                easing.bezierCurve: toast.m3Decel
            }
        }

        ParallelAnimation {
            id: exitAnim
            running: toast.modelData.closed
            onStarted: toast.anchors.bottomMargin = toast.anchors.bottomMargin
            onFinished: toast.modelData.unlock(toast)

            NumberAnimation {
                target: toast
                property: "toastOpacity"
                to: 0
                duration: 180
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: toast
                property: "toastScale"
                to: 0.92
                duration: 180
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: toast
                property: "offsetY"
                to: 10
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        ToastItem {
            id: toastInner
            modelData: toast.modelData
        }

        Behavior on anchors.bottomMargin {
            Anim {
                type: Anim.Emphasized
            }
        }
    }
}
