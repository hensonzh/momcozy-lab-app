@echo off
echo Starting build process...
npm run build && npx cap sync android
if %errorlevel% neq 0 (
    echo Build failed!
    exit /b %errorlevel%
)

echo Build and sync successfully!