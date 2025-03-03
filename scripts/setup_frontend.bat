@echo off
REM Printer SNMP Management - Frontend Setup Script for Windows

echo =========================================================
echo Printer SNMP Management - Frontend Setup
echo =========================================================

REM Check if Node.js is installed
node --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Node.js is not installed or not in PATH.
    echo Please install Node.js from https://nodejs.org/
    echo Make sure to select "Add to PATH" during installation.
    echo After installing Node.js, run this script again.
    exit /b 1
) else (
    echo Node.js is already installed: 
    node --version
)

REM Navigate to frontend directory
cd /d "%~dp0..\FrontEnd"
set FRONTEND_DIR=%CD%
echo Setting up frontend in: %FRONTEND_DIR%

REM Install npm dependencies
echo Installing npm dependencies...
call npm install

REM Check if package.json exists and has proxy configuration
findstr "\"proxy\":" package.json >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Adding proxy configuration to package.json...
    
    REM Using PowerShell to modify JSON (built into Windows 10/11)
    powershell -Command "(Get-Content package.json -Raw | ConvertFrom-Json) | Add-Member -Name 'proxy' -Value 'http://localhost:3000' -MemberType NoteProperty -Force | ConvertTo-Json -Depth 100 | Set-Content package.json"
    
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to modify package.json with PowerShell.
        echo NOTICE: Please manually add the following line to your package.json:
        echo   "proxy": "http://localhost:3000"
        echo This should be added inside the root JSON object.
    ) else (
        echo Successfully added proxy configuration.
    )
)

REM Create startup scripts
echo Creating startup scripts...

REM Create Windows batch script for development
(
    echo @echo off
    echo cd /d "%%~dp0"
    echo echo Starting frontend in development mode...
    echo call npm start
) > run_dev.bat

REM Create Windows batch script for building
(
    echo @echo off
    echo cd /d "%%~dp0"
    echo echo Building frontend for production...
    echo call npm run build
    echo echo Build complete. Files are in the 'build' directory.
) > build.bat

echo =========================================================
echo Frontend setup complete!
echo.
echo For development mode:
echo   run_dev.bat
echo   This will start the development server at http://localhost:3000
echo.
echo To build for production:
echo   build.bat
echo   This will create a production build in the 'build' directory
echo.
echo NOTE: Make sure the backend server is running before using the frontend.
echo =========================================================

pause