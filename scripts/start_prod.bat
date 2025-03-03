@echo off
REM Printer SNMP Management - Production Environment Startup Script

echo =========================================================
echo Printer SNMP Management - Starting Production Environment
echo =========================================================

REM Get script directory
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM Function to check if component is set up
:check_setup
set "component=%~1"
set "check_dir=%~2"
set "check_file=%~3"

if not exist "%check_dir%\" (
    echo %component% is not set up. Running setup script...
    call setup_%component%.bat
) else if not exist "%check_file%" (
    echo %component% is not set up properly. Running setup script...
    call setup_%component%.bat
) else (
    echo %component% appears to be set up.
)
goto :eof

REM Check and setup each component if needed
call :check_setup "server" "..\Server\node_modules" "..\Server\node_modules\express"
call :check_setup "frontend" "..\FrontEnd\node_modules" "..\FrontEnd\node_modules\react"
call :check_setup "agent" "..\Agent\venv" "..\Agent\venv\Scripts\activate.bat"

REM Build frontend for production
echo Building frontend for production...
cd /d "..\FrontEnd"
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo Failed to build frontend. Exiting.
    pause
    exit /b 1
)
cd /d "%SCRIPT_DIR%"

REM Check if pm2 is available for production process management
where pm2 >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo PM2 process manager not found. Installing globally...
    call npm install -g pm2
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to install PM2. Will run without process management.
    )
)

REM Start server in production mode
echo Starting server in production mode...
cd /d "..\Server"
where pm2 >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    REM Set production environment
    set NODE_ENV=production
    REM Start with PM2
    call pm2 start server.js --name "printer-snmp-server"
    if %ERRORLEVEL% NEQ 0 (
        echo PM2 failed, starting normally...
        start "Printer SNMP Management - Server (Prod)" cmd /c "set NODE_ENV=production && node server.js"
    )
) else (
    REM Start without PM2
    start "Printer SNMP Management - Server (Prod)" cmd /c "set NODE_ENV=production && node server.js"
)
cd /d "%SCRIPT_DIR%"

REM Start agent in production mode
echo Starting agent in production mode...
cd /d "..\Agent"
where pm2 >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    REM Start agent with PM2
    call pm2 start --interpreter python ./data_collector.py --name "printer-snmp-agent"
    if %ERRORLEVEL% NEQ 0 (
        echo PM2 failed, starting normally...
        start "Printer SNMP Management - Agent (Prod)" cmd /c "call venv\Scripts\activate.bat && python data_collector.py"
    )
) else (
    REM Start without PM2
    start "Printer SNMP Management - Agent (Prod)" cmd /c "call venv\Scripts\activate.bat && python data_collector.py"
)
cd /d "%SCRIPT_DIR%"

REM If using PM2, save the process list
where pm2 >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Saving PM2 process list...
    call pm2 save
    
    echo =========================================================
    echo Production environment started successfully with PM2!
    echo.
    echo Running processes:
    call pm2 list
    echo.
    echo To monitor: pm2 monit
    echo To stop all: pm2 stop all
    echo To remove all: pm2 delete all
) else (
    echo =========================================================
    echo Production environment started successfully!
    echo.
    echo All processes are running in separate windows.
    echo Close the windows to stop the processes.
)
echo =========================================================

pause