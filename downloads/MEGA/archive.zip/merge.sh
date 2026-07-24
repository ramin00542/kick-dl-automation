#!/bin/bash
cd "$(dirname "$0")"
echo "Reconstructing archive.zip ..."
cat "archive.zip.part"* > "archive.zip"
echo "Done. File restored: archive.zip"
