#!/usr/bin/env bash
#=============================================================================
# Helper bash script to convert WSA 2210.40000.7.0 Windows build to Linux
#=============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BUILD="${1:-WSA_2210.40000.7.0_x86_64_Windows10}"
OUTPUT_DIR="${2:-$SCRIPT_DIR/../output}"

echo "============================================================"
echo " Converting WSA Build: $TARGET_BUILD to Linux (Fedora/Ubuntu)"
echo "============================================================"

python3 "$SCRIPT_DIR/convert_wsa_build.py" "$TARGET_BUILD" -o "$OUTPUT_DIR" --distro fedora "$@"
