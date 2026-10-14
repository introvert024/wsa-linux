#!/usr/bin/env bash
#=============================================================================
# WSA Linux Installer
# Automated installer for Fedora (dnf/dnf5) and Ubuntu (apt)
#=============================================================================

set -eo pipefail

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$INSTALLER_DIR/.." && pwd)"

echo "============================================================"
echo "    Windows Subsystem for Android (WSA) on Linux Installer"
echo "    Target Distributions: Fedora & Ubuntu"
echo "============================================================"

# Detect Distribution
DISTRO="unknown"
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO="$ID"
    DISTRO_LIKE="${ID_LIKE:-$ID}"
fi

echo "[*] Detected OS: $NAME ($DISTRO)"

# Check Virtualization Support
echo "[*] Checking CPU virtualization extensions (VT-x / AMD-V)..."
if grep -E -q '(vmx|svm)' /proc/cpuinfo; then
    echo "[+] CPU hardware virtualization is supported by your processor."
else
    echo "[!] Warning: CPU hardware virtualization (VT-x/AMD-V) flag not found in /proc/cpuinfo."
    echo "    Make sure Virtualization is enabled in your BIOS/UEFI settings."
fi

# Package Installation
echo "[*] Installing required system packages..."
if [[ "$DISTRO" =~ fedora|rhel|centos ]]; then
    echo "[*] Configuring for Fedora/RHEL ecosystem..."
    PM="dnf"
    if command -v dnf5 >/dev/null 2>&1; then
        PM="dnf5"
    fi
    sudo "$PM" install -y \
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
elif [[ "$DISTRO" =~ ubuntu|debian|pop|linuxmint ]]; then
    echo "[*] Configuring for Ubuntu/Debian ecosystem..."
    sudo apt-get update
    sudo apt-get install -y \
        qemu-system-x86 \
        qemu-utils \
        adb \
        e2fsprogs \
        p7zip-full \
        python3 \
        python3-tk \
        python3-pip \
        aria2 \
        libnotify-bin \
        pulseaudio-utils \
        xdg-utils
else
    echo "[!] Unsupported or generic Linux distribution. Please ensure qemu-system-x86_64, adb, and e2fsprogs are installed."
fi

# Setup KVM group and permissions
echo "[*] Configuring KVM access permissions..."
if getent group kvm >/dev/null; then
    sudo usermod -aG kvm "$USER" || true
fi

# Add udev rule for reliable /dev/kvm access
sudo tee /etc/udev/rules.d/65-wsa-kvm.rules >/dev/null << 'EOF'
KERNEL=="kvm", GROUP="kvm", MODE="0666"
EOF
sudo udevadm control --reload-rules || true
sudo udevadm trigger --name-match=kvm || true

# Target installation directory
TARGET_DIR="/opt/wsa-linux"
echo "[*] Installing WSA binaries into $TARGET_DIR..."
sudo mkdir -p "$TARGET_DIR/bin" "$TARGET_DIR/desktop" "$TARGET_DIR/systemd"

# Copy binaries
sudo cp "$PACKAGE_DIR/bin/wsa-runner.sh" "$TARGET_DIR/bin/wsa-runner"
sudo cp "$PACKAGE_DIR/bin/wsa-client" "$TARGET_DIR/bin/wsa-client"
sudo cp "$PACKAGE_DIR/bin/wsa-app" "$TARGET_DIR/bin/wsa-app"
sudo cp "$PACKAGE_DIR/bin/wsa-sync-apps" "$TARGET_DIR/bin/wsa-sync-apps"
sudo cp "$PACKAGE_DIR/bin/wsa-settings" "$TARGET_DIR/bin/wsa-settings"
sudo cp "$PACKAGE_DIR/bin/wsa-uninstaller" "$TARGET_DIR/bin/wsa-uninstaller"
sudo chmod +x "$TARGET_DIR/bin/"*

# Create symlinks in /usr/local/bin
sudo ln -sf "$TARGET_DIR/bin/wsa-runner" /usr/local/bin/wsa-runner
sudo ln -sf "$TARGET_DIR/bin/wsa-client" /usr/local/bin/wsa-client
sudo ln -sf "$TARGET_DIR/bin/wsa-app" /usr/local/bin/wsa-app
sudo ln -sf "$TARGET_DIR/bin/wsa-sync-apps" /usr/local/bin/wsa-sync-apps
sudo ln -sf "$TARGET_DIR/bin/wsa-settings" /usr/local/bin/wsa-settings
sudo ln -sf "$TARGET_DIR/bin/wsa-uninstaller" /usr/local/bin/wsa-uninstaller

# Copy Android images if present in package
if [[ -d "$PACKAGE_DIR/images" ]]; then
    echo "[*] Copying Android OS partition images to $TARGET_DIR/images..."
    sudo mkdir -p "$TARGET_DIR/images"
    sudo cp -r "$PACKAGE_DIR/images/"* "$TARGET_DIR/images/"
elif [[ -f "$PACKAGE_DIR/system.img" ]]; then
    echo "[*] Copying Android OS partition images to $TARGET_DIR/images..."
    sudo mkdir -p "$TARGET_DIR/images"
    sudo cp "$PACKAGE_DIR"/*.img "$TARGET_DIR/images/" 2>/dev/null || true
    if [[ -d "$PACKAGE_DIR/Tools" ]]; then
        sudo cp -r "$PACKAGE_DIR/Tools" "$TARGET_DIR/images/"
    fi
fi

# Install Desktop Shortcuts and URI protocol
echo "[*] Registering Desktop shortcuts and wsa:// URI protocol..."
sudo cp "$PACKAGE_DIR/desktop/wsa-settings.desktop" /usr/share/applications/
sudo cp "$PACKAGE_DIR/desktop/wsa-uri-handler.desktop" /usr/share/applications/
xdg-mime default wsa-uri-handler.desktop x-scheme-handler/wsa 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true

# Install Systemd User Service
USER_SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$USER_SYSTEMD_DIR"
cp "$PACKAGE_DIR/systemd/wsa-linux.service" "$USER_SYSTEMD_DIR/"
systemctl --user daemon-reload 2>/dev/null || true

echo ""
echo "============================================================"
echo " [+] WSA Linux Subsystem successfully installed!"
echo "============================================================"
echo " Quick Start Guide:"
echo "  1. Start Android Subsystem:  wsa-client start"
echo "  2. Launch Google Play Store: wsa-client play"
echo "  3. Open Magisk Manager:      wsa-client magisk"
echo "  4. Install an APK:           wsa-client install app.apk"
echo "  5. Adjust CPU/RAM/Settings:  wsa-settings"
echo "  6. Sync apps to menu:        wsa-client sync-apps"
echo ""
echo " Note: If this is your first time adding the kvm group,"
echo " you may need to log out and log back in for KVM group access."
echo "============================================================"
