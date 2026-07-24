#!/bin/bash
# =============================================================================
# process.sh — Process downloaded files (zip / split / preserve)
# =============================================================================
# Depends on: common.sh
# Input (env vars):
#   INPUT_HANDLING     — Handling mode: normal, zip, single_zip_split,
#                        full_file_no_split, individual_split
#   INPUT_SOURCE       — Source type (for target directory naming)
#   INPUT_SPLIT_SIZE   — Custom split size in MB (default: 90)
#   INPUT_SPLIT_MODE   — auto or custom (default: auto)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ── Validate inputs ─────────────────────────────────────────────────────────
HANDLING="${INPUT_HANDLING:-normal}"
SOURCE="${INPUT_SOURCE:-direct}"
SPLIT_MB="${INPUT_SPLIT_SIZE:-90}"
SPLIT_MODE="${INPUT_SPLIT_MODE:-auto}"

# normal = v1 behavior (keep original names, split if needed)
if [ "$HANDLING" = "normal" ]; then
    HANDLING="individual_split"
fi

# Auto-detect split size
if [ "$SPLIT_MODE" = "auto" ]; then
    DETECTED=$(detect_split_size "tmp_downloads" "$SPLIT_MB")
    if [ "$DETECTED" != "$SPLIT_MB" ]; then
        # shellcheck disable=SC2012
        FIRST_FILE=$(ls -1 tmp_downloads 2>/dev/null | head -1)
        EXT="${FIRST_FILE##*.}"
        log_info "Auto mode: detected .${EXT} → ${DETECTED}MB chunks"
        SPLIT_MB=$DETECTED
    fi
fi

LIMIT=$((SPLIT_MB * 1024 * 1024))
TARGET_BASE=$(get_target_base "$SOURCE")
mkdir -p "$TARGET_BASE"

# shellcheck disable=SC2012
FILE_COUNT=$(ls -1 tmp_downloads 2>/dev/null | grep -v '^$' | wc -l)
log_step "Processing $FILE_COUNT file(s) | mode: $HANDLING | split: ${SPLIT_MB}MB"
log_info "Target: $TARGET_BASE"

# ── single_zip_split: ZIP everything, split if needed ───────────────────────
if [ "$HANDLING" = "single_zip_split" ]; then
    log_info "Creating ZIP archive from all files"
    if [ "$FILE_COUNT" -eq 1 ]; then
        # shellcheck disable=SC2012
        SOURCE_FILE=$(ls tmp_downloads | head -1)
        zip -j "tmp_downloads/archive.zip" "tmp_downloads/$SOURCE_FILE"
        rm -f "tmp_downloads/$SOURCE_FILE"
    else
        zip -j "tmp_downloads/archive.zip" tmp_downloads/*
        find tmp_downloads -maxdepth 1 -type f ! -name 'archive.zip' -delete
    fi

    FINAL_FILE="tmp_downloads/archive.zip"
    SIZE=$(stat -c%s "$FINAL_FILE")
    TARGET_DIR="$TARGET_BASE/archive.zip"
    mkdir -p "$TARGET_DIR"

    if [ "$SIZE" -gt "$LIMIT" ]; then
        log_info "Splitting $(($SIZE / 1024 / 1024))MB into ${SPLIT_MB}MB chunks"            split -b "${SPLIT_MB}M" -d -a 2 "$FINAL_FILE" "$TARGET_DIR/archive.zip.part"
            generate_merge_scripts "$TARGET_DIR" "archive.zip"
    else
        cp "$FINAL_FILE" "$TARGET_DIR/archive.zip"
        log_info "File is under limit, stored as-is"
    fi
    rm -rf tmp_downloads

# ── full_file_no_split: Just copy, no processing ────────────────────────────
elif [ "$HANDLING" = "full_file_no_split" ]; then
    for FILE in tmp_downloads/*; do
        [ -f "$FILE" ] || continue
        BASENAME=$(basename "$FILE")
        TARGET_DIR="$TARGET_BASE/$BASENAME"
        mkdir -p "$TARGET_DIR"
        cp "$FILE" "$TARGET_DIR/$BASENAME"
    done
    rm -rf tmp_downloads
    log_info "Files preserved as-is (no split)"

# ── individual_split: Each file individually, split if needed ───────────────
elif [ "$HANDLING" = "individual_split" ]; then
    for FILE in tmp_downloads/*; do
        [ -f "$FILE" ] || continue
        SIZE=$(stat -c%s "$FILE")
        BASENAME_CLEAN=$(basename "$FILE")
        BASENAME_CLEAN="${BASENAME_CLEAN%%\?*}"
        TARGET_DIR="$TARGET_BASE/$BASENAME_CLEAN"
        mkdir -p "$TARGET_DIR"

        # Create .full copy for full upload mode
        cp "$FILE" "$TARGET_DIR/${BASENAME_CLEAN}.full"

        if [ "$SIZE" -gt "$LIMIT" ]; then
            log_info "Splitting $BASENAME_CLEAN ($(($SIZE / 1024 / 1024))MB)"
            split -b "${SPLIT_MB}M" -d -a 2 "$FILE" "$TARGET_DIR/${BASENAME_CLEAN}.part"
            generate_merge_scripts "$TARGET_DIR" "$BASENAME_CLEAN"
        else
            cp "$FILE" "$TARGET_DIR/$BASENAME_CLEAN"
        fi
    done
    generate_master_script "$TARGET_BASE"
    rm -rf tmp_downloads

# ── zip: ZIP all files, split if needed ─────────────────────────────────────
elif [ "$HANDLING" = "zip" ]; then
    ARCHIVE_NAME="tmp_downloads/archive_$(date +%Y%m%d_%H%M%S).zip"
    zip -j "$ARCHIVE_NAME" tmp_downloads/*
    find tmp_downloads -maxdepth 1 -type f ! -name '*.zip' -delete
    find tmp_downloads -maxdepth 1 -name 'archive_*.zip' -delete 2>/dev/null || true
    mv "$ARCHIVE_NAME" tmp_downloads/archive.zip

    FINAL_FILE="tmp_downloads/archive.zip"
    SIZE=$(stat -c%s "$FINAL_FILE")
    TARGET_DIR="$TARGET_BASE/archive.zip"
    mkdir -p "$TARGET_DIR"

    if [ "$SIZE" -gt "$LIMIT" ]; then
        log_info "Splitting archive into ${SPLIT_MB}MB chunks"            split -b "${SPLIT_MB}M" -d -a 2 "$FINAL_FILE" "$TARGET_DIR/archive.zip.part"
            generate_merge_scripts "$TARGET_DIR" "archive.zip"
    else
        cp "$FINAL_FILE" "$TARGET_DIR/archive.zip"
    fi
    rm -rf tmp_downloads

else
    log_error "Unknown handling mode: $HANDLING"
    exit 1
fi

log_info "Processing complete!"
echo "Files in downloads directory:"
find downloads/ -type f -exec ls -lh {} \; 2>/dev/null || echo "  (no files)"
