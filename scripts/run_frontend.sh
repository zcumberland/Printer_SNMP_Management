#!/bin/bash
# Printer SNMP Management - Frontend Run Script

echo "========================================================="
echo "Printer SNMP Management - Starting Frontend"
echo "========================================================="

# Navigate to frontend directory
cd "$(dirname "$0")/../FrontEnd"
FRONTEND_DIR=$(pwd)
echo "Starting frontend from: $FRONTEND_DIR"

# Check for Node.js
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed or not in PATH."
    echo "Please run the setup script first: ./setup_frontend.sh"
    exit 1
fi

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "Node modules not found. Running npm install..."
    npm install
fi

# Start the development server
echo "Starting the frontend development server..."
npm start

# This script should not normally reach here unless the server exits
echo "Frontend development server has stopped."