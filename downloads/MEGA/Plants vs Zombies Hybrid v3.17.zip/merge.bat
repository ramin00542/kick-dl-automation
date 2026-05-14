@echo off
echo Reconstructing Plants vs Zombies Hybrid v3.17.zip ...
copy /b "Plants vs Zombies Hybrid v3.17.zip.part*" "Plants vs Zombies Hybrid v3.17.zip" > nul
if errorlevel 1 (
  echo ❌ Error: Failed to reconstruct Plants vs Zombies Hybrid v3.17.zip
  pause
  exit /b 1
)
echo ✅ File Plants vs Zombies Hybrid v3.17.zip reconstructed successfully.
pause
