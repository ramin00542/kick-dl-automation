#!/bin/bash
# =============================================================================
# upload.sh — Upload processed files to target file hosting sites
# =============================================================================
# Depends on: common.sh
# Input (env vars):
#   INPUT_TARGET_SITES — Comma-separated list of target upload sites
#   INPUT_UPLOAD_MODE  — 'full' (upload .full files) or 'parts'
#   SITE_CREDS         — Credentials for upload sites (from secrets)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ── Validate inputs ─────────────────────────────────────────────────────────
TARGET_SITES="${INPUT_TARGET_SITES:-}"
UPLOAD_MODE="${INPUT_UPLOAD_MODE:-full}"
SITE_CREDS="${SITE_CREDS:-}"

if [ -z "$TARGET_SITES" ]; then
    log_warn "No target sites specified, skipping upload"
    exit 0
fi

log_step "Uploading to sites: $TARGET_SITES"
log_info "Upload mode: $UPLOAD_MODE"

UPLOAD_FAILURES=0

upload_file() {
    local file="$1"
    log_info "Uploading: $file"
    if python upload_to_sites.py \
        --file "$file" \
        --sites "$TARGET_SITES" \
        --creds "$SITE_CREDS"; then
        log_info "✓ Upload successful: $file"
    else
        log_warn "⚠ Upload failed for $file, continuing..."
        UPLOAD_FAILURES=$((UPLOAD_FAILURES + 1))
    fi
}

if [ "$UPLOAD_MODE" = "full" ]; then
    # Upload ALL .full files
    # shellcheck disable=SC2140
    if find downloads -type f -name "*.full" -print0 2>/dev/null | grep -q .; then
        while IFS= read -r -d '' FILE; do
            upload_file "$FILE"
        done < <(find downloads -type f -name "*.full" -print0)
    else
        # Fallback: upload non-script, non-part files
        log_info "No .full files found, uploading original files"
        while IFS= read -r -d '' FILE; do
            upload_file "$FILE"
        done < <(find downloads -type f \
            ! -name '*.bat' ! -name '*.command' ! -name '*.sh' \
            ! -name 'password.txt' ! -name 'reconstruct_all.sh' \
            ! -name '*.full' -print0 2>/dev/null)
    fi
else
    # Upload part files
    log_info "Uploading part files..."
    while IFS= read -r -d '' PART; do
        upload_file "$PART"
    done < <(find downloads -type f -name '*.part*' -print0 2>/dev/null | sort -z)
fi

if [ "$UPLOAD_FAILURES" -gt 0 ]; then
    log_warn "$UPLOAD_FAILURES upload(s) failed (others succeeded)"
else
    log_info "All uploads completed"
fi
