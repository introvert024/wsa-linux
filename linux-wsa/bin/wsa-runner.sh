#!/usr/bin/env bash
#=============================================================================
# WSA Linux Subsystem Runner (LSA - Linux Subsystem for Android)
# Core Virtualization & Android Execution Engine for Fedora, Ubuntu & Linux
# Adapted from Windows Subsystem for Android (WSABuilds)
#=============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration paths
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wsa-linux"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/wsa-linux"
CONFIG_FILE="$CONFIG_DIR/wsa-linux.conf"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/wsa-linux"

mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$RUNTIME_DIR"

# Default configuration values
DEFAULT_CPUS=$(nproc 2>/dev/null || echo 4)
DEFAULT_RAM="4G"
DEFAULT_USERDATA_SIZE="16G"
DEFAULT_DISPLAY="auto" # auto, gtk, sdl, headless
DEFAULT_GL="on"        # on, off
DEFAULT_ADB_PORT=5555
DEFAULT_SHARE_DIR="$HOME/AndroidShare"

# Load user configuration if present
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

WSA_CPUS="${WSA_CPUS:-$DEFAULT_CPUS}"
WSA_RAM="${WSA_RAM:-$DEFAULT_RAM}"
USERDATA_SIZE="${WSA_USERDATA_SIZE:-$DEFAULT_USERDATA_SIZE}"
DISPLAY_MODE="${WSA_DISPLAY:-$DEFAULT_DISPLAY}"
GL_MODE="${WSA_GL:-$DEFAULT_GL}"
ADB_PORT="${WSA_ADB_PORT:-$DEFAULT_ADB_PORT}"
SHARE_DIR="${WSA_SHARE_DIR:-$DEFAULT_SHARE_DIR}"
mkdir -p "$SHARE_DIR"

# Locate WSA root image directory
if [[ -n "$WSA_IMAGES_DIR" && -d "$WSA_IMAGES_DIR" ]]; then
    IMG_DIR="$WSA_IMAGES_DIR"
elif [[ -d "$BASE_DIR/images" ]]; then
    IMG_DIR="$BASE_DIR/images"
elif [[ -d "$BASE_DIR/WSA" ]]; then
    IMG_DIR="$BASE_DIR/WSA"
elif [[ -d "$DATA_DIR/images" ]]; then
    IMG_DIR="$DATA_DIR/images"
else
    IMG_DIR="$BASE_DIR"
fi

# Locate Kernel and Initrd
KERNEL="$IMG_DIR/Tools/kernel"
INITRD="$IMG_DIR/Tools/initrd.img"

if [[ ! -f "$KERNEL" ]]; then
    # Fallback search
    KERNEL=$(find "$IMG_DIR" -name "kernel" -type f 2>/dev/null | head -n 1 || true)
fi

if [[ ! -f "$INITRD" ]]; then
    INITRD=$(find "$IMG_DIR" -name "initrd.img" -type f 2>/dev/null | head -n 1 || true)
fi

# Verify core files
if [[ ! -f "$KERNEL" || ! -f "$INITRD" ]]; then
    echo "[!] Error: WSA kernel or initrd.img not found in: $IMG_DIR"
    echo "    Please run the converter first or ensure WSA images are installed."
    exit 1
fi

# Verify and setup Android partition images
SYSTEM_IMG="$IMG_DIR/system.img"
VENDOR_IMG="$IMG_DIR/vendor.img"
PRODUCT_IMG="$IMG_DIR/product.img"
SYSTEM_EXT_IMG="$IMG_DIR/system_ext.img"
USERDATA_IMG="$DATA_DIR/userdata.img"

if [[ ! -f "$SYSTEM_IMG" ]]; then
    echo "[!] Error: system.img not found at $SYSTEM_IMG"
    exit 1
fi

if [[ ! -f "$VENDOR_IMG" ]]; then
    echo "[!] Error: vendor.img not found at $VENDOR_IMG"
    exit 1
fi

# Initialize userdata.img if not present
if [[ ! -f "$USERDATA_IMG" ]]; then
    echo "[*] Creating persistent user data disk ($USERDATA_SIZE)..."
    truncate -s "$USERDATA_SIZE" "$USERDATA_IMG"
    mkfs.ext4 -F -L userdata -O ^has_journal,^huge_file "$USERDATA_IMG" >/dev/null 2>&1 || mkfs.ext4 -F -L userdata "$USERDATA_IMG"
    echo "[+] userdata.img created successfully at $USERDATA_IMG"
fi

