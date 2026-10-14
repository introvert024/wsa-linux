# Windows Subsystem for Android (WSA) on Linux
### Full Conversion of MustardChef/WSABuilds (`WSA_2210.40000.7.0_x86_64_Windows10`) for Fedora & Ubuntu

This repository provides the complete Linux port of the **MustardChef/WSABuilds** project and the **WSA 2210.40000.7.0 (x86_64)** build. It enables running Windows Subsystem for Android natively on Linux with near-native CPU speed via KVM, 3D graphics acceleration via VirGL, Google Play Store (MindTheGapps), Magisk root, and seamless desktop application integration.

---

## 🌟 Key Features

* **Tailored for Fedora & Ubuntu (mostly Fedora)**: First-class native package support via `dnf`/`dnf5` and `apt`.
* **Hardware Accelerated (KVM + VirGL)**: Direct CPU hardware virtualization via KVM; 3D OpenGL/Vulkan acceleration via VirGL VirtIO-GPU.
* **Google Play Store & Magisk**: Full integration of Google Play Store (MindTheGapps) and Magisk root solution on Android 12.1.
* **Seamless Desktop Integration**:
  * Automatically creates `.desktop` menu shortcuts for all installed Android apps.
  * Handles `wsa://` URI links (e.g. `wsa://com.android.vending` launches Google Play Store).
  * Automatically auto-boots the Android subsystem on demand when an app is launched.
* **PipeWire & PulseAudio**: Low-latency audio forwarding from Android directly to the Linux host.
* **Shared Folder Support**: Real-time two-way folder synchronization between `~/AndroidShare` and `/sdcard/Windows`.
* **Universal Conversion Engine**: Tooling to convert any Windows WSA release or raw WSA archive into a native Linux distribution.

---

## 📂 Repository Structure

```
d:/wsa for linux/
├── WSABuilds/               # Upstream WSABuilds repository with Linux-adapted scripts
│   ├── MagiskOnWSA/         # Core build toolchain
│   │   ├── scripts/         # install_deps.sh & build.sh with native Fedora & Ubuntu support
│   │   └── libhoudini/      # ARM translation layer installer
│   └── WSABuilds Utilities/ # Cross-platform uninstaller & updater
│
└── linux-wsa/               # Linux Subsystem for Android (LSA) Engine & Tooling
    ├── bin/
    │   ├── wsa-runner.sh    # QEMU-KVM hardware virtualization & VirtIO runner
    │   ├── wsa-client       # Command-line control interface (start, stop, adb, install)
    │   ├── wsa-app          # Application launcher & wsa:// URI protocol handler
    │   ├── wsa-sync-apps    # Generates Linux desktop menu entries for Android apps
    │   ├── wsa-settings     # GUI & TUI hardware configuration manager
    │   └── wsa-uninstaller  # Clean uninstaller for Linux
    ├── installer/
    │   └── install.sh       # Automated installer for Fedora (dnf) & Ubuntu (apt)
    ├── converter/
    │   ├── convert_wsa_build.py # Automated converter for WSA_2210.40000.7.0_x86_64_Windows10
    │   └── convert_wsa_build.sh # Quick bash wrapper for conversion
    ├── packaging/
    │   ├── fedora/          # wsa-linux.spec for building native Fedora RPMs
    │   └── ubuntu/          # debian/ packaging files for building Ubuntu .deb packages
    ├── systemd/
    │   └── wsa-linux.service# Systemd user daemon unit
    └── docs/
        ├── FEDORA_GUIDE.md  # Detailed setup guide for Fedora Linux
        ├── UBUNTU_GUIDE.md  # Detailed setup guide for Ubuntu Linux
        └── ARCHITECTURE.md  # Deep dive into the virtualization architecture
```

---

## 📦 Direct Downloads & Prebuilt Packages

Prebuilt releases and installers are published on GitHub:
👉 **[GitHub Releases v2210.40000.7.0](https://github.com/introvert024/wsa-linux/releases/tag/v2210.40000.7.0)**

| Package | Target OS | Direct Download Link | Installation Command |
| :--- | :--- | :--- | :--- |
| **Debian / Ubuntu Package** | Ubuntu 20.04 - 24.10, Debian | [Download `.deb`](https://github.com/introvert024/wsa-linux/releases/download/v2210.40000.7.0/wsa-linux_2210.40000.7.0_amd64.deb) | `sudo apt-get install -y ./wsa-linux_2210.40000.7.0_amd64.deb` |
| **Fedora Package Bundle** | Fedora 38, 39, 40, 41, Rawhide | [Download Fedora Bundle](https://github.com/introvert024/wsa-linux/releases/download/v2210.40000.7.0/wsa-linux-2210.40000.7.0-fedora.tar.gz) | `tar -xzf wsa-linux-*-fedora.tar.gz && sudo ./installer/install.sh` |
| **Universal Installer** | All Linux Distributions | [Download Universal Archive](https://github.com/introvert024/wsa-linux/releases/download/v2210.40000.7.0/wsa-linux-2210.40000.7.0-universal.tar.gz) | `tar -xzf wsa-linux-*-universal.tar.gz && sudo ./installer/install.sh` |

---

## 🚀 Quick Start Guide

### 1. Direct Install on Fedora
```bash
wget https://github.com/introvert024/wsa-linux/releases/download/v2210.40000.7.0/wsa-linux-2210.40000.7.0-fedora.tar.gz
tar -xzf wsa-linux-2210.40000.7.0-fedora.tar.gz
sudo ./installer/install.sh
```
*(Or build native RPM package: `rpmbuild -ba packaging/fedora/wsa-linux.spec`)*

### 2. Direct Install on Ubuntu
```bash
wget https://github.com/introvert024/wsa-linux/releases/download/v2210.40000.7.0/wsa-linux_2210.40000.7.0_amd64.deb
sudo apt-get update && sudo apt-get install -y ./wsa-linux_2210.40000.7.0_amd64.deb
```

### 3. Converting `WSA_2210.40000.7.0_x86_64_Windows10` (From Source Archive)
To convert a raw Windows 10 WSA 2210.40000.7.0 build archive or directory:
```bash
cd linux-wsa/converter
./convert_wsa_build.sh /path/to/WSA_2210.40000.7.0_x86_64_Windows10.7z -o ./output --distro fedora
```

---

## 🎮 Essential Commands

| Command | Action |
| :--- | :--- |
| `wsa-client start` | Launch the WSA Android subsystem |
| `wsa-client start --daemon` | Start WSA in background mode |
| `wsa-client stop` | Gracefully shut down Android subsystem |
| `wsa-client status` | Show runtime, boot status, and Android version |
| `wsa-client play` | Open Google Play Store |
| `wsa-client magisk` | Open Magisk Manager (Root) |
| `wsa-client install app.apk` | Sideload an APK and create desktop shortcut |
| `wsa-client sync-apps` | Refresh desktop application menu entries |
| `wsa-settings` | Open the graphical configuration manager |
| `wsa-client shell` | Open ADB root shell |

---

## 📖 Detailed Guides
* [Fedora Installation & Usage Guide](file:///d:/wsa%20for%20linux/linux-wsa/docs/FEDORA_GUIDE.md)
* [Ubuntu Installation & Usage Guide](file:///d:/wsa%20for%20linux/linux-wsa/docs/UBUNTU_GUIDE.md)
* [Architecture Documentation](file:///d:/wsa%20for%20linux/linux-wsa/docs/ARCHITECTURE.md)
