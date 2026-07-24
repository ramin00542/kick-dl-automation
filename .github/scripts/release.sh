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

echo "Files to release:"
echo "$RELEASE_FILES" | while IFS= read -r F; do
    F_SIZE=$(stat -c%s "$F" 2>/dev/null || echo 0)
    F_SIZE_MB=$((F_SIZE / 1024 / 1024))
    log_info "  $(basename "$F") (${F_SIZE_MB}MB)"
done

# Create release notes
NOTES_FILE=$(mktemp)
create_release_notes "$SOURCE" "$HANDLING" > "$NOTES_FILE"
echo "$RELEASE_FILES" | while IFS= read -r F; do
    F_SIZE=$(stat -c%s "$F" 2>/dev/null || echo 0)
    F_SIZE_MB=$((F_SIZE / 1024 / 1024))
    F_NAME=$(basename "$F")
    printf -- '- \`%s\` (%dMB)\n' "$F_NAME" "$F_SIZE_MB" >> "$NOTES_FILE"
done
printf '\n---\n*Automated release by GitHub Actions*\n' >> "$NOTES_FILE"

# Build file array for safe filename handling
RELEASE_ARGS=()
while IFS= read -r F; do
    RELEASE_ARGS+=("$F")
done <<< "$RELEASE_FILES"

# Create the release
gh release create "$RELEASE_TAG" \
    --title "Download from $SOURCE - $(date +%Y-%m-%d)" \
    --notes-file "$NOTES_FILE" \
    -- "${RELEASE_ARGS[@]}"

rm -f "$NOTES_FILE"
log_info "Release created: https://github.com/${GITHUB_REPOSITORY}/releases/tag/$RELEASE_TAG"