# Check KVM hardware acceleration
KVM_FLAG=""
if [[ -e /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
    KVM_FLAG="-enable-kvm -cpu host"
elif [[ -e /dev/kvm ]]; then
    echo "[!] Warning: /dev/kvm exists but is not readable/writable by current user."
    echo "    Fix on Fedora/Ubuntu with: sudo usermod -aG kvm $USER"
    echo "    Attempting to run with sudo or fallback..."
    KVM_FLAG="-enable-kvm -cpu host"
else
    echo "[!] Warning: Hardware KVM acceleration not available! Emulation mode will be slow."
    KVM_FLAG="-cpu max"
fi

# Select Display and 3D acceleration
QEMU_DISPLAY_ARGS=()
case "$DISPLAY_MODE" in
    "headless")
        QEMU_DISPLAY_ARGS=(-display none -vga none)
        ;;
    "sdl")
        if [[ "$GL_MODE" == "on" ]]; then
            QEMU_DISPLAY_ARGS=(-device virtio-vga-gl -display sdl,gl=on)
        else
            QEMU_DISPLAY_ARGS=(-device virtio-vga -display sdl)
        fi
        ;;
    "gtk")
        if [[ "$GL_MODE" == "on" ]]; then
            QEMU_DISPLAY_ARGS=(-device virtio-vga-gl -display gtk,gl=on)
        else
            QEMU_DISPLAY_ARGS=(-device virtio-vga -display gtk)
        fi
        ;;
    "auto"|*)
        if command -v pkg-config >/dev/null 2>&1 && qemu-system-x86_64 -display help 2>&1 | grep -q "gtk"; then
            if [[ "$GL_MODE" == "on" ]]; then
                QEMU_DISPLAY_ARGS=(-device virtio-vga-gl -display gtk,gl=on)
            else
                QEMU_DISPLAY_ARGS=(-device virtio-vga -display gtk)
            fi
        elif qemu-system-x86_64 -display help 2>&1 | grep -q "sdl"; then
            if [[ "$GL_MODE" == "on" ]]; then
                QEMU_DISPLAY_ARGS=(-device virtio-vga-gl -display sdl,gl=on)
            else
                QEMU_DISPLAY_ARGS=(-device virtio-vga -display sdl)
            fi
        else
            QEMU_DISPLAY_ARGS=(-device virtio-vga -display default)
        fi
        ;;
esac

# Audio configuration (PipeWire / PulseAudio)
AUDIO_ARGS=()
if pactl info >/dev/null 2>&1 || [[ -n "$PULSE_SERVER" ]] || [[ -S "/run/user/$(id -u)/pulse/native" ]]; then
    AUDIO_ARGS=(
        -audiodev "pa,id=audio0,server=/run/user/$(id -u)/pulse/native"
        -device "intel-hda"
        -device "hda-duplex,audiodev=audio0"
    )
else
    AUDIO_ARGS=(
        -audiodev "none,id=audio0"
    )
fi

# Drive configuration (virtio block devices matching WSA initrd mounts)
DRIVE_ARGS=(
    -drive "file=$SYSTEM_IMG,if=none,id=system,format=raw,readonly=on"
    -device "virtio-blk-pci,drive=system"
    -drive "file=$VENDOR_IMG,if=none,id=vendor,format=raw,readonly=on"
    -device "virtio-blk-pci,drive=vendor"
)

if [[ -f "$PRODUCT_IMG" ]]; then
    DRIVE_ARGS+=(
        -drive "file=$PRODUCT_IMG,if=none,id=product,format=raw,readonly=on"
        -device "virtio-blk-pci,drive=product"
    )
fi

if [[ -f "$SYSTEM_EXT_IMG" ]]; then
    DRIVE_ARGS+=(
        -drive "file=$SYSTEM_EXT_IMG,if=none,id=system_ext,format=raw,readonly=on"
        -device "virtio-blk-pci,drive=system_ext"
    )
fi

DRIVE_ARGS+=(
    -drive "file=$USERDATA_IMG,if=none,id=userdata,format=raw"
    -device "virtio-blk-pci,drive=userdata"
)

# Shared folder between host Linux and WSA Android (/sdcard/Windows)
SHARE_ARGS=(
    -fsdev "local,security_model=none,id=fsdev0,path=$SHARE_DIR"
    -device "virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=host_share"
)

# Network configuration with ADB forward
NET_ARGS=(
    -netdev "user,id=net0,hostfwd=tcp::$ADB_PORT-:5555"
    -device "virtio-net-pci,netdev=net0"
)

# USB tablet pointer for accurate mouse tracking
INPUT_ARGS=(
    -device "virtio-tablet-pci"
    -device "virtio-keyboard-pci"
)

# Kernel command line
CMDLINE="console=ttyS0 root=/dev/ram0 androidboot.hardware=virtio androidboot.serialno=WSA_LINUX androidboot.selinux=permissive loop.max_part=7 virtio_gpu.virgl=1 quiet"

PID_FILE="$RUNTIME_DIR/wsa.pid"

# Check if already running
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "[!] WSA Linux is already running (PID: $(cat "$PID_FILE"))."
    echo "    Use 'wsa-client stop' or 'kill $(cat "$PID_FILE")' to stop it."
    exit 0
fi

echo "============================================================"
echo " Starting WSA Linux Subsystem (Android 12.1 / API 32)"
echo " CPUs: $WSA_CPUS | RAM: $WSA_RAM | ADB Port: $ADB_PORT"
echo " Host Share: $SHARE_DIR"
echo "============================================================"

# Launch QEMU
# shellcheck disable=SC2086
exec qemu-system-x86_64 \
    $KVM_FLAG \
    -m "$WSA_RAM" \
    -smp "$WSA_CPUS" \
    -kernel "$KERNEL" \
    -initrd "$INITRD" \
    -append "$CMDLINE" \
    "${QEMU_DISPLAY_ARGS[@]}" \
    "${AUDIO_ARGS[@]}" \
    "${DRIVE_ARGS[@]}" \
    "${SHARE_ARGS[@]}" \
    "${NET_ARGS[@]}" \
    "${INPUT_ARGS[@]}" \
    -pidfile "$PID_FILE" \
    "$@"
