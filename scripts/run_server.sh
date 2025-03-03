#!/bin/bash
# Printer SNMP Management - Server Run Script

echo "========================================================="
echo "Printer SNMP Management - Starting Server"
echo "========================================================="

# Navigate to server directory
cd "$(dirname "$0")/../Server"
SERVER_DIR=$(pwd)
echo "Starting server from: $SERVER_DIR"

# Check for Node.js
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed or not in PATH."
    echo "Please run the setup script first: ./setup_server.sh"
    exit 1
fi

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "Node modules not found. Running npm install..."
    npm install
fi

# Start the server
echo "Starting the server..."
npm start

# This script should not normally reach here unless the server exits
echo "Server has stopped."