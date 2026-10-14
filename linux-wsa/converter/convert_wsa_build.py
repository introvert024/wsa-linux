#!/usr/bin/env python3
"""
=============================================================================
 WSA-to-Linux Converter Engine
 Converts Windows Subsystem for Android (WSA) builds (including
 WSA_2210.40000.7.0_x86_64_Windows10) into a fully functional
 Linux Subsystem for Android (LSA) targeting Fedora & Ubuntu.
=============================================================================
"""

import os
import sys
import shutil
import subprocess
import argparse
import tarfile
import zipfile
from pathlib import Path

VERSION = "2210.40000.7.0"
ARCH = "x86_64"

def log(msg):
    print(f"[*] {msg}", flush=True)

def error(msg):
    print(f"[!] ERROR: {msg}", file=sys.stderr, flush=True)
    sys.exit(1)

def run_command(cmd, cwd=None):
    log(f"Executing: {' '.join(cmd)}")
    res = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode != 0:
        error(f"Command failed:\n{res.stderr.strip()}")
    return res.stdout

def extract_archive(archive_path: Path, dest_dir: Path):
    dest_dir.mkdir(parents=True, exist_ok=True)
    log(f"Extracting {archive_path.name} to {dest_dir}...")
    
    suffix = archive_path.suffix.lower()
    if suffix == ".zip":
        with zipfile.ZipFile(archive_path, 'r') as zf:
            zf.extractall(dest_dir)
    elif suffix in [".7z", ".rar"]:
        if shutil.which("7z"):
            run_command(["7z", "x", "-y", f"-o{dest_dir}", str(archive_path)])
        elif shutil.which("7za"):
            run_command(["7za", "x", "-y", f"-o{dest_dir}", str(archive_path)])
        else:
            error("p7zip is required to extract .7z files. Install with 'dnf install p7zip' or 'apt install p7zip-full'.")
    elif suffix in [".tar", ".gz", ".xz", ".tgz"]:
        with tarfile.open(archive_path, 'r:*') as tf:
            tf.extractall(dest_dir)
    else:
        error(f"Unsupported archive format: {archive_path.suffix}")
    log("Extraction complete.")

def find_wsa_root(search_dir: Path) -> Path:
    """Find directory containing system.img and Tools/kernel"""
    for root, dirs, files in os.walk(search_dir):
        p = Path(root)
        if (p / "system.img").is_file():
            return p
        if (p / "Tools" / "kernel").is_file():
            return p
    return search_dir

