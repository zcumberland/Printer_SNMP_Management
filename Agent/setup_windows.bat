@echo off
REM Printer SNMP Management - Agent Setup Script for Windows
REM Run this batch file to set up the agent on Windows systems

echo =========================================================
echo Printer SNMP Management - Agent Setup for Windows
echo =========================================================

set SERVER_URL=http://localhost:3000/api
if not "%~1"=="" (
    set SERVER_URL=%~1
    echo Using server URL: %SERVER_URL%
) else (
    echo No server URL provided, using default: %SERVER_URL%
    echo You can specify a server URL: setup_windows.bat http://your-server:3000/api
)

REM Check if Python is installed
python --version 2>NUL
if %ERRORLEVEL% NEQ 0 (
    echo Python is not installed or not in PATH.
    echo Please install Python 3.8 or newer from https://www.python.org/downloads/
    echo Make sure to check "Add Python to PATH" during installation.
    exit /b 1
)

REM Create virtual environment
if not exist venv (
    echo Creating Python virtual environment...
    python -m venv venv
)

REM Activate virtual environment and install dependencies
echo Installing required packages...
call venv\Scripts\activate
python -m pip install --upgrade pip
pip install -r requirements.txt

REM Create data directory
if not exist data mkdir data

REM Generate a unique agent ID
for /f "tokens=*" %%a in ('python -c "import uuid; print(str(uuid.uuid4()))"') do set AGENT_ID=%%a
echo Generated agent ID: %AGENT_ID%

REM Create configuration file
echo Creating/updating configuration...
(
    echo [agent]
    echo id = %AGENT_ID%
    echo name = PrinterMonitorAgent
    echo polling_interval = 300
    echo discovery_interval = 86400
    echo data_dir = ./data
    echo.
    echo [server]
    echo enabled = true
    echo url = %SERVER_URL%
    echo.
    echo [network]
    echo subnets = ["192.168.1.0/24"]
    echo snmp_community = public
    echo snmp_timeout = 2
) > config.ini

echo Configuration created. Edit config.ini to match your network settings.

REM Initialize the database
echo Initializing the database...
python -c ^
"import sqlite3; import os; os.makedirs('./data', exist_ok=True); db_path = os.path.join('./data', 'printers.db'); conn = sqlite3.connect(db_path); cursor = conn.cursor(); cursor.execute('CREATE TABLE IF NOT EXISTS printers (id INTEGER PRIMARY KEY, ip_address TEXT UNIQUE, serial_number TEXT, model TEXT, name TEXT, status TEXT, last_seen TIMESTAMP)'); cursor.execute('CREATE TABLE IF NOT EXISTS metrics (id INTEGER PRIMARY KEY, printer_id INTEGER, timestamp TIMESTAMP, page_count INTEGER, toner_levels TEXT, status TEXT, error_state TEXT, raw_data TEXT, FOREIGN KEY (printer_id) REFERENCES printers (id))'); conn.commit(); conn.close(); print('Database initialized successfully.')"

REM Create run scripts
echo Creating executable scripts...

REM Create run script for Windows
(
    echo @echo off
    echo cd /d "%%~dp0"
    echo call venv\Scripts\activate
    echo python data_collector.py %%*
) > run_agent.bat

REM Create discover script
(
    echo @echo off
    echo cd /d "%%~dp0"
    echo call venv\Scripts\activate
    echo python data_collector.py --discover
) > discover_printers.bat

echo =========================================================
echo Agent setup complete!
echo.
echo You can run the agent with:
echo   run_agent.bat
echo.
echo To discover printers:
echo   discover_printers.bat
echo.
echo To manually run:
echo   1. Open a command prompt in this directory
echo   2. Activate the virtual environment: venv\Scripts\activate
echo   3. Run the agent: python data_collector.py
echo.
echo The agent is configured to connect to: %SERVER_URL%
echo Edit config.ini to change any settings.
echo =========================================================

pause