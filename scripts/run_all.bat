@echo off
REM Printer SNMP Management - Complete System Run Script for Windows

echo =========================================================
echo Printer SNMP Management - Starting All Components
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

REM Start each component
echo Starting components...

REM Start the server in a new window
echo Starting server...
start "Printer SNMP Management - Server" cmd /c "%SCRIPT_DIR%run_server.bat"

REM Wait briefly for server to initialize
timeout /t 3 /nobreak > nul

REM Start the agent in a new window
echo Starting agent...
start "Printer SNMP Management - Agent" cmd /c "%SCRIPT_DIR%run_agent.bat"

REM Start the frontend in a new window (this will be visible to the user)
echo Starting frontend...
start "Printer SNMP Management - Frontend" cmd /c "%SCRIPT_DIR%run_frontend.bat"

echo All components have been started in separate windows.
echo Close this window when you want to exit the application.
echo (Closing this window will NOT stop the running components)

pause