def convert_build(input_path: Path, output_dir: Path, target_distro: str = "fedora", create_packages: bool = True):
    log("==================================================================")
    log(f" Starting WSA Linux Conversion (Target Build: {VERSION})")
    log(f" Target Distribution: {target_distro.upper()} (with Ubuntu support)")
    log("==================================================================")

    temp_extract = Path("/tmp/wsa_convert_tmp") if os.name != 'nt' else Path("./wsa_convert_tmp")
    if temp_extract.exists():
        shutil.rmtree(temp_extract)
    temp_extract.mkdir(parents=True, exist_ok=True)

    try:
        # Step 1: Input Resolution
        if input_path.is_file():
            extract_archive(input_path, temp_extract)
            source_root = find_wsa_root(temp_extract)
        elif input_path.is_dir():
            source_root = find_wsa_root(input_path)
        else:
            error(f"Input path not found: {input_path}")

        log(f"Identified WSA image root at: {source_root}")

        # Step 2: Validate essential Android partitions
        kernel_path = source_root / "Tools" / "kernel"
        initrd_path = source_root / "Tools" / "initrd.img"
        system_img = source_root / "system.img"
        vendor_img = source_root / "vendor.img"

        if not kernel_path.is_file():
            # Search recursively
            found_kernel = list(source_root.glob("**/Tools/kernel")) or list(source_root.glob("**/kernel"))
            if found_kernel:
                kernel_path = found_kernel[0]
            else:
                error("Missing WSA Linux kernel (Tools/kernel).")

        if not initrd_path.is_file():
            found_initrd = list(source_root.glob("**/Tools/initrd.img")) or list(source_root.glob("**/initrd.img"))
            if found_initrd:
                initrd_path = found_initrd[0]
            else:
                error("Missing WSA ramdisk (Tools/initrd.img).")

        if not system_img.is_file():
            found_system = list(source_root.glob("**/system.img"))
            if found_system:
                system_img = found_system[0]
            else:
                error("Missing Android system.img.")

        if not vendor_img.is_file():
            found_vendor = list(source_root.glob("**/vendor.img"))
            if found_vendor:
                vendor_img = found_vendor[0]
            else:
                error("Missing Android vendor.img.")

        log("[+] Validated core Android images and Linux kernel:")
        log(f"    Kernel:  {kernel_path}")
        log(f"    Initrd:  {initrd_path}")
        log(f"    System:  {system_img}")
        log(f"    Vendor:  {vendor_img}")

        # Step 3: Prepare Target Linux Subsystem Directory
        pkg_name = f"wsa-linux-{VERSION}-{ARCH}"
        target_dir = output_dir / pkg_name
        if target_dir.exists():
            shutil.rmtree(target_dir)

        (target_dir / "images" / "Tools").mkdir(parents=True, exist_ok=True)
        (target_dir / "bin").mkdir(parents=True, exist_ok=True)
        (target_dir / "installer").mkdir(parents=True, exist_ok=True)
        (target_dir / "desktop").mkdir(parents=True, exist_ok=True)
        (target_dir / "systemd").mkdir(parents=True, exist_ok=True)
        (target_dir / "packaging" / "fedora").mkdir(parents=True, exist_ok=True)
        (target_dir / "packaging" / "ubuntu" / "debian").mkdir(parents=True, exist_ok=True)

        # Copy Images (pure Android Linux images, no Windows AppX binaries)
        log("Copying Android partition images...")
        shutil.copy2(kernel_path, target_dir / "images" / "Tools" / "kernel")
        shutil.copy2(initrd_path, target_dir / "images" / "Tools" / "initrd.img")
        shutil.copy2(system_img, target_dir / "images" / "system.img")
        shutil.copy2(vendor_img, target_dir / "images" / "vendor.img")

        for optional_img in ["product.img", "system_ext.img"]:
            opt_path = source_root / optional_img
            if opt_path.is_file():
                log(f"Copying {optional_img}...")
                shutil.copy2(opt_path, target_dir / "images" / optional_img)

        # Step 4: Inject Linux Subsystem Runtime & Tooling
        script_dir = Path(__file__).resolve().parent
        linux_wsa_dir = script_dir.parent

        log("Injecting Linux Subsystem engine, management tools, and desktop integration...")
        bin_files = ["wsa-runner.sh", "wsa-client", "wsa-app", "wsa-sync-apps", "wsa-settings", "wsa-uninstaller"]
        for b in bin_files:
            src_b = linux_wsa_dir / "bin" / b
            if src_b.is_file():
                dst_b = target_dir / "bin" / b
                shutil.copy2(src_b, dst_b)
                dst_b.chmod(0o755)

        # Installer
        src_inst = linux_wsa_dir / "installer" / "install.sh"
        if src_inst.is_file():
            dst_inst = target_dir / "installer" / "install.sh"
            shutil.copy2(src_inst, dst_inst)
            dst_inst.chmod(0o755)
            # Also create top-level install.sh and run.sh for immediate ease of use
            top_inst = target_dir / "install.sh"
            top_inst.write_text("#!/usr/bin/env bash\nexec \"$(dirname \"$0\")/installer/install.sh\" \"$@\"\n")
            top_inst.chmod(0o755)

            top_run = target_dir / "run.sh"
            top_run.write_text("#!/usr/bin/env bash\nexec \"$(dirname \"$0\")/bin/wsa-runner.sh\" \"$@\"\n")
            top_run.chmod(0o755)

        # Desktop files
        for d in ["wsa-settings.desktop", "wsa-uri-handler.desktop"]:
            src_d = linux_wsa_dir / "desktop" / d
            if src_d.is_file():
                shutil.copy2(src_d, target_dir / "desktop" / d)

        # Systemd
        src_s = linux_wsa_dir / "systemd" / "wsa-linux.service"
        if src_s.is_file():
            shutil.copy2(src_s, target_dir / "systemd" / "wsa-linux.service")

        # Packaging specs
        src_spec = linux_wsa_dir / "packaging" / "fedora" / "wsa-linux.spec"
        if src_spec.is_file():
            shutil.copy2(src_spec, target_dir / "packaging" / "fedora" / "wsa-linux.spec")

        src_deb = linux_wsa_dir / "packaging" / "ubuntu" / "debian"
        if src_deb.is_dir():
            shutil.copytree(src_deb, target_dir / "packaging" / "ubuntu" / "debian", dirs_exist_ok=True)

        # Documentation
        readme = target_dir / "README.md"
        readme.write_text(f"""# Windows Subsystem for Android (WSA) on Linux
**Build:** {VERSION} ({ARCH})
**Converted from:** MustardChef/WSABuilds (WSA_{VERSION}_{ARCH}_Windows10)
**Target Distributions:** Fedora (38/39/40/41/Rawhide) and Ubuntu (20.04/22.04/24.04/24.10)

## Quick Installation

Run the automated installer:
```bash
sudo ./install.sh
```

## Running WSA
```bash
# Start Android subsystem
wsa-client start

# Open Google Play Store
wsa-client play

# Open Magisk Manager (Root)
wsa-client magisk

# Install an APK
wsa-client install my-app.apk

# Open WSA Settings (RAM, CPU, 3D graphics)
wsa-settings
```

## Building Fedora RPM
```bash
cd packaging/fedora
rpmbuild -ba wsa-linux.spec
```

## Building Ubuntu DEB
```bash
cd packaging/ubuntu
dpkg-buildpackage -us -uc -b
```
""")

        log(f"[+] Successfully converted WSA build into ready-to-use Linux distribution at:")
        log(f"    {target_dir.resolve()}")

        # Step 5: Archive & Packaging
        tar_path = output_dir / f"{pkg_name}.tar.gz"
        log(f"Creating portable distribution archive: {tar_path.name}...")
        with tarfile.open(tar_path, "w:gz") as tar:
            tar.add(target_dir, arcname=pkg_name)
        log(f"[+] Portable archive generated: {tar_path}")

        # If on Fedora with rpmbuild available
        if target_distro == "fedora" and shutil.which("rpmbuild"):
            log("Host has rpmbuild. You can build the native RPM with:")
            log(f"    rpmbuild -ta {tar_path}")

        log("==================================================================")
        log(" WSA BUILD CONVERSION COMPLETED SUCCESSFULLY!")
        log("==================================================================")

    finally:
        if temp_extract.exists():
            shutil.rmtree(temp_extract, ignore_errors=True)

def main():
    parser = argparse.ArgumentParser(
        description="Convert Windows Subsystem for Android (WSA) Windows builds into Linux native subsystem (Fedora & Ubuntu)"
    )
    parser.add_argument(
        "input",
        nargs="?",
        default="WSA_2210.40000.7.0_x86_64_Windows10",
        help="Path to WSA 7z, zip, or extracted directory of WSA_2210.40000.7.0_x86_64_Windows10",
    )
    parser.add_argument(
        "-o", "--output",
        default="./output",
        help="Output directory for the Linux WSA distribution (default: ./output)",
    )
    parser.add_argument(
        "--distro",
        choices=["fedora", "ubuntu", "all"],
        default="fedora",
        help="Primary target Linux distribution (default: fedora)",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    output_dir = Path(args.output).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    convert_build(input_path, output_dir, target_distro=args.distro)

if __name__ == "__main__":
    main()
