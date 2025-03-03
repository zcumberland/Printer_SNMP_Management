@echo off
REM Printer SNMP Management - Frontend Run Script for Windows

echo =========================================================
echo Printer SNMP Management - Starting Frontend
echo =========================================================

REM Navigate to frontend directory
cd /d "%~dp0..\FrontEnd"
set FRONTEND_DIR=%CD%
echo Starting frontend from: %FRONTEND_DIR%

REM Check for Node.js
node --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Node.js is not installed or not in PATH.
    echo Please run the setup script first: setup_frontend.bat
    pause
    exit /b 1
)

REM Check if node_modules exists
if not exist "node_modules\" (
    echo Node modules not found. Running npm install...
    call npm install
)

REM Start the development server
echo Starting the frontend development server...
call npm start

REM This script should not normally reach here unless the server exits
echo Frontend development server has stopped.
pause