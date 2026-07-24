#!/bin/bash
# =============================================================================
# process.sh — Process downloaded files (full / split / zip_split)
# =============================================================================
# Thin orchestrator. All strategy logic lives in lib/handling.sh.
#
# Depends on: common.sh, lib/handling.sh
# Input (env vars):
#   INPUT_HANDLING     — Handling mode. Canonical: full_file, split, zip_split,
#                        auto. Legacy aliases still accepted (full_file_no_split,
#                        normal, individual_split, zip, single_zip_split).
#   INPUT_SOURCE       — Source type (for target directory naming)
#   INPUT_SPLIT_SIZE   — Custom split size in MB (default: 90). ONLY used by
#                        split / zip_split modes when INPUT_SPLIT_MODE=custom.
#                        Ignored entirely by full_file.
#   INPUT_SPLIT_MODE   — auto (recommend size from file type) or custom
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/lib/handling.sh"

SRC_DIR="tmp_downloads"

# ── Resolve inputs ──────────────────────────────────────────────────────────
RAW_HANDLING="${INPUT_HANDLING:-auto}"
SOURCE="${INPUT_SOURCE:-direct}"
SPLIT_MB="${INPUT_SPLIT_SIZE:-90}"
SPLIT_MODE="${INPUT_SPLIT_MODE:-auto}"

HANDLING=$(normalize_handling "$RAW_HANDLING" "$SRC_DIR")

# Auto-detect a sensible split size (only matters for split / zip_split).
if [ "$SPLIT_MODE" = "auto" ] && [ "$HANDLING" != "full_file" ]; then
    DETECTED=$(detect_split_size "$SRC_DIR" "$SPLIT_MB")
    if [ "$DETECTED" != "$SPLIT_MB" ]; then
        # shellcheck disable=SC2012
        FIRST_FILE=$(ls -1 "$SRC_DIR" 2>/dev/null | head -1)
        log_info "Auto mode: detected .${FIRST_FILE##*.} → ${DETECTED}MB chunks"
        SPLIT_MB="$DETECTED"
    fi
fi

TARGET_BASE=$(get_target_base "$SOURCE")
mkdir -p "$TARGET_BASE"

# shellcheck disable=SC2012
FILE_COUNT=$(ls -1 "$SRC_DIR" 2>/dev/null | grep -vc '^$' || echo 0)
if [ "$FILE_COUNT" -eq 0 ]; then
    log_error "No files found in $SRC_DIR to process"
    exit 1
fi

log_step "Processing $FILE_COUNT file(s) | mode: $HANDLING | split: ${SPLIT_MB}MB"
log_info "Target: $TARGET_BASE"
if [ "$RAW_HANDLING" != "$HANDLING" ]; then
    log_info "(requested '$RAW_HANDLING' → resolved to '$HANDLING')"
fi

# ── Dispatch to the chosen strategy ─────────────────────────────────────────
case "$HANDLING" in
    full_file)
        handle_full_file "$SRC_DIR" "$TARGET_BASE" ;;
    split)
        handle_split "$SRC_DIR" "$TARGET_BASE" "$SPLIT_MB" ;;
    zip_split)
        handle_zip_split "$SRC_DIR" "$TARGET_BASE" "$SPLIT_MB" ;;
    *)
        log_error "Unresolved handling mode: $HANDLING"
        exit 1 ;;
esac

rm -rf "$SRC_DIR"

log_info "Processing complete!"
echo "Files in downloads directory:"
find downloads/ -type f -exec ls -lh {} \; 2>/dev/null || echo "  (no files)"
