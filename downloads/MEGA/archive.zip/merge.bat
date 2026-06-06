@echo off
echo در حال بازسازی archive.zip ...
copy /b "archive.zip.part*" "archive.zip" > nul
if errorlevel 1 ( echo ❌ خطا & pause & exit /b 1 )
echo ✅ بازسازی شد.
pause
