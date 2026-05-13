
name: Download from MEGA & Save to Repo

on:
  workflow_dispatch:
    inputs:
      mega_link:
        description: 'لینک فایل یا پوشه در MEGA (چندتا لینک با فاصله مجاز است)'
        required: true
        type: string
      mode:
        description: 'حالت دانلود (normal یا zip)'
        required: false
        default: 'normal'
        type: choice
        options:
          - normal
          - zip
  push:
    branches:
      - "**"

jobs:
  save-file:
    if: |
      github.event_name == 'workflow_dispatch' ||
      contains(github.event.head_commit.message, 'mega:') ||
      contains(github.event.head_commit.message, 'mega-zip:')
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Install megatools
        run: sudo apt-get update && sudo apt-get install -y megatools

      - name: Extract URLs and download files
        run: |
          MSG=$(git log -1 --pretty=%B)
          echo "Commit message: $MSG"

          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            MODE="${{ github.event.inputs.mode }}"
            URLS="${{ github.event.inputs.mega_link }}"
            echo "Mode: $MODE (manual trigger)"
          else
            if echo "$MSG" | grep -qP 'mega-zip:'; then
              MODE="zip"
              URLS=$(echo "$MSG" | grep -oP 'mega-zip:\s*\K.*')
            elif echo "$MSG" | grep -qP 'mega:'; then
              MODE="normal"
              URLS=$(echo "$MSG" | grep -oP 'mega:\s*\K.*')
            else
              echo "❌ No mega command found in commit message"
              exit 1
            fi
            echo "Mode: $MODE (from commit)"
          fi

          mkdir -p tmp_downloads downloads/MEGA

          # دانلود همه لینک‌ها
          for URL in $URLS; do
            echo "⬇️ Downloading $URL using megatools"
            cd tmp_downloads
            if ! megatools dl "$URL"; then
              echo "❌ Download failed for $URL"
              exit 1
            fi
            cd ..
          done

          # بیرون کشیدن فایل‌ها از زیرپوشه‌ها (برای پوشه‌های MEGA)
          find tmp_downloads -type f -exec mv {} tmp_downloads/ \;
          rm -rf tmp_downloads/*/

          # حالت zip: فقط یک آرشیو نهایی نگه داشته شود
          if [ "$MODE" = "zip" ]; then
            ARCHIVE_NAME="tmp_downloads/archive_$(date +%Y%m%d_%H%M%S).zip"
            zip -j "$ARCHIVE_NAME" tmp_downloads/*
            rm -f tmp_downloads/*
            mv "$ARCHIVE_NAME" tmp_downloads/archive.zip
          fi

          # پردازش هر فایل دانلود شده (تقسیم یا کپی و مرتب‌سازی در downloads/MEGA)
          for FILE in tmp_downloads/*; do
            [ -f "$FILE" ] || continue
            SIZE=$(stat -c%s "$FILE")
            LIMIT=$((90 * 1024 * 1024))
            BASENAME=$(basename "$FILE")

            TARGET_DIR="downloads/MEGA/$BASENAME"
            mkdir -p "$TARGET_DIR"

            if [ "$SIZE" -gt "$LIMIT" ]; then
              echo "✂️ $BASENAME is $(( SIZE / 1024 / 1024 ))MB — splitting into 90MB chunks in $TARGET_DIR"
              split -b 90M -d -a 2 "$FILE" "$TARGET_DIR/${BASENAME}.part"
              PARTS=$(ls "$TARGET_DIR/${BASENAME}.part"* | wc -l)
              echo "✅ Created $PARTS parts"

              # اسکریپت merge مخصوص این فایل
              printf '#!/bin/bash\n# بازسازی فایل %s از روی بخش‌ها\ncat "%s.part"* > "%s"\necho "✅ فایل %s بازسازی شد"\n' "$BASENAME" "$BASENAME" "$BASENAME" "$BASENAME" > "$TARGET_DIR/${BASENAME}_merge.sh"
              chmod +x "$TARGET_DIR/${BASENAME}_merge.sh"
            else
              echo "📄 Copying $BASENAME to $TARGET_DIR"
              cp "$FILE" "$TARGET_DIR/$BASENAME"
            fi
          done

          # --- ساخت اسکریپت اصلی برای بازسازی یک‌کلیک همه فایل‌ها ---
          MASTER_SCRIPT="downloads/MEGA/reconstruct_all.sh"
          printf '#!/bin/bash\n' > "$MASTER_SCRIPT"
          printf '# بازسازی همه فایل‌های تقسیم شده در این پوشه\n' >> "$MASTER_SCRIPT"
          printf 'set -e\n' >> "$MASTER_SCRIPT"
          printf 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n' >> "$MASTER_SCRIPT"
          printf 'cd "$SCRIPT_DIR"\n' >> "$MASTER_SCRIPT"
          printf 'for dir in */; do\n' >> "$MASTER_SCRIPT"
          printf '    if [ -d "$dir" ]; then\n' >> "$MASTER_SCRIPT"
          printf '        merge_script=$(find "$dir" -maxdepth 1 -name "*_merge.sh" -type f | head -1)\n' >> "$MASTER_SCRIPT"
          printf '        if [ -n "$merge_script" ]; then\n' >> "$MASTER_SCRIPT"
          printf '            echo "🔄 بازسازی در $dir"\n' >> "$MASTER_SCRIPT"
          printf '            (cd "$dir" && bash "$(basename "$merge_script")")\n' >> "$MASTER_SCRIPT"
          printf '        fi\n' >> "$MASTER_SCRIPT"
          printf '    fi\n' >> "$MASTER_SCRIPT"
          printf 'done\n' >> "$MASTER_SCRIPT"
          printf 'echo "✅ همه فایل‌ها با موفقیت بازسازی شدند"\n' >> "$MASTER_SCRIPT"
          chmod +x "$MASTER_SCRIPT"

          rm -rf tmp_downloads

      - name: Commit & Push (single commit)
        run: |
          BRANCH="${GITHUB_REF_NAME}"
          git config user.name "github-actions"
          git config user.email "github-actions@github.com"

          git add downloads/
          if git diff --cached --quiet; then
            echo "Nothing to commit"
            exit 0
          fi

          git commit -m "Add files from MEGA ($MODE mode) [skip ci]"
          git pull --rebase origin "$BRANCH"
          git push origin HEAD:"$BRANCH"

          echo "🎉 All files pushed successfully in downloads/MEGA/ organized by file name"
