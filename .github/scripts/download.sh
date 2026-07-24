#!/bin/bash
# =============================================================================
# download.sh — Download files from various sources
# =============================================================================
# Depends on: common.sh
# Input (env vars):
#   INPUT_SOURCE     — Source type: direct, mega, pixeldrain
#   INPUT_URLS       — Space-separated list of download URLs
#   INPUT_LINK_PASS  — Link password (for HTTP Basic Auth or MEGA)
#   MEGA_SECRET_PASS — MEGA link password from secrets
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ── Validate inputs ─────────────────────────────────────────────────────────
INPUT_SOURCE="${INPUT_SOURCE:-}"
INPUT_URLS="${INPUT_URLS:-}"
INPUT_LINK_PASS="${INPUT_LINK_PASS:-}"
MEGA_SECRET_PASS="${MEGA_SECRET_PASS:-}"

if [ -z "$INPUT_SOURCE" ]; then
    log_error "INPUT_SOURCE is not set"
    exit 1
fi
if [ -z "$INPUT_URLS" ]; then
    log_error "INPUT_URLS is not set"
    exit 1
fi

# ── Main ────────────────────────────────────────────────────────────────────
log_step "Starting download from source: $INPUT_SOURCE"
log_info "URL count: $(echo "$INPUT_URLS" | wc -w)"

mkdir -p tmp_downloads downloads
log_info "Created tmp_downloads and downloads directories"

# Word splitting is intentional for space-separated URLs
# shellcheck disable=SC2086
for URL in $INPUT_URLS; do
    log_info "Downloading: ${URL:0:80}..."
    pushd tmp_downloads > /dev/null || { log_error "pushd failed"; exit 1; }

    case "$INPUT_SOURCE" in
        mega)
            log_info "MEGA link — using megatools"
            MEGA_PASS="$INPUT_LINK_PASS"
            if [ -z "$MEGA_PASS" ] && [ -n "${MEGA_SECRET_PASS:-}" ]; then
                MEGA_PASS="$MEGA_SECRET_PASS"
            fi
            if [ -n "$MEGA_PASS" ]; then
                megatools dl --password "$MEGA_PASS" "$URL"
            else
                megatools dl "$URL"
            fi
            ;;

        pixeldrain)
            log_info "Pixeldrain link — using API"
            FILE_ID=$(echo "$URL" | grep -oP 'pixeldrain\.com/(?:u|api/file)/\K[a-zA-Z0-9]+')
            if [ -z "$FILE_ID" ]; then
                log_error "Could not extract file ID from URL: $URL"
                exit 1
            fi
            log_info "File ID: $FILE_ID"
            curl -LJO --fail --retry 3 --retry-delay 5 \
                --connect-timeout 30 --max-time 21600 \
                "https://pixeldrain.com/api/file/$FILE_ID"
            ;;

        direct)
            if [ -n "$INPUT_LINK_PASS" ] && [[ "$INPUT_LINK_PASS" == *:* ]]; then
                AUTH_USER="${INPUT_LINK_PASS%%:*}"
                AUTH_PASS="${INPUT_LINK_PASS#*:}"
                log_info "Using HTTP Basic Auth (user: $AUTH_USER)"
                curl -L -u "$AUTH_USER:$AUTH_PASS" -O \
                    --fail --retry 3 --retry-delay 5 \
                    --connect-timeout 30 --max-time 21600 \
                    "$URL"
            else
                curl -L -O \
                    --fail --retry 3 --retry-delay 5 \
                    --connect-timeout 30 --max-time 21600 \
                    "$URL"
            fi
            ;;

        *)
            log_error "Unknown source: $INPUT_SOURCE"
            exit 1
            ;;
    esac

    popd > /dev/null || { log_warn "popd failed"; break; }
done

# Flatten nested directories safely
flatten_directories "tmp_downloads"

log_info "Downloads complete"
echo "Files in tmp_downloads:"
ls -lh tmp_downloads/ 2>/dev/null || echo "  (no files)"
