# Running Windows Subsystem for Android (WSA) on Fedora Linux

This guide details how to install, convert, and run **WSA (Windows Subsystem for Android) 2210.40000.7.0 (x86_64)** on **Fedora Linux (Fedora 38, 39, 40, 41, and Rawhide)**.

---

## 1. Prerequisites on Fedora

Ensure your CPU has hardware virtualization (VT-x or AMD-V) enabled in your BIOS/UEFI.

Install required dependencies via `dnf` / `dnf5`:

```bash
sudo dnf install -y \
    qemu-kvm \
    qemu-img \
    android-tools \
    e2fsprogs \
    p7zip \
    p7zip-plugins \
    python3 \
    python3-tkinter \
    python3-pip \
    aria2 \
    libnotify \
    pulseaudio-utils \
    pipewire-utils \
    xdg-utils
```

### Enable KVM User Permissions
To allow running KVM without root/sudo:
```bash
sudo usermod -aG kvm $USER
sudo tee /etc/udev/rules.d/65-wsa-kvm.rules << 'EOF'
KERNEL=="kvm", GROUP="kvm", MODE="0666"
EOF
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=kvm
```
*(Log out and log back in for group membership to refresh).*

---

## 2. Converting the `WSA_2210.40000.7.0_x86_64_Windows10` Build

If you have downloaded the prebuilt archive `WSA_2210.40000.7.0_x86_64_Windows10.7z` (or extracted directory) from MustardChef/WSABuilds:

Run the automated Linux converter:
```bash
cd linux-wsa/converter
./convert_wsa_build.sh /path/to/WSA_2210.40000.7.0_x86_64_Windows10.7z -o ./output --distro fedora
```

The converter will:
1. Extract and validate Android images: `system.img`, `vendor.img`, `product.img`, `system_ext.img`.
2. Extract the Linux kernel (`Tools/kernel`) and patched ramdisk (`Tools/initrd.img` with Magisk and MindTheGapps).
3. Strip away Windows AppX metadata and Windows DLLs/exes.
4. Inject native Linux subsystem binaries (`wsa-runner`, `wsa-client`, `wsa-app`, `wsa-settings`).
5. Output a ready-to-run package in `output/wsa-linux-2210.40000.7.0-x86_64/`.

---

## 3. Installation on Fedora

### Option A: Direct Installer
```bash
cd output/wsa-linux-2210.40000.7.0-x86_64
sudo ./install.sh
```

### Option B: Build Native Fedora RPM
```bash
cd packaging/fedora
rpmbuild -ba wsa-linux.spec
sudo dnf install -y ~/rpmbuild/RPMS/x86_64/wsa-linux-2210.40000.7.0-1.fc*.x86_64.rpm
```

---

## 4. Usage & Controls

### Start WSA Subsystem
```bash
# Start with GUI window
wsa-client start

# Or start headless in background (for seamless app launching)
wsa-client start --daemon
```

### Check Status
```bash
wsa-client status
```

### Google Play Store & Root (Magisk)
```bash
# Launch Google Play Store directly
wsa-client play

# Launch Magisk Manager
wsa-client magisk

# Open Android Settings
wsa-client settings
```

### Sideload & Install Android APKs
```bash
wsa-client install /path/to/app.apk
```
This automatically installs the APK and creates a `.desktop` shortcut in Fedora GNOME / KDE menus!

### Synchronize Apps to Desktop
```bash
wsa-client sync-apps
```

### Adjust Hardware Configuration (RAM, CPU, 3D Acceleration)
```bash
wsa-settings
```
You can configure:
* CPU Cores (e.g. 4 or 8)
* Memory (RAM) (e.g. 4G, 8G, 16G)
* Display Mode: GTK, SDL, or Headless
* 3D Acceleration: VirGL (OpenGL/Vulkan)
* Shared Folder: Mounts `~/AndroidShare` into Android `/sdcard/Windows`
