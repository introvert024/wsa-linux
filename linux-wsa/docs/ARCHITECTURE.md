# Technical Architecture: WSA on Linux (LSA)

## Overview

Windows Subsystem for Android (WSA) on Windows operates as a microVM managed by Microsoft Hyper-V and orchestrated by `WsaClient.exe` / `WsaService.exe`. Underneath, WSA is built on the Linux kernel and Android Open Source Project (AOSP), specifically Android 12.1 (API 32) in version `2210.40000.7.0`.

This project ports the WSA architecture to Linux (specifically Fedora and Ubuntu) by replacing the proprietary Windows Hyper-V and UWP stack with high-performance Linux native equivalents:

| Windows WSA Component | Linux WSA Equivalent | Technology / Function |
| :--- | :--- | :--- |
| **Hyper-V MicroVM** | **KVM (Kernel-based Virtual Machine)** | Hardware virtualization with near-native CPU speed |
| **DirectX / D3D12 vGPU** | **VirtIO-GPU with VirGL / Venus** | 3D hardware-accelerated OpenGL / Vulkan |
| **WsaClient.exe / WsaService** | **`wsa-client` & `wsa-runner`** | Process lifecycle, ADB bridge, daemon management |
| **Windows Audio Service** | **PipeWire / PulseAudio** | Low-latency host audio routing via HDA / VirtIO-Snd |
| **Windows AppX Packaging** | **Fedora RPM / Ubuntu DEB** | Native Linux package managers (`dnf`, `apt`) |
| **Start Menu Tiles** | **XDG `.desktop` entries** | Seamless GNOME / KDE / XFCE application menu entries |
| **`wsa://` URI Protocol** | **XDG MIME URI Handler** | Protocol handler via `wsa-uri-handler.desktop` |
| **Folder Sharing** | **VirtIO-9P / VirtIO-FS** | Real-time folder sync between `~/AndroidShare` & Android |

---

## Disk Image Layout & Mounting

WSA 2210.40000.7.0 uses multiple raw and ext4/erofs disk images:

1. **`system.img`**: Core Android 12.1 runtime and framework (mounted read-only).
2. **`vendor.img`**: Hardware abstraction layers (HALs) and VirtIO device drivers (mounted read-only).
3. **`product.img`** & **`system_ext.img`**: System extensions, bundled apps, and Google services.
4. **`userdata.img`**: Persistent user data, installed apps, and app data (mounted read-write). Automatically created as a sparse ext4 filesystem.
5. **`Tools/kernel`**: Linux 5.10 / 5.15 x86_64 kernel tailored with Android Ashmem, Binder, and VirtIO device support.
6. **`Tools/initrd.img`**: Initial ramdisk patched with Magisk root (`lspinit`, `magiskinit`) and MindTheGapps overlays.

---

## App Sideloading & Windowing

### Sideloading (`wsa-client install`)
When an APK is installed via `wsa-client install app.apk`:
1. Subsystem boots automatically in background if not already active.
2. APK is pushed and installed via ADB: `adb install -r app.apk`.
3. App activity names and icons are inspected.
4. A standard `.desktop` file is generated in `~/.local/share/applications/wsa-<pkg>.desktop`.

### Launching (`wsa-app`)
When clicking an app icon or invoking `wsa-app <pkg>`:
1. Subsystem auto-boots.
2. App launcher intent is dispatched: `adb shell monkey -p <pkg> -c android.intent.category.LAUNCHER 1`.
3. The app opens directly inside the hardware-accelerated display.
