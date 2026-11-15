import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Olvex
import Olvex.Config
import qs.services

Item {
    id: root

    property Session session
    property var appJoin
    property var appSplit
    property var idxOf

    property int clipboardCount: 0
    property bool clipboardRecording: true

    function refreshStatus() {
        clipCountProc.running = true;
        clipWatchProc.running = true;
    }

    Process {
        id: clipCountProc
        running: true
        command: ["bash", "-c", "cliphist list 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: root.clipboardCount = parseInt((text || "0").trim(), 10) || 0
        }
    }

    Process {
        id: clipWatchProc
        running: true
        command: ["bash", "-c", "pgrep -f 'wl-paste.*cliphist' >/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: root.clipboardRecording = (text || "").trim() === "1"
        }
    }

    Process {
        id: toggleClipProc
        onExited: root.refreshStatus()
    }

    Process {
        id: wipeClipProc
        command: ["cliphist", "wipe"]
        onExited: (exitCode) => {
            if (exitCode === 0 && typeof Toaster !== "undefined" && Toaster.toast)
                Toaster.toast(qsTr("Clipboard history cleared"), "", "delete_sweep");
            root.refreshStatus();
        }
    }

    Process {
        id: clearThumbsProc
        command: ["bash", "-c", "rm -rf ~/.cache/thumbnails/*"]
        onExited: {
            if (typeof Toaster !== "undefined" && Toaster.toast)
                Toaster.toast(qsTr("Thumbnail cache cleared"), "", "cleaning_services");
        }
    }

    Process {
        id: emptyTrashProc
        command: ["bash", "-c", "command -v trash-empty >/dev/null 2>&1 && trash-empty || rm -rf ~/.local/share/Trash/files/* ~/.local/share/Trash/info/*"]
        onExited: {
            if (typeof Toaster !== "undefined" && Toaster.toast)
                Toaster.toast(qsTr("Trash emptied"), "", "delete_forever");
        }
    }

    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()

    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.normal || 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.normal || 300; easing.type: Easing.OutCubic }
    }

    implicitHeight: (col ? col.implicitHeight : 0) + Tokens.padding.large * 2

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        spacing: Tokens.spacing.large

        Section {
            Layout.fillWidth: true
            title: qsTr("Clipboard History")
            description: qsTr("Control background clipboard recording and stored entries")
            icon: "content_paste"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Record clipboard history")
                description: qsTr("Watch text and images copied to clipboard via wl-paste + cliphist")
                StyledSwitch {
                    checked: root.clipboardRecording
                    onToggled: {
                        if (checked) {
                            toggleClipProc.command = ["bash", "-c", "nohup wl-paste --type text --watch cliphist store >/dev/null 2>&1 & nohup wl-paste --type image --watch cliphist store >/dev/null 2>&1 &"];
                        } else {
                            toggleClipProc.command = ["bash", "-c", "pkill -f 'wl-paste.*cliphist' || true"];
                        }
                        toggleClipProc.running = true;
                    }
                }
            }

            SettingRow {
                title: qsTr("Clear clipboard history")
                description: qsTr("%1 saved entries in cliphist database").arg(root.clipboardCount)
                TextButton {
                    text: qsTr("Clear all")
                    type: TextButton.Tonal
                    onClicked: wipeClipProc.running = true
                }
            }
        }

        Section {
            Layout.fillWidth: true
            title: qsTr("Privacy & Cleanup")
            description: qsTr("Remove cached previews and deleted files")
            icon: "shield"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Clear thumbnail cache")
                description: qsTr("Remove generated file previews from ~/.cache/thumbnails")
                TextButton {
                    text: qsTr("Clear")
                    type: TextButton.Tonal
                    onClicked: clearThumbsProc.running = true
                }
            }

            SettingRow {
                title: qsTr("Empty trash")
                description: qsTr("Permanently remove all items in system trash")
                TextButton {
                    text: qsTr("Empty")
                    type: TextButton.Tonal
                    onClicked: emptyTrashProc.running = true
                }
            }
        }
    }
}

