import os
import re
import shutil
import subprocess
from pathlib import Path

from olvex.utils.dots.packages import PackageError, PackageInstaller
from olvex.utils.io import info, log, warn


def _safe_cmd_output(cmd: list[str]) -> str:
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def _is_multilib_enabled() -> bool:
    """Check if multilib repo is enabled in pacman.conf."""
    pacman_conf = Path("/etc/pacman.conf")
    if not pacman_conf.exists():
        return False
    try:
        content = pacman_conf.read_text()
        return bool(re.search(r"^\s*\[multilib\]", content, re.MULTILINE))
    except Exception:
        return False


def _detect_installed_kernel_headers() -> list[str]:
    """Detect installed kernel packages and return corresponding -headers packages."""
    headers: list[str] = []
    pacman_q = _safe_cmd_output(["pacman", "-Qq"])
    installed_pkgs = set(pacman_q.splitlines())

    known_kernels = [
        "linux",
        "linux-lts",
        "linux-zen",
        "linux-hardened",
        "linux-cachyos",
        "linux-cachyos-lts",
        "linux-cachyos-bore",
        "linux-xanmod",
        "linux-liquorix",
    ]

    for kern in known_kernels:
        if kern in installed_pkgs:
            header_pkg = f"{kern}-headers"
            headers.append(header_pkg)

    return headers


def _detect_kernel_bundled_nvidia() -> list[str]:
    """Detect custom kernels that bundle NVIDIA kernel modules (e.g. linux-cachyos-nvidia), excluding firmware."""
    pacman_q = _safe_cmd_output(["pacman", "-Qq"])
    return [
        pkg
        for pkg in pacman_q.splitlines()
        if re.match(r"^linux-(?!firmware).*nvidia", pkg)
    ]


