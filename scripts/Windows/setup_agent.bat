@echo off
REM Printer SNMP Management - Agent Setup Script for Windows
REM This script will setup the agent component on a Windows system

echo =========================================================
echo Printer SNMP Management - Agent Setup for Windows
echo =========================================================

REM Process command line arguments
set SERVER_URL=http://localhost:3000/api
if not "%~1"=="" (
    set SERVER_URL=%~1
    echo Using server URL: %SERVER_URL%
) else (
    echo No server URL provided, using default: %SERVER_URL%
    echo You can specify a server URL: setup_agent.bat http://your-server:3000/api
)

REM Get the directory of this script
set SCRIPT_DIR=%~dp0
cd %SCRIPT_DIR%

REM Navigate to agent directory
cd /d "%SCRIPT_DIR%..\Agent"
set AGENT_DIR=%CD%
echo Setting up agent in: %AGENT_DIR%

REM Run the agent's setup script with the server URL
call setup_windows.bat %SERVER_URL%

echo =========================================================
echo Agent setup completed!
echo =========================================================
echo To run the agent: run_agent.bat
echo =========================================================

pause