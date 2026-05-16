@echo off
echo Reconstructing 3.6.1_android.zip ...
copy /b "3.6.1_android.zip.part*" "3.6.1_android.zip" > nul
if errorlevel 1 (
  echo ❌ Error
  pause
  exit /b 1
)
echo ✅ File 3.6.1_android.zip reconstructed
pause
