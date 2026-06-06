#!/bin/bash
cd "$(dirname "$0")"
cat "archive.zip.part"* > "archive.zip"
echo "✅ بازسازی شد"
