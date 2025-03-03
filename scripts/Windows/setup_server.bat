@echo off
REM Printer SNMP Management - Server Setup Script for Windows

echo =========================================================
echo Printer SNMP Management - Server Setup
echo =========================================================

REM Check if Node.js is installed
node --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Node.js is not installed or not in PATH.
    echo Please install Node.js from https://nodejs.org/
    echo Make sure to select "Add to PATH" during installation.
    echo After installing Node.js, run this script again.
    exit /b 1
) else (
    echo Node.js is already installed: 
    node --version
)

REM Check if Docker is installed
docker --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Docker is not installed or not in PATH.
    echo For production mode, you'll need Docker.
    echo Download Docker Desktop from https://www.docker.com/products/docker-desktop
    echo.
    echo You can continue with development setup without Docker.
    set DOCKER_AVAILABLE=false
) else (
    echo Docker is already installed:
    docker --version
    set DOCKER_AVAILABLE=true
)

REM Navigate to server directory
cd /d "%~dp0..\Server"
set SERVER_DIR=%CD%
echo Setting up server in: %SERVER_DIR%

REM Setup .env file
if not exist .env (
    echo Creating .env file...
    
    REM Generate random passwords and secrets
    setlocal EnableDelayedExpansion
    set "characters=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    set "jwt_secret="
    set "db_password="
    set "admin_password="
    
    REM Generate JWT Secret (32 chars)
    for /L %%i in (1,1,32) do (
        set /a rnd=!random! %% 62
        for /F %%j in ("!rnd!") do set "jwt_secret=!jwt_secret!!characters:~%%j,1!"
    )
    
    REM Generate DB Password (16 chars)
    for /L %%i in (1,1,16) do (
        set /a rnd=!random! %% 62
        for /F %%j in ("!rnd!") do set "db_password=!db_password!!characters:~%%j,1!"
    )
    
    REM Generate Admin Password (12 chars)
    for /L %%i in (1,1,12) do (
        set /a rnd=!random! %% 62
        for /F %%j in ("!rnd!") do set "admin_password=!admin_password!!characters:~%%j,1!"
    )
    
    (
        echo # Database Configuration
        echo DB_USER=postgres
        echo DB_PASSWORD=!db_password!
        echo DB_HOST=db
        echo DB_NAME=printer_monitor
        echo DB_PORT=5432
        echo.
        echo # JWT Configuration
        echo JWT_SECRET=!jwt_secret!
        echo JWT_EXPIRES_IN=24h
        echo.
        echo # Admin User
        echo DEFAULT_ADMIN_USERNAME=admin
        echo DEFAULT_ADMIN_PASSWORD=!admin_password!
        echo DEFAULT_ADMIN_EMAIL=admin@example.com
        echo.
        echo # Server Configuration
        echo PORT=3000
        echo NODE_ENV=production
    ) > .env
    
    echo Created .env file with secure randomly generated passwords.
    echo Admin username: admin
    echo Admin password: !admin_password!
    echo Please save these credentials securely!
    endlocal
) else (
    echo .env file already exists. Keeping existing configuration.
)

REM Install npm dependencies
echo Installing npm dependencies...
call npm install

REM Create run scripts
echo Creating startup scripts...

REM Create Windows batch script for development
(
    echo @echo off
    echo cd /d "%%~dp0"
    echo echo Starting server in development mode...
    echo call npm run dev
) > run_dev.bat

REM Create Windows batch script for production with Docker
(
    echo @echo off
    echo cd /d "%%~dp0"
    echo echo Starting server in production mode with Docker...
    echo docker compose down
    echo docker compose up -d
) > run_docker.bat

echo =========================================================
echo Server setup complete!
echo.
echo For development mode:
echo   run_dev.bat
echo.
echo For production mode (with Docker):
echo   run_docker.bat
echo.
echo Admin credentials:
echo   Username: admin
for /f "tokens=2 delims==" %%a in ('findstr "DEFAULT_ADMIN_PASSWORD" .env') do echo   Password: %%a
echo.
echo These credentials will be needed to log in to the system.
echo Make sure all necessary ports (3000, 80) are open in your firewall.
echo =========================================================

pause