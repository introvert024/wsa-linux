# WSAUpdater
# Version: 1.0.0
#
# This file is part of the WSABuilds project.
#
# WSAUpdater is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# WSAUpdater is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with WSAUpdater.  If not, see <https://www.gnu.org/licenses/>.
#
# Copyright (C) 2024 MustardChef & Linux Port Contributors
#

import os
import sys
import json
import urllib.request
import subprocess
from pathlib import Path

REPO = "MustardChef/WSABuilds"
API_URL = f"https://api.github.com/repos/{REPO}/releases/latest"

def get_installed_version():
    if os.name == 'nt':
        try:
            cmd = 'powershell.exe -Command "(Get-AppxPackage -Name *WindowsSubsystemForAndroid*).Version"'
            res = subprocess.check_output(cmd, shell=True, text=True).strip()
            return res if res else None
        except Exception:
            return None
    else:
        # Check Linux installation
        try:
            res = subprocess.check_output(["wsa-client", "status"], text=True)
            for line in res.splitlines():
                if "Android Version:" in line:
                    return line.split(":", 1)[1].strip()
        except Exception:
            pass
        return "2210.40000.7.0"

def check_for_updates():
    print(f"[*] Checking for latest WSA builds from {REPO}...")
    try:
        req = urllib.request.Request(API_URL, headers={'User-Agent': 'WSAUpdater'})
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode())
            tag = data.get("tag_name", "unknown")
            print(f"[+] Latest release tag: {tag}")
            installed = get_installed_version()
            print(f"[*] Currently installed version: {installed or 'Not detected'}")

            assets = data.get("assets", [])
            print(f"[*] Available download assets ({len(assets)}):")
            for a in assets[:5]:
                print(f"    - {a.get('name')} ({round(a.get('size', 0)/1024/1024, 1)} MB)")
            return data
    except Exception as e:
        print(f"[!] Failed to check updates: {e}")
        return None

if __name__ == "__main__":
    check_for_updates()
