#!/bin/bash
cd "$(dirname "$0")"
echo "Reconstructing archive.zip ..."
cat "archive.zip.part"* > "archive.zip"
echo "Done. File restored: archive.zip"
read -n 1 -p "Press any key to exit..."
