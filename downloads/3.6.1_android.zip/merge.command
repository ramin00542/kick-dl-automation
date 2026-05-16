#!/bin/bash
cd "$(dirname "$0")"
cat "3.6.1_android.zip.part"* > "3.6.1_android.zip"
echo "✅ 3.6.1_android.zip reconstructed"
read -p "Press any key..."
