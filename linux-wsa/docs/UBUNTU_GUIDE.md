# Running Windows Subsystem for Android (WSA) on Ubuntu Linux

This guide details how to install, convert, and run **WSA 2210.40000.7.0 (x86_64)** on **Ubuntu Linux (20.04 LTS, 22.04 LTS, 24.04 LTS, 24.10)** and Debian-based systems.

---

## 1. Prerequisites on Ubuntu

Install the required packages via `apt`:

```bash
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
```

### KVM Permissions
```bash
sudo usermod -aG kvm $USER
sudo tee /etc/udev/rules.d/65-wsa-kvm.rules << 'EOF'
KERNEL=="kvm", GROUP="kvm", MODE="0666"
EOF
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=kvm
```

---

## 2. Converting the Build

Convert the prebuilt `WSA_2210.40000.7.0_x86_64_Windows10.7z` build:

```bash
cd linux-wsa/converter
./convert_wsa_build.sh /path/to/WSA_2210.40000.7.0_x86_64_Windows10.7z -o ./output --distro ubuntu
```

---

## 3. Installation

### Direct Install:
```bash
cd output/wsa-linux-2210.40000.7.0-x86_64
sudo ./install.sh
```

### Debian Package (.deb):
```bash
cd packaging/ubuntu
dpkg-buildpackage -us -uc -b
sudo dpkg -i ../wsa-linux_2210.40000.7.0*.deb
```

---

## 4. Usage Commands

```bash
# Start Android Subsystem
wsa-client start

# Open Google Play Store
wsa-client play

# Open Magisk Root Manager
wsa-client magisk

# Install any APK into WSA
wsa-client install app.apk

# Sync Android Apps to Ubuntu Dash / Menu
wsa-client sync-apps

# Open WSA Settings Control Panel
wsa-settings
```
