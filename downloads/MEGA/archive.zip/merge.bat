@echo off
title Merging archive.zip ...
echo Reconstructing archive.zip ...
copy /b "archive.zip.part*" "archive.zip" > nul
if errorlevel 1 (
  echo ERROR: Merge failed!
  pause
  exit /b 1
)
echo Done. File restored: archive.zip
pause
