#!/bin/bash
# Printer SNMP Management - Complete System Setup Script
# Sets up both Server and Frontend components

set -e

echo "========================================================="
echo "Printer SNMP Management - Complete System Setup"
echo "========================================================="

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Server Setup
echo "Step 1: Setting up the Server..."
bash "$SCRIPT_DIR/setup_server.sh"

# Frontend Setup
echo "Step 2: Setting up the Frontend..."
bash "$SCRIPT_DIR/setup_frontend.sh"

# Create startup scripts in the root directory
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

echo "Creating convenient system-wide startup scripts..."

# Create development startup script
cat > start_dev.sh << 'EOF'
#!/bin/bash
# Start both server and frontend in development mode
echo "Starting Printer SNMP Management System in development mode..."

# Start the server
cd "$(dirname "$0")/Server"
npm run dev &
SERVER_PID=$!
echo "Server started with PID: $SERVER_PID"

# Wait a moment for server to initialize
sleep 3

# Start the frontend 
cd "$(dirname "$0")/FrontEnd"
npm start &
FRONTEND_PID=$!
echo "Frontend started with PID: $FRONTEND_PID"

echo "System is running. Press Ctrl+C to stop."

# Handle graceful shutdown
trap "kill $SERVER_PID $FRONTEND_PID; exit" INT TERM
wait
EOF
chmod +x start_dev.sh

# Create production startup script with Docker
cat > start_prod.sh << 'EOF'
#!/bin/bash
# Start the complete system in production mode using Docker

echo "Starting Printer SNMP Management System in production mode..."

# Use the server's docker-compose to start everything
cd "$(dirname "$0")/Server"
docker compose down
docker compose up -d

echo "System started in Docker containers."
echo "Access the system at: http://localhost"
echo "Admin username: admin"
echo "Admin password: $(grep DEFAULT_ADMIN_PASSWORD .env | cut -d '=' -f2)"
EOF
chmod +x start_prod.sh

# Create Windows batch files
cat > start_dev.bat << 'EOF'
@echo off
echo Starting Printer SNMP Management System in development mode...

start "Printer Monitor Server" cmd /c "cd %~dp0Server && npm run dev"
timeout /t 5
start "Printer Monitor Frontend" cmd /c "cd %~dp0FrontEnd && npm start"

echo System is starting. Close the terminal windows to stop.
EOF

cat > start_production.bat << 'EOF'
@echo off
echo Starting Printer SNMP Management System in production mode...

cd %~dp0Server
docker compose down
docker compose up -d

echo System started in Docker containers.
echo Access the system at: http://localhost
echo Admin username: admin
for /f "tokens=2 delims==" %%a in ('findstr "DEFAULT_ADMIN_PASSWORD" .env') do echo Admin password: %%a
EOF

echo "========================================================="
echo "Complete system setup finished!"
echo ""
echo "You can now start the entire system with:"
echo "  For development: ./start_dev.sh"
echo "  For production: ./start_prod.sh"
echo ""
echo "To set up the agent on monitoring machines:"
echo "  1. Copy the Agent directory to each monitoring machine"
echo "  2. Run: ./scripts/setup_agent.sh http://server-address:3000/api"
echo ""
echo "Admin credentials (save these):"
echo "  Username: admin"
echo "  Password: $(grep DEFAULT_ADMIN_PASSWORD Server/.env | cut -d '=' -f2)"
echo ""
echo "These credentials will be needed to log in to the system."
echo "========================================================="