#!/bin/bash
# Printer SNMP Management - Complete System Run Script

echo "========================================================="
echo "Printer SNMP Management - Starting All Components"
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

# Start each component
echo "Starting components..."

# Start server in background
echo "Starting server..."
./run_server.sh &
SERVER_PID=$!
echo "Server started with PID: $SERVER_PID"

# Wait briefly for server to initialize
sleep 3

# Start agent in background
echo "Starting agent..."
./run_agent.sh &
AGENT_PID=$!
echo "Agent started with PID: $AGENT_PID"

# Start frontend (this will stay in foreground)
echo "Starting frontend..."
./run_frontend.sh

# When frontend exits, kill other processes
echo "Frontend has stopped. Stopping other components..."
kill $SERVER_PID $AGENT_PID 2>/dev/null

echo "All components have been stopped."