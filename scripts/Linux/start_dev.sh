#!/bin/bash
# Printer SNMP Management - Development Environment Startup Script

echo "========================================================="
echo "Printer SNMP Management - Starting Development Environment"
echo "========================================================="

# Get script directory
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

# Function to check if a component is set up
check_setup() {
    local component=$1
    local check_dir=$2
    local check_file=$3
    
    if [ ! -d "$check_dir" ] || [ ! -f "$check_file" ]; then
        echo "$component is not set up. Running setup script..."
        ./setup_${component}.sh
    else
        echo "$component appears to be set up."
    fi
}

# Check and setup each component if needed
check_setup "server" "../Server/node_modules" "../Server/node_modules/express"
check_setup "frontend" "../FrontEnd/node_modules" "../FrontEnd/node_modules/react"
check_setup "agent" "../Agent/venv" "../Agent/venv/pyvenv.cfg"

# Start each component in development mode
echo "Starting components in development mode..."

# Start server with nodemon (if available) for auto-reloading
cd "../Server"
if [ -d "node_modules/nodemon" ] || [ -d "../node_modules/nodemon" ]; then
    echo "Starting server with nodemon for auto-reloading..."
    npx nodemon server.js &
else
    echo "Starting server (install nodemon globally for auto-reloading)..."
    node server.js &
fi
SERVER_PID=$!
echo "Server started with PID: $SERVER_PID"
cd "$SCRIPT_DIR"

# Wait briefly for server to initialize
sleep 2

# Start agent with auto-reloading using watchdog if available
cd "../Agent"
echo "Starting agent..."
source venv/bin/activate
if pip list | grep -q "watchdog"; then
    echo "Starting agent with auto-reloading..."
    python -m watchdog.watchmedo auto-restart --directory=. --pattern=*.py --recursive -- python data_collector.py &
else
    echo "Starting agent (install watchdog for auto-reloading)..."
    python data_collector.py &
fi
AGENT_PID=$!
echo "Agent started with PID: $AGENT_PID"
deactivate
cd "$SCRIPT_DIR"

# Start frontend in development mode
cd "../FrontEnd"
echo "Starting frontend in development mode..."
npm start

# When frontend exits, kill other processes
echo "Frontend has stopped. Stopping other components..."
kill $SERVER_PID $AGENT_PID 2>/dev/null

echo "All development components have been stopped."