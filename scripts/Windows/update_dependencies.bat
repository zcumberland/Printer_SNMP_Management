@echo off
REM This script updates dependencies for both Server and Frontend components

echo =========================================================
echo Printer SNMP Management - Dependency Update Script
echo =========================================================

REM Get the root directory of the project
set SCRIPT_DIR=%~dp0
set ROOT_DIR=%SCRIPT_DIR%..\..

REM Update Server dependencies
echo Updating Server dependencies...
cd /d "%ROOT_DIR%\Server"
call npm install
call npm update
call npm prune

REM Update Frontend dependencies
echo Updating Frontend dependencies...
cd /d "%ROOT_DIR%\FrontEnd"
call npm install
call npm update
call npm prune

echo =========================================================
echo Dependencies updated successfully!
echo =========================================================

pause