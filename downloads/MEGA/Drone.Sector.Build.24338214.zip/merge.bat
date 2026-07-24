@echo off
title Merging Drone.Sector.Build.24338214.zip ...
echo Reconstructing Drone.Sector.Build.24338214.zip ...
copy /b "Drone.Sector.Build.24338214.zip.part*" "Drone.Sector.Build.24338214.zip" > nul
if errorlevel 1 (
  echo ERROR: Merge failed!
  pause
  exit /b 1
)
echo Done. File restored: Drone.Sector.Build.24338214.zip
pause
