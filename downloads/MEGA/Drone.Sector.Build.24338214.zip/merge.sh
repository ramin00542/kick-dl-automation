#!/bin/bash
cd "$(dirname "$0")"
echo "Reconstructing Drone.Sector.Build.24338214.zip ..."
cat "Drone.Sector.Build.24338214.zip.part"* > "Drone.Sector.Build.24338214.zip"
echo "Done. File restored: Drone.Sector.Build.24338214.zip"