class DriverDetector:
    """Probes system hardware and returns recommended driver packages."""

    def __init__(self) -> None:
        self.lspci = _safe_cmd_output(["lspci", "-nnk"])
        self.lscpu = _safe_cmd_output(["lscpu"])
        self.lsusb = _safe_cmd_output(["lsusb"])
        self.virt = _safe_cmd_output(["systemd-detect-virt"]).strip().lower()
        self.multilib = _is_multilib_enabled()

    def detect_all(self) -> tuple[list[str], list[str]]:
        """Returns (packages_to_install, detected_hardware_descriptions)."""
        packages: list[str] = []
        descriptions: list[str] = []

        # 1. GPU Detection
        gpu_pkgs, gpu_desc = self.detect_gpu()
        packages.extend(gpu_pkgs)
        descriptions.extend(gpu_desc)

        # 2. CPU Microcode
        cpu_pkgs, cpu_desc = self.detect_cpu()
        packages.extend(cpu_pkgs)
        descriptions.extend(cpu_desc)

        # 3. Audio & Sound System
        audio_pkgs, audio_desc = self.detect_audio()
        packages.extend(audio_pkgs)
        descriptions.extend(audio_desc)

        # 4. Bluetooth
        bt_pkgs, bt_desc = self.detect_bluetooth()
        packages.extend(bt_pkgs)
        descriptions.extend(bt_desc)

        # 5. Virtualization Guest
        virt_pkgs, virt_desc = self.detect_virtualization()
        packages.extend(virt_pkgs)
        descriptions.extend(virt_desc)

        # Deduplicate while preserving order
        deduped_pkgs: list[str] = []
        seen = set()
        for pkg in packages:
            if pkg and pkg not in seen:
                seen.add(pkg)
                deduped_pkgs.append(pkg)

        return deduped_pkgs, descriptions

    def detect_gpu(self) -> tuple[list[str], list[str]]:
        pkgs: list[str] = []
        desc: list[str] = []

        gpu_lines = [
            line.strip()
            for line in self.lspci.splitlines()
            if any(tok in line.lower() for tok in ("vga compatible controller", "3d controller", "display controller"))
        ]
        gpu_text = "\n".join(gpu_lines)

        # NVIDIA GPU
        if "NVIDIA" in gpu_text:
            bundled_nvidia = _detect_kernel_bundled_nvidia()
            if bundled_nvidia:
                desc.append(f"NVIDIA GPU (Kernel-bundled module: {', '.join(bundled_nvidia)})")
                pkgs.extend(["nvidia-utils", "nvidia-settings", "libva-nvidia-driver"])
            else:
                desc.append("NVIDIA GPU (Open Kernel / DKMS)")
                headers = _detect_installed_kernel_headers()
                if headers:
                    pkgs.extend(headers)
                    pkgs.extend(["nvidia-open-dkms", "dkms", "nvidia-utils", "nvidia-settings", "libva-nvidia-driver"])
                else:
                    pkgs.extend(["nvidia-open", "nvidia-utils", "nvidia-settings", "libva-nvidia-driver"])

            if self.multilib:
                pkgs.append("lib32-nvidia-utils")

        # AMD / Radeon GPU (archinstall GfxDriver.AmdOpenSource)
        if any(tok in gpu_text for tok in ("AMD", "Advanced Micro Devices", "Radeon")):
            desc.append("AMD/Radeon GPU")
            pkgs.extend(["mesa", "xf86-video-amdgpu", "xf86-video-ati", "vulkan-radeon"])
            if self.multilib:
                pkgs.append("lib32-vulkan-radeon")

        # Intel GPU (archinstall GfxDriver.IntelOpenSource)
        if "Intel" in gpu_text:
            desc.append("Intel GPU")
            pkgs.extend(["mesa", "libva-intel-driver", "intel-media-driver", "vpl-gpu-rt", "libvpl", "vulkan-intel"])
            if self.multilib:
                pkgs.append("lib32-vulkan-intel")

        return pkgs, desc

    def detect_cpu(self) -> tuple[list[str], list[str]]:
        pkgs: list[str] = []
        desc: list[str] = []

        if "GenuineIntel" in self.lscpu or "Vendor ID: Intel" in self.lscpu:
            desc.append("Intel CPU (intel-ucode)")
            pkgs.append("intel-ucode")
        elif "AuthenticAMD" in self.lscpu or "Vendor ID: AMD" in self.lscpu:
            desc.append("AMD CPU (amd-ucode)")
            pkgs.append("amd-ucode")

        return pkgs, desc

    def detect_audio(self) -> tuple[list[str], list[str]]:
        # Matches official archinstall AudioApp.pipewire_packages
        desc = ["PipeWire Audio Stack"]
        pkgs = [
            "pipewire",
            "pipewire-alsa",
            "pipewire-jack",
            "pipewire-pulse",
            "pipewire-audio",
            "gst-plugin-pipewire",
            "libpulse",
            "wireplumber",
        ]

        # Check for Intel SOF / ALSA DSP firmware
        if "sof-audio" in self.lspci.lower() or "snd_sof" in _safe_cmd_output(["lsmod"]):
            pkgs.append("sof-firmware")
            desc.append("Sound Open Firmware (sof-firmware)")

        return pkgs, desc

    def detect_bluetooth(self) -> tuple[list[str], list[str]]:
        # Matches official archinstall BluetoothApp
        pkgs: list[str] = []
        desc: list[str] = []

        has_bt = (
            "bluetooth" in self.lspci.lower()
            or "bluetooth" in self.lsusb.lower()
            or bool(_safe_cmd_output(["rfkill", "list", "bluetooth"]).strip())
        )

        if has_bt:
            desc.append("Bluetooth Controller")
            pkgs.extend(["bluez", "bluez-utils", "pipewire-audio"])

        return pkgs, desc

    def detect_virtualization(self) -> tuple[list[str], list[str]]:
        # Matches official archinstall GfxDriver.VMOpenSource & guest tools
        pkgs: list[str] = []
        desc: list[str] = []

        if self.virt and self.virt != "none":
            if "kvm" in self.virt or "qemu" in self.virt:
                desc.append(f"Virtual Machine ({self.virt})")
                pkgs.extend(["mesa", "qemu-guest-agent"])
            elif "oracle" in self.virt or "vbox" in self.virt:
                desc.append("VirtualBox VM")
                pkgs.extend(["mesa", "virtualbox-guest-utils"])
            elif "vmware" in self.virt:
                desc.append("VMware VM")
                pkgs.extend(["mesa", "open-vm-tools"])

        return pkgs, desc


class DriverInstaller:
    """Coordinates hardware detection, package installation, and post-configuration."""

    @staticmethod
    def install(installer: PackageInstaller) -> list[str]:
        if shutil.which("pacman") is None:
            info("Skipping driver installation (not on Arch Linux).")
            return []

        detector = DriverDetector()
        packages, descriptions = detector.detect_all()

        if not packages:
            info("No additional hardware drivers required.")
            return []

        print()
        log("Detected Hardware:")
        for d in descriptions:
            info(f"  • {d}")

        print()
        log(f"Installing driver packages: {', '.join(packages)}")
        try:
            installer.install(packages)
        except PackageError as e:
            warn(f"Some driver packages could not be installed: {e}")

        # Post-install actions
        DriverInstaller.post_install(packages)
        return packages

    @staticmethod
    def post_install(packages: list[str]) -> None:
        # 1. DKMS autoinstall if dkms drivers were installed
        if any("dkms" in pkg for pkg in packages) and shutil.which("dkms"):
            print()
            log("Rebuilding DKMS modules for installed kernels...")
            try:
                subprocess.run(["sudo", "dkms", "autoinstall"], check=False)
            except Exception as e:
                warn(f"DKMS rebuild warning: {e}")

        # 2. Live NVIDIA module loading
        if any("nvidia" in pkg for pkg in packages) and shutil.which("modprobe"):
            try:
                subprocess.run(
                    ["sudo", "modprobe", "nvidia", "nvidia_modeset", "nvidia_uvm", "nvidia_drm"],
                    stderr=subprocess.DEVNULL,
                    stdout=subprocess.DEVNULL,
                    check=False,
                )
            except Exception:
                pass
