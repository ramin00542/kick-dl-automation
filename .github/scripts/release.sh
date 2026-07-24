#!/bin/bash
# =============================================================================
# release.sh — Create GitHub Release with processed files
# =============================================================================
# Depends on: common.sh
# Input (env vars):
#   INPUT_SOURCE       — Source type (for release notes)
#   INPUT_HANDLING     — Handling mode (for release notes)
#   GH_TOKEN           — GitHub token for gh CLI
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ── Validate inputs ─────────────────────────────────────────────────────────
SOURCE="${INPUT_SOURCE:-unknown}"
HANDLING="${INPUT_HANDLING:-unknown}"
GH_TOKEN="${GH_TOKEN:-}"

if [ -z "$GH_TOKEN" ]; then
    log_error "GH_TOKEN is not set"
    exit 1
fi

# Check if there are any files to release
RELEASE_FILES=$(find downloads -type f \
    ! -name 'password.txt' \
    ! -name 'reconstruct_all.sh' \
    ! -name '*.full' 2>/dev/null)

if [ -z "$RELEASE_FILES" ]; then
    log_warn "No files found to release, skipping"
    exit 0
fi

RELEASE_TAG="release-$(date +%Y%m%d-%H%M%S)"
log_step "Creating GitHub Release: $RELEASE_TAG"

# Count total files and check for potential duplicate basenames
FILE_COUNT=0
DUPE_CHECK=""
while IFS= read -r F; do
    FILE_COUNT=$((FILE_COUNT + 1))
done <<< "$RELEASE_FILES"

log_info "Found $FILE_COUNT file(s) to release"

if [ "$FILE_COUNT" -eq 0 ]; then
    log_warn "No files found for release"
    exit 0
fi

# Create release notes
NOTES_FILE=$(mktemp)
create_release_notes "$SOURCE" "$HANDLING" > "$NOTES_FILE"
while IFS= read -r F; do
    [ -z "$F" ] && continue
    F_SIZE=$(stat -c%s "$F" 2>/dev/null || echo 0)
    F_SIZE_MB=$((F_SIZE / 1024 / 1024))
    F_NAME=$(basename "$F")
    printf -- '- \`%s\` (%dMB)\n' "$F_NAME" "$F_SIZE_MB" >> "$NOTES_FILE"
done <<< "$RELEASE_FILES"
printf '\n---\n*Automated release by GitHub Actions*\n' >> "$NOTES_FILE"

# Build file list for release (gh handles unique basenames by using path)
RELEASE_ARGS=()
while IFS= read -r F; do
    [ -z "$F" ] && continue
    RELEASE_ARGS+=("$F")
done <<< "$RELEASE_FILES"

# First attempt: create release with all files at once
log_info "Creating release and uploading assets..."
if gh release create "$RELEASE_TAG" \
    --title "Download from $SOURCE - $(date +%Y-%m-%d)" \
    --notes-file "$NOTES_FILE" \
    -- "${RELEASE_ARGS[@]}" 2>/dev/null; then
    log_info "Release created successfully"
else
    log_warn "Bulk upload failed (likely duplicate asset names), trying individual uploads..."
    
    # Create release without assets first
    gh release create "$RELEASE_TAG" \
        --title "Download from $SOURCE - $(date +%Y-%m-%d)" \
        --notes-file "$NOTES_FILE" 2>/dev/null || true
    
    # Upload files one by one, skipping duplicates
    while IFS= read -r F; do
        [ -z "$F" ] && continue
        F_NAME=$(basename "$F")
        log_info "Uploading: $F_NAME"
        if gh release upload "$RELEASE_TAG" "$F" --clobber 2>/dev/null; then
            log_info "  ✓ $F_NAME uploaded"
        else
            log_warn "  ⚠ Could not upload $F_NAME, skipping"
        fi
    done <<< "$RELEASE_FILES"
fi

rm -f "$NOTES_FILE"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-unknown/repo}"
RELEASE_URL="https://github.com/${GITHUB_REPOSITORY}/releases/tag/$RELEASE_TAG"
log_info "Release: $RELEASE_URL"
