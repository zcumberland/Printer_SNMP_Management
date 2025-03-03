@echo off
REM Printer SNMP Management - Docker Environment Startup Script

echo =========================================================
echo Printer SNMP Management - Starting Docker Environment
echo =========================================================

REM Get script directory
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM Check if Docker is installed
docker --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Docker is not installed. Please install Docker and Docker Compose first.
    echo Visit https://docs.docker.com/get-docker/ for installation instructions.
    pause
    exit /b 1
)

REM Check if Docker Compose is installed
docker-compose --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    docker compose version >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo Docker Compose is not installed or not available. Please install Docker Compose.
        echo Visit https://docs.docker.com/compose/install/ for installation instructions.
        pause
        exit /b 1
    )
)

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

REM Check compose file location
set "COMPOSE_FILE=..\Server\compose.yml"
if not exist "%COMPOSE_FILE%" (
    set "COMPOSE_FILE=..\Server\docker-compose.yml"
    if not exist "%COMPOSE_FILE%" (
        echo Docker Compose file not found. Creating a default compose file...
        
        REM Create a compose file if it doesn't exist
        (
            echo version: '3.8'
            echo.
            echo services:
            echo   server:
            echo     build:
            echo       context: .
            echo       dockerfile: dockerfile
            echo     restart: unless-stopped
            echo     ports:
            echo       - "3000:3000"
            echo     environment:
            echo       - NODE_ENV=production
            echo     volumes:
            echo       - ./data:/app/data
            echo     networks:
            echo       - printer-snmp-network
            echo.
            echo   frontend:
            echo     build:
            echo       context: ../FrontEnd
            echo       dockerfile: dockerfile.frontend
            echo     restart: unless-stopped
            echo     ports:
            echo       - "80:80"
            echo     depends_on:
            echo       - server
            echo     networks:
            echo       - printer-snmp-network
            echo.
            echo networks:
            echo   printer-snmp-network:
            echo     driver: bridge
        ) > "..\Server\compose.yml"
        set "COMPOSE_FILE=..\Server\compose.yml"
        
        REM Check if Dockerfiles exist, create if needed
        if not exist "..\Server\dockerfile" (
            echo Creating server Dockerfile...
            (
                echo FROM node:18-alpine
                echo.
                echo WORKDIR /app
                echo.
                echo COPY package*.json ./
                echo.
                echo RUN npm install --production
                echo.
                echo COPY . .
                echo.
                echo EXPOSE 3000
                echo.
                echo CMD ["node", "server.js"]
            ) > "..\Server\dockerfile"
        )
        
        if not exist "..\FrontEnd\dockerfile.frontend" (
            echo Creating frontend Dockerfile...
            (
                echo FROM node:18-alpine as build
                echo.
                echo WORKDIR /app
                echo.
                echo COPY package*.json ./
                echo.
                echo RUN npm install
                echo.
                echo COPY . .
                echo.
                echo RUN npm run build
                echo.
                echo FROM nginx:alpine
                echo.
                echo COPY --from=build /app/build /usr/share/nginx/html
                echo COPY nginx.conf /etc/nginx/conf.d/default.conf
                echo.
                echo EXPOSE 80
                echo.
                echo CMD ["nginx", "-g", "daemon off;"]
            ) > "..\FrontEnd\dockerfile.frontend"
        )
        
        REM Check if nginx conf exists
        if not exist "..\FrontEnd\nginx.conf" (
            echo Creating nginx configuration...
            (
                echo server {
                echo     listen 80;
                echo     server_name localhost;
                echo.
                echo     location / {
                echo         root /usr/share/nginx/html;
                echo         index index.html;
                echo         try_files $uri $uri/ /index.html;
                echo     }
                echo.
                echo     location /api {
                echo         proxy_pass http://server:3000/api;
                echo         proxy_http_version 1.1;
                echo         proxy_set_header Upgrade $http_upgrade;
                echo         proxy_set_header Connection 'upgrade';
                echo         proxy_set_header Host $host;
                echo         proxy_cache_bypass $http_upgrade;
                echo     }
                echo }
            ) > "..\FrontEnd\nginx.conf"
        )
    )
)

REM Start Docker Compose
echo Starting Docker containers...
cd /d "%~dp0..\Server"

REM Check which Docker Compose command to use
docker-compose --version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    REM Using older docker-compose
    docker-compose -f compose.yml up -d --build
) else (
    REM Using newer docker compose
    docker compose -f compose.yml up -d --build
)

if %ERRORLEVEL% EQU 0 (
    echo =========================================================
    echo Docker containers started successfully!
    echo.
    echo The application should be available at:
    echo http://localhost
    echo.
    echo API is available at:
    echo http://localhost/api
    echo.
    echo To view logs: docker compose logs -f
    echo To stop: docker compose down
    echo =========================================================
) else (
    echo Failed to start Docker containers. Please check the logs.
    pause
    exit /b 1
)

REM Note about agent
echo NOTE: The agent component must be installed and run separately on the
echo monitoring machine(s). It cannot be containerized with the rest of the
echo application since it needs access to the local network for SNMP scanning.
echo.
echo To set up the agent, run the setup_agent.bat script on each monitoring machine.

pause