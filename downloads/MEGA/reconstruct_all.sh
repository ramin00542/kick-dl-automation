#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
echo "🔍 Scanning for folders containing split files..."
for dir in */; do
    if [ -d "$dir" ] && [ -f "$dir/merge.sh" ]; then
        echo "🔄 Reconstructing in $dir"
        (cd "$dir" && bash merge.sh)
    fi
done
echo "✅ All files reconstructed successfully."
