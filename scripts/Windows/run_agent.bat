@echo off
REM Printer SNMP Management - Agent Run Script for Windows

echo =========================================================
echo Printer SNMP Management - Starting Agent
echo =========================================================

REM Navigate to agent directory
cd /d "%~dp0..\Agent"
set AGENT_DIR=%CD%
echo Starting agent from: %AGENT_DIR%

REM Check for Python
python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Python is not installed or not in PATH.
    echo Please run the setup script first: setup_agent.bat
    pause
    exit /b 1
)

REM Check if virtual environment exists
if not exist "venv\" (
    echo Virtual environment not found. Running setup script...
    cd /d "%~dp0"
    call setup_agent.bat
    cd /d "%AGENT_DIR%"
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat

REM Set optimization options
echo Setting Python optimization options...
set PYTHONOPTIMIZE=2
set PYTHONHASHSEED=0
set PYTHONUNBUFFERED=1

REM Create data directory if it doesn't exist
if not exist "data" (
    mkdir data
    echo Created data directory
)

REM Start the agent with optimizations
echo Starting the agent with optimizations...
python -O data_collector.py

REM This script should not normally reach here unless the agent exits
echo Agent has stopped.
call venv\Scripts\deactivate.bat
pause