#!/bin/bash
# =============================================================================
# lib/handling.sh — File-handling mode logic (normalize + strategies)
# =============================================================================
# Sourced by process.sh. Depends on common.sh being sourced first
# (uses log_*, generate_merge_scripts, generate_master_script).
#
# Canonical handling modes (user-facing):
#   full_file   → copy as-is, NEVER split      (best for GitHub Releases, <2GB)
#   split       → keep raw file, split if large
#   zip_split   → ZIP everything, split if large
#   auto        → pick full_file for <2GB single file, else split
#
# Legacy aliases (kept for backward compatibility with old workflows / commits):
#   full_file_no_split → full_file
#   normal, individual_split → split
#   zip, single_zip_split    → zip_split
# =============================================================================

# GitHub Release single-asset hard limit is 2GB. Files at or below this can be
# uploaded whole (no split needed) as a Release asset.
RELEASE_ASSET_LIMIT_BYTES=$((2 * 1024 * 1024 * 1024))

# ── Normalize a handling mode to its canonical name ─────────────────────────
# Usage: HANDLING=$(normalize_handling "$RAW_HANDLING" "tmp_downloads")
normalize_handling() {
    local raw="${1:-auto}"
    local src_dir="${2:-tmp_downloads}"

    case "$raw" in
        full_file|full_file_no_split)
            echo "full_file" ;;
        split|normal|individual_split)
            echo "split" ;;
        zip_split|zip|single_zip_split)
            echo "zip_split" ;;
        auto)
            resolve_auto_handling "$src_dir" ;;
        *)
            log_warn "Unknown handling mode '$raw', falling back to 'split'" >&2
            echo "split" ;;
    esac
}

# ── auto: decide the best mode based on the downloaded files ────────────────
# Single file that fits in a Release asset → full_file (whole, no split).
# Otherwise → split (chunked so it can live in the repo / be reassembled).
resolve_auto_handling() {
    local src_dir="${1:-tmp_downloads}"
    local count
    # shellcheck disable=SC2012
    count=$(ls -1 "$src_dir" 2>/dev/null | grep -vc '^$' || echo 0)

    if [ "$count" -eq 1 ]; then
        local file size
        # shellcheck disable=SC2012
        file="$src_dir/$(ls -1 "$src_dir" | head -1)"
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        if [ "$size" -le "$RELEASE_ASSET_LIMIT_BYTES" ]; then
            log_info "auto: single file ≤2GB → full_file (no split)" >&2
            echo "full_file"
            return
        fi
    fi
    log_info "auto: multiple files or >2GB → split" >&2
    echo "split"
}

# ── Strategy: full_file — copy each file untouched, never split ─────────────
handle_full_file() {
    local src_dir="$1" target_base="$2"
    local file basename target_dir
    for file in "$src_dir"/*; do
        [ -f "$file" ] || continue
        basename=$(basename "$file")
        basename="${basename%%\?*}"
        target_dir="$target_base/$basename"
        mkdir -p "$target_dir"
        cp "$file" "$target_dir/$basename"
    done
    log_info "Files preserved as-is (no split)"
}

# ── Strategy: split — each file individually, split if over the limit ───────
handle_split() {
    local src_dir="$1" target_base="$2" split_mb="$3"
    local limit=$((split_mb * 1024 * 1024))
    local file size basename target_dir
    for file in "$src_dir"/*; do
        [ -f "$file" ] || continue
        size=$(stat -c%s "$file")
        basename=$(basename "$file")
        basename="${basename%%\?*}"
        target_dir="$target_base/$basename"
        mkdir -p "$target_dir"

        # Keep a whole copy for "full" upload mode.
        cp "$file" "$target_dir/${basename}.full"

        if [ "$size" -gt "$limit" ]; then
            log_info "Splitting $basename ($((size / 1024 / 1024))MB) into ${split_mb}MB chunks"
            split -b "${split_mb}M" -d -a 2 "$file" "$target_dir/${basename}.part"
            generate_merge_scripts "$target_dir" "$basename"
        else
            cp "$file" "$target_dir/$basename"
        fi
    done
    generate_master_script "$target_base"
}

# ── Strategy: zip_split — ZIP everything into one archive, split if large ────
handle_zip_split() {
    local src_dir="$1" target_base="$2" split_mb="$3"
    local limit=$((split_mb * 1024 * 1024))
    local count archive_name archive_basename size target_dir

    # shellcheck disable=SC2012
    count=$(ls -1 "$src_dir" 2>/dev/null | grep -vc '^$' || echo 0)

    if [ "$count" -eq 1 ]; then
        local source_file source_basename
        # shellcheck disable=SC2012
        source_file="$(ls -1 "$src_dir" | head -1)"
        source_basename=$(basename "$source_file")
        source_basename="${source_basename%%\?*}"
        if [[ "$source_basename" == *.zip ]]; then
            archive_name="$src_dir/$source_basename"
        else
            archive_name="$src_dir/${source_basename}.zip"
            zip -j "$archive_name" "$src_dir/$source_file"
            rm -f "$src_dir/$source_file"
        fi
    else
        archive_name="$src_dir/archive.zip"
        zip -j "$archive_name" "$src_dir"/*
        find "$src_dir" -maxdepth 1 -type f ! -name 'archive.zip' -delete
    fi

    archive_basename=$(basename "$archive_name")
    size=$(stat -c%s "$archive_name")
    target_dir="$target_base/$archive_basename"
    mkdir -p "$target_dir"

    # Keep a whole copy for "full" upload mode.
    cp "$archive_name" "$target_dir/${archive_basename}.full"

    if [ "$size" -gt "$limit" ]; then
        log_info "Splitting $archive_basename ($((size / 1024 / 1024))MB) into ${split_mb}MB chunks"
        split -b "${split_mb}M" -d -a 2 "$archive_name" "$target_dir/${archive_basename}.part"
        generate_merge_scripts "$target_dir" "$archive_basename"
    else
        cp "$archive_name" "$target_dir/$archive_basename"
        log_info "Archive is under limit, stored as-is"
    fi
    generate_master_script "$target_base"
}
