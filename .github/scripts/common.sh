#!/bin/bash
# =============================================================================
# common.sh — Shared utilities for kick-dl-automation scripts
# =============================================================================
# This script is meant to be sourced by other scripts (not executed directly).
# Usage: source "$(dirname "$0")/common.sh"
#
# Provides:
#   - Logging with colors (log_info, log_warn, log_error, log_step)
#   - Auto-detect split size from file extension (detect_split_size)
#   - Generate merge scripts for split files (generate_merge_scripts)
#   - Generate master reconstruction script (generate_master_script)
#   - Get target base directory (get_target_base)
#   - Safe file flattening (flatten_directories)
# =============================================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── Logging ─────────────────────────────────────────────────────────────────
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "${BLUE}[STEP]${NC}  $*"; }
log_debug() { echo -e "${MAGENTA}[DEBUG]${NC} $*"; }

# ── Auto-detect split size based on first file's extension ─────────────────
# Usage: SPLIT_MB=$(detect_split_size "/path/to/dir" 90)
detect_split_size() {
    local dir="${1:-tmp_downloads}"
    local default="${2:-90}"

    # shellcheck disable=SC2012
    FIRST_FILE=$(ls -1 "$dir" 2>/dev/null | head -1)
    if [ -z "$FIRST_FILE" ]; then
        echo "$default"
        return
    fi

    EXT="${FIRST_FILE##*.}"
    EXT_LOWER=$(tr '[:upper:]' '[:lower:]' <<< "$EXT")

    case "$EXT_LOWER" in
        # Video → 200MB (usually huge, fewer parts = easier download)
        mp4|mkv|avi|mov|wmv|flv|m4v|webm|vob|mpg|mpeg|ts|3gp|ogv)
            echo 200 ;;
        # Audio → 100MB
        mp3|flac|wav|aac|ogg|wma|m4a|opus|ape|aiff)
            echo 100 ;;
        # Archives → 150MB
        zip|rar|7z|tar|gz|bz2|xz|zst|tgz|tbz2)
            echo 150 ;;
        # Documents → 50MB
        pdf|doc|docx|xls|xlsx|ppt|pptx|epub|mobi|odt|ods|odp|csv|tsv|md)
            echo 50 ;;
        # Images → 25MB
        jpg|jpeg|png|gif|bmp|webp|svg|tiff|tif|ico|heic|avif)
            echo 25 ;;
        # ISOs & disk images → 200MB
        iso|img|bin|cue|vhd|vmdk|nrg|mdf)
            echo 200 ;;
        # Executables → 100MB
        exe|msi|apk|dmg|deb|rpm|AppImage|flatpak|snap)
            echo 100 ;;
        # Everything else → default (90MB)
        *)
            echo "$default" ;;
    esac
}

# ── Get target base directory from source type ──────────────────────────────
# Usage: TARGET_BASE=$(get_target_base "$SOURCE")
get_target_base() {
    local source="$1"
    if [ "$source" = "mega" ] || [ "$source" = "pixeldrain" ]; then
        echo "downloads/${source^^}"
    else
        echo "downloads/DIRECT"
    fi
}

# ── Generate merge scripts for a split file ─────────────────────────────────
# Usage: generate_merge_scripts "/path/to/dir" "filename.ext"
generate_merge_scripts() {
    local target_dir="$1"
    local base_name="$2"

    # merge.bat (Windows cmd)
    {
        printf '@echo off\r\n'
        printf 'title Merging %s ...\r\n' "$base_name"
        printf 'echo Reconstructing %s ...\r\n' "$base_name"
        printf 'copy /b "%s.part*" "%s" > nul\r\n' "$base_name" "$base_name"
        printf 'if errorlevel 1 (\r\n'
        printf '  echo ERROR: Merge failed!\r\n'
        printf '  pause\r\n'
        printf '  exit /b 1\r\n'
        printf ')\r\n'
        printf 'echo Done. File restored: %s\r\n' "$base_name"
        printf 'pause\r\n'
    } > "$target_dir/merge.bat"

    # merge.sh (Linux/macOS terminal)
    {
        printf '#!/bin/bash\n'
        printf 'cd "$(dirname "$0")"\n'
        printf 'echo "Reconstructing %s ..."\n' "$base_name"
        printf 'cat "%s.part"* > "%s"\n' "$base_name" "$base_name"
        printf 'echo "Done. File restored: %s"\n' "$base_name"
    } > "$target_dir/merge.sh"
    chmod +x "$target_dir/merge.sh"

    # merge.command (macOS double-click)
    {
        printf '#!/bin/bash\n'
        printf 'cd "$(dirname "$0")"\n'
        printf 'echo "Reconstructing %s ..."\n' "$base_name"
        printf 'cat "%s.part"* > "%s"\n' "$base_name" "$base_name"
        printf 'echo "Done. File restored: %s"\n' "$base_name"
        printf 'read -n 1 -p "Press any key to exit..."\n'
    } > "$target_dir/merge.command"
    chmod +x "$target_dir/merge.command"
}

# ── Generate master reconstruction script ───────────────────────────────────
# Usage: generate_master_script "/path/to/downloads/SOURCE"
generate_master_script() {
    local target_base="$1"
    local script_path="$target_base/reconstruct_all.sh"

    {
        printf '#!/bin/bash\n'
        printf 'set -e\n'
        printf 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
        printf 'cd "$SCRIPT_DIR"\n'
        printf 'echo "=== Reconstructing all split files === "\n'
        printf 'for dir in */; do\n'
        printf '  if [ -d "$dir" ] && [ -f "$dir/merge.sh" ]; then\n'
        printf '    echo "  → Reconstructing: ${dir%%/}"\n'
        printf '    (cd "$dir" && bash merge.sh)\n'
        printf '    echo "  ✓ ${dir%%/} restored"\n'
        printf '  fi\n'
        printf 'done\n'
        printf 'echo "=== All files reconstructed === "\n'
    } > "$script_path"
    chmod +x "$script_path"
}

# ── Flatten nested directories safely (avoid overwrites) ────────────────────
# Usage: flatten_directories "tmp_downloads"
flatten_directories() {
    local base_dir="${1:-tmp_downloads}"
    # shellcheck disable=SC2153
    find "$base_dir" -mindepth 2 -type f -print0 2>/dev/null | while IFS= read -r -d '' file; do
        local base
        base=$(basename "$file")
        local target="$base_dir/$base"
        if [ -e "$target" ]; then
            target="$base_dir/$(date +%s%N)_$base"
        fi
        mv "$file" "$target"
    done
    # shellcheck disable=SC2115
    find "$base_dir" -mindepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
}

# ── Clean sensitive files before commit ─────────────────────────────────────
# Usage: clean_sensitive_files "downloads"
clean_sensitive_files() {
    local search_dir="${1:-downloads}"
    find "$search_dir" -name 'password.txt' -delete 2>/dev/null || true
    rm -f logs/passwords_debug.log 2>/dev/null || true
}

# ── Create release notes ────────────────────────────────────────────────────
# Usage: create_release_notes "downloads" "SOURCE" "HANDLING" > /tmp/notes.txt
create_release_notes() {
    local source="$1"
    local handling="$2"

    printf '# Download from %s\n\n' "$source"
    printf '**Source:** %s  \n' "$source"
    printf '**Handling:** %s  \n' "$handling"
    printf '**Date:** %s\n\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    printf '## Files\n\n'
}
