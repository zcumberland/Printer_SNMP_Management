@echo off
REM Printer SNMP Management - Server Run Script for Windows

echo =========================================================
echo Printer SNMP Management - Starting Server
echo =========================================================

REM Navigate to server directory
cd /d "%~dp0..\Server"
set SERVER_DIR=%CD%
echo Starting server from: %SERVER_DIR%

REM Check for Node.js
node --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Node.js is not installed or not in PATH.
    echo Please run the setup script first: setup_server.bat
    pause
    exit /b 1
)

REM Check if node_modules exists
if not exist "node_modules\" (
    echo Node modules not found. Running npm install...
    call npm install
)

REM Start the server
echo Starting the server...
call npm start

REM This script should not normally reach here unless the server exits
echo Server has stopped.
pause