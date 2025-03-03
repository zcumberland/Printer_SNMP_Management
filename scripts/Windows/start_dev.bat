@echo off
REM Printer SNMP Management - Development Environment Startup Script

echo =========================================================
echo Printer SNMP Management - Starting Development Environment
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

REM Start each component in development mode
echo Starting components in development mode...

REM Start server with nodemon (if available) for auto-reloading
cd /d "..\Server"
if exist "node_modules\nodemon\" (
    echo Starting server with nodemon for auto-reloading...
    start "Printer SNMP Management - Server (Dev)" cmd /c "npx nodemon server.js"
) else (
    echo Starting server (install nodemon for auto-reloading)...
    start "Printer SNMP Management - Server (Dev)" cmd /c "node server.js"
)
cd /d "%SCRIPT_DIR%"

REM Wait briefly for server to initialize
timeout /t 2 /nobreak > nul

REM Start agent
cd /d "..\Agent"
echo Starting agent...
start "Printer SNMP Management - Agent (Dev)" cmd /c "call venv\Scripts\activate.bat && python data_collector.py"
cd /d "%SCRIPT_DIR%"

REM Start frontend in development mode
cd /d "..\FrontEnd"
echo Starting frontend in development mode...
start "Printer SNMP Management - Frontend (Dev)" cmd /c "npm start"
cd /d "%SCRIPT_DIR%"

echo All development components have been started in separate windows.
echo Close this window when you want to exit the application.
echo (Closing this window will NOT stop the running components)

pause