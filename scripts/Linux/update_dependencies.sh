#!/bin/bash
# This script updates dependencies for both Server and Frontend components

echo "========================================================="
echo "Printer SNMP Management - Dependency Update Script"
echo "========================================================="

# Get the root directory of the project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Update Server dependencies
echo "Updating Server dependencies..."
cd "$ROOT_DIR/Server"
npm install
npm update
npm prune

# Update Frontend dependencies
echo "Updating Frontend dependencies..."
cd "$ROOT_DIR/FrontEnd"
npm install
npm update
npm prune

echo "========================================================="
echo "Dependencies updated successfully!"
echo "========================================================="