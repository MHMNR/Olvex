
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config

Item {
    id: root
    
    property Session session
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.large; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.large; easing.type: Easing.OutCubic }
    }

    readonly property var logoOptions: [
        { label: qsTr("Auto (Detected Distro)"), value: "", category: "distros" },
        { label: qsTr("Olvex Logo"), value: "olvex", category: "distros" },

        // Linux Distributions
        { label: qsTr("Arch Linux"), value: "arch", category: "distros" },
        { label: qsTr("NixOS"), value: "nixos", category: "distros" },
        { label: qsTr("Fedora"), value: "fedora", category: "distros" },
        { label: qsTr("Debian"), value: "debian", category: "distros" },
        { label: qsTr("Ubuntu"), value: "ubuntu", category: "distros" },
        { label: qsTr("Void Linux"), value: "void", category: "distros" },
        { label: qsTr("Alpine Linux"), value: "alpine", category: "distros" },
        { label: qsTr("Gentoo"), value: "gentoo", category: "distros" },
        { label: qsTr("openSUSE"), value: "opensuse", category: "distros" },
        { label: qsTr("Manjaro"), value: "manjaro", category: "distros" },
        { label: qsTr("Pop!_OS"), value: "pop", category: "distros" },
        { label: qsTr("Linux Mint"), value: "mint", category: "distros" },
        { label: qsTr("EndeavourOS"), value: "endeavouros", category: "distros" },
        { label: qsTr("CachyOS"), value: "cachyos", category: "distros" },
        { label: qsTr("Archcraft"), value: "archcraft", category: "distros" },
        { label: qsTr("Garuda Linux"), value: "garuda", category: "distros" },
        { label: qsTr("Artix Linux"), value: "artix", category: "distros" },
        { label: qsTr("Kali Linux"), value: "kali", category: "distros" },
        { label: qsTr("Elementary OS"), value: "elementary", category: "distros" },
        { label: qsTr("Zorin OS"), value: "zorin", category: "distros" },
        { label: qsTr("Red Hat / RHEL"), value: "rhel", category: "distros" },
        { label: qsTr("CentOS"), value: "centos", category: "distros" },
        { label: qsTr("Rocky Linux"), value: "rocky", category: "distros" },
        { label: qsTr("AlmaLinux"), value: "almalinux", category: "distros" },
        { label: qsTr("Nobara Linux"), value: "nobara", category: "distros" },
        { label: qsTr("Raspberry Pi OS"), value: "raspberry", category: "distros" },
        { label: qsTr("Slackware"), value: "slackware", category: "distros" },
        { label: qsTr("Solus"), value: "solus", category: "distros" },
        { label: qsTr("Mageia"), value: "mageia", category: "distros" },
        { label: qsTr("FreeBSD / OpenBSD"), value: "freebsd", category: "distros" },
        { label: qsTr("Generic Linux (Tux)"), value: "linux", category: "distros" },

        // Operating Systems
        { label: qsTr("Apple (macOS)"), value: "apple", category: "os" },
        { label: qsTr("Microsoft Windows"), value: "windows", category: "os" },
        { label: qsTr("Android"), value: "android", category: "os" },

        // Tech, Tools & Developer
        { label: qsTr("Hyprland"), value: "hyprland", category: "tools" },
        { label: qsTr("Wayland"), value: "wayland", category: "tools" },
        { label: qsTr("Terminal"), value: "terminal", category: "tools" },
        { label: qsTr("Code / Dev"), value: "code", category: "tools" },
        { label: qsTr("Git"), value: "git", category: "tools" },
        { label: qsTr("GitHub"), value: "github", category: "tools" },
        { label: qsTr("Docker"), value: "docker", category: "tools" },
        { label: qsTr("Neovim"), value: "neovim", category: "tools" },
        { label: qsTr("Rust"), value: "rust", category: "tools" },
        { label: qsTr("Python"), value: "python", category: "tools" },
        { label: qsTr("Flathub"), value: "flathub", category: "tools" },
        { label: qsTr("Qt"), value: "qt", category: "tools" },

        // Community & Icons
        { label: qsTr("Rocket"), value: "rocket", category: "icons" },
        { label: qsTr("Flame / Fire"), value: "fire", category: "icons" },
        { label: qsTr("Sparkles / Magic"), value: "sparkles", category: "icons" },
        { label: qsTr("Lightning"), value: "lightning", category: "icons" },
        { label: qsTr("Heart"), value: "heart", category: "icons" },
        { label: qsTr("Star"), value: "star", category: "icons" },
        { label: qsTr("Coffee Cup"), value: "coffee", category: "icons" },
        { label: qsTr("Diamond"), value: "diamond", category: "icons" },
        { label: qsTr("Ghost"), value: "ghost", category: "icons" },
        { label: qsTr("Music Note"), value: "music", category: "icons" },
        { label: qsTr("Gamepad"), value: "gamepad", category: "icons" }
    ]

    implicitHeight: (col ? col.implicitHeight : 0) + Tokens.padding.large * 2
    
    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        spacing: 0

        SettingRow {
            title: qsTr("Enable launcher")
            description: qsTr("Allow opening the app launcher")
            divider: true
            StyledSwitch {
                checked: Config.launcher.enabled ?? true
                onToggled: {
                    GlobalConfig.launcher.enabled = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Enable dangerous actions")
            description: qsTr("Allow shutdown / reboot from search")
            divider: true
            StyledSwitch {
                checked: GlobalConfig.launcher.enableDangerousActions ?? true
                onToggled: {
                    GlobalConfig.launcher.enableDangerousActions = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Launcher button logo")
            description: qsTr("Select active distro icon or brand mark")
            divider: false
            PickerGrid {
                id: logoPickerGrid
                model: root.logoOptions
                currentIndex: {
                    const cur = (GlobalConfig.general.logo || "").trim().toLowerCase();
                    for (let i = 0; i < root.logoOptions.length; i++) {
                        if (root.logoOptions[i].value === cur)
                            return i;
                    }
                    return 0;
                }
                onSelected: index => {
                    if (index >= 0 && index < root.logoOptions.length) {
                        GlobalConfig.general.logo = root.logoOptions[index].value;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
