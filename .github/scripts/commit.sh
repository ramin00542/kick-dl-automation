#!/bin/bash
# =============================================================================
# commit.sh — Commit & push small files to the repository
# =============================================================================
# Depends on: common.sh
# Input (env vars):
#   INPUT_SOURCE       — Source type (for commit message)
#   INPUT_HANDLING     — Handling mode (for commit message)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ── Validate inputs ─────────────────────────────────────────────────────────
SOURCE="${INPUT_SOURCE:-unknown}"
HANDLING="${INPUT_HANDLING:-unknown}"

# GitHub hard-blocks any single file >100MB on push. Use a safe ceiling well
# under that so a large auto-detected split size can never cause a failed push.
# (This is independent of the split chunk size used during processing.)
COMMIT_MAX_MB=95

log_step "Preparing commit"

# GitHub Actions env vars (with defaults for local testing)
GITHUB_REF_NAME="${GITHUB_REF_NAME:-main}"

# Configure git
git config user.name "github-actions"
git config user.email "github-actions@github.com"

# Remove sensitive files
clean_sensitive_files "downloads"

# Show files found
echo "Files in downloads/ (up to 20):"
find downloads/ -type f 2>/dev/null | head -20 || echo "  (no files)"

# Add workflow-generated files (force-add since they're in .gitignore)
git add -f upload_results.txt upload_results.json logs/ 2>/dev/null || true

# Add small download files only (exclude .part*, .full, and large files)
find downloads/ -type f -size -"${COMMIT_MAX_MB}"M \
    ! -name '*.part*' ! -name '*.full' \
    -print0 2>/dev/null | xargs -0 git add 2>/dev/null || true

# Check if there's anything to commit
if git diff --cached --quiet; then
    log_info "No small files to commit (large files stored as Release/Artifacts)"
    exit 0
fi

log_info "Changes detected, committing..."
git commit -m "Download results from ${SOURCE} [skip ci]"
git pull --rebase origin "$GITHUB_REF_NAME" 2>/dev/null || log_warn "Rebase failed"
git push 2>/dev/null || log_warn "Push failed"
log_info "Commit successful"
