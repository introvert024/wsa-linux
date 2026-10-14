#!/usr/bin/env bash
#=============================================================================
# WSA Linux Subsystem One-Line Online Installer
# Supports:
#  - Fedora 38, 39, 40, 41, Rawhide (via DNF / RPM)
#  - Ubuntu 20.04, 22.04, 24.04, 24.10, Debian (via APT / DEB)
# Usage:
#  curl -fsSL https://raw.githubusercontent.com/introvert024/wsa-linux/main/install-online.sh | bash
#=============================================================================

set -eo pipefail

REPO="introvert024/wsa-linux"
TAG="v2210.40000.7.0"
RELEASE_URL="https://github.com/$REPO/releases/download/$TAG"

echo "============================================================"
echo " Windows Subsystem for Android (WSA) on Linux Installer"
echo " Automated setup for Fedora and Ubuntu"
echo "============================================================"

# Detect distribution
DISTRO="unknown"
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO="$ID"
    DISTRO_LIKE="${ID_LIKE:-$ID}"
fi

echo "[*] Detected Linux OS: $NAME ($DISTRO)"

# Check virtualization
if ! grep -E -q '(vmx|svm)' /proc/cpuinfo; then
    echo "[!] Warning: Hardware virtualization (VT-x/AMD-V) flag was not detected."
    echo "    Make sure Virtualization is enabled in your UEFI/BIOS."
else
    echo "[+] Hardware virtualization (KVM) supported."
fi

WORK_DIR="$(mktemp -d -t wsa-installer-XXXXXX)"
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cd "$WORK_DIR"

if [[ "$DISTRO" =~ fedora|rhel|centos ]]; then
    echo "[*] Installing for Fedora ecosystem..."
    PM="dnf"
    if command -v dnf5 >/dev/null 2>&1; then
        PM="dnf5"
    fi

    # Try downloading binary RPM if available in release, otherwise use bundle
    RPM_FILE="wsa-linux-2210.40000.7.0-1.x86_64.rpm"
    BUNDLE_FILE="wsa-linux-2210.40000.7.0-fedora.tar.gz"

    if curl --head --silent --fail "$RELEASE_URL/$RPM_FILE" >/dev/null 2>&1; then
        echo "[*] Downloading Fedora RPM package..."
        curl -fSL -o "$RPM_FILE" "$RELEASE_URL/$RPM_FILE"
        sudo "$PM" install -y "./$RPM_FILE"
    else
        echo "[*] Downloading Fedora package bundle..."
        curl -fSL -o "$BUNDLE_FILE" "$RELEASE_URL/$BUNDLE_FILE"
        tar -xzf "$BUNDLE_FILE"
        sudo ./installer/install.sh
    fi

elif [[ "$DISTRO" =~ ubuntu|debian|pop|linuxmint ]]; then
    echo "[*] Installing for Ubuntu/Debian ecosystem..."
    DEB_FILE="wsa-linux_2210.40000.7.0_amd64.deb"
    echo "[*] Downloading Debian package: $DEB_FILE..."
    curl -fSL -o "$DEB_FILE" "$RELEASE_URL/$DEB_FILE"
    sudo apt-get update
    sudo apt-get install -y "./$DEB_FILE"
else
    echo "[*] Generic Linux distribution detected. Using Universal Installer..."
    TAR_FILE="wsa-linux-2210.40000.7.0-universal.tar.gz"
    curl -fSL -o "$TAR_FILE" "$RELEASE_URL/$TAR_FILE"
    tar -xzf "$TAR_FILE"
    sudo ./installer/install.sh
fi

echo ""
echo "============================================================"
echo " [+] WSA Linux Subsystem successfully installed!"
echo "============================================================"
echo " To start WSA Android subsystem:  wsa-client start"
echo " To open Google Play Store:        wsa-client play"
echo " To open Magisk Root Manager:      wsa-client magisk"
echo " To install any Android APK:       wsa-client install app.apk"
echo " To configure CPU/RAM/Settings:    wsa-settings"
echo "============================================================"
