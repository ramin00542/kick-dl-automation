@echo off
echo Reconstructing PvZ.Fusion.3.6.1.Multi-lang.Release.by.Blooms.zip ...
copy /b "PvZ.Fusion.3.6.1.Multi-lang.Release.by.Blooms.zip.part*" "PvZ.Fusion.3.6.1.Multi-lang.Release.by.Blooms.zip" > nul
if errorlevel 1 (
  echo ❌ Error
  pause
  exit /b 1
)
echo ✅ File PvZ.Fusion.3.6.1.Multi-lang.Release.by.Blooms.zip reconstructed
pause
