@echo off
REM Printer SNMP Management - Complete System Setup Script for Windows
REM Sets up both Server and Frontend components

echo =========================================================
echo Printer SNMP Management - Complete System Setup
echo =========================================================

REM Get the directory of this script
set "SCRIPT_DIR=%~dp0"

REM Run Server Setup
echo Step 1: Setting up the Server...
call "%SCRIPT_DIR%setup_server.bat"

REM Run Frontend Setup
echo Step 2: Setting up the Frontend...
call "%SCRIPT_DIR%setup_frontend.bat"

REM Create startup scripts in the root directory
cd /d "%SCRIPT_DIR%.."
set "ROOT_DIR=%CD%"

echo Creating convenient system-wide startup scripts...

REM Create development startup script
(
    echo @echo off
    echo REM Start both server and frontend in development mode
    echo echo Starting Printer SNMP Management System in development mode...
    echo.
    echo REM Start the server
    echo start "Printer Monitor Server" cmd /c "cd /d %%~dp0Server && call run_dev.bat"
    echo.
    echo REM Wait a moment for server to initialize
    echo timeout /t 5
    echo.
    echo REM Start the frontend 
    echo start "Printer Monitor Frontend" cmd /c "cd /d %%~dp0FrontEnd && call run_dev.bat"
    echo.
    echo echo System is running in separate windows.
    echo echo Close those windows to stop the services.
) > start_dev.bat

REM Create production startup script with Docker
(
    echo @echo off
    echo REM Start the complete system in production mode using Docker
    echo.
    echo echo Starting Printer SNMP Management System in production mode...
    echo.
    echo REM Use the server's docker-compose to start everything
    echo cd /d %%~dp0Server
    echo call run_docker.bat
    echo.
    echo echo System started in Docker containers.
    echo echo Access the system at: http://localhost
    echo echo Admin username: admin
    echo for /f "tokens=2 delims==" %%%%a in ('findstr "DEFAULT_ADMIN_PASSWORD" .env') do echo Admin password: %%%%a
) > start_production.bat

echo =========================================================
echo Complete system setup finished!
echo.
echo You can now start the entire system with:
echo   For development: start_dev.bat
echo   For production: start_production.bat
echo.
echo To set up the agent on monitoring machines:
echo   1. Copy the Agent directory to each monitoring machine
echo   2. Run: cd Agent && setup_windows.bat http://server-address:3000/api
echo.
echo Admin credentials are saved in Server/.env
echo.
echo These credentials will be needed to log in to the system.
echo =========================================================

pause