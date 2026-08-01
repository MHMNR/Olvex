pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property string providerName: ""
    property string installPackage: ""
    property string installCommand: ""

    function detectInstallHint(): void {
        detectPkgManagerProc.running = true;
    }

    function detectAvailability(): bool {
        try {
            const testObject = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                Item {}
            `, root, "MultimediaService.Test");
            if (testObject)
                testObject.destroy();
            available = true;
            return true;
        } catch (e) {
            available = false;
            return false;
        }
    }

    Component.onCompleted: {
        detectInstallHint();
        if (!detectAvailability())
            console.warn("MultimediaService: QtMultimedia not available");
    }

    Process {
        id: detectPkgManagerProc

        command: ["bash", "-lc", "if command -v pacman >/dev/null 2>&1; then echo pacman; elif command -v apt >/dev/null 2>&1; then echo apt; elif command -v dnf >/dev/null 2>&1; then echo dnf; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const manager = text.trim();
                if (manager === "pacman") {
                    root.providerName = "QtMultimedia";
                    root.installPackage = "qt6-multimedia";
                    root.installCommand = "sudo pacman -S qt6-multimedia";
                } else if (manager === "apt") {
                    root.providerName = "QtMultimedia";
                    root.installPackage = "qml6-module-qtmultimedia";
                    root.installCommand = "sudo apt install qml6-module-qtmultimedia";
                } else if (manager === "dnf") {
                    root.providerName = "QtMultimedia";
                    root.installPackage = "qt6-qtmultimedia";
                    root.installCommand = "sudo dnf install qt6-qtmultimedia";
                }
            }
        }
    }
}
