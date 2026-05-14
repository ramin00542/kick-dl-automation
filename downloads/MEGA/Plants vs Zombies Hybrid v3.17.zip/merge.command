#!/bin/bash
cd "$(dirname "$0")"
echo "Reconstructing Plants vs Zombies Hybrid v3.17.zip ..."
cat "Plants vs Zombies Hybrid v3.17.zip.part"* > "Plants vs Zombies Hybrid v3.17.zip"
if [ $? -eq 0 ]; then
  echo "✅ File Plants vs Zombies Hybrid v3.17.zip reconstructed successfully."
else
  echo "❌ Error: Failed to reconstruct Plants vs Zombies Hybrid v3.17.zip"
  exit 1
fi
echo "Press any key to close..."
read -n 1
