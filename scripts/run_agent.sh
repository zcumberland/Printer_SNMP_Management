#!/bin/bash
# Printer SNMP Management - Agent Run Script

echo "========================================================="
echo "Printer SNMP Management - Starting Agent"
echo "========================================================="

# Navigate to agent directory
cd "$(dirname "$0")/../Agent"
AGENT_DIR=$(pwd)
echo "Starting agent from: $AGENT_DIR"

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed or not in PATH."
    echo "Please run the setup script first: ./setup_agent.sh"
    exit 1
fi

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Running setup script..."
    cd "$(dirname "$0")"
    ./setup_agent.sh
    cd "$AGENT_DIR"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Set optimization options
echo "Setting Python optimization options..."
export PYTHONOPTIMIZE=2
export PYTHONHASHSEED=0
export PYTHONUNBUFFERED=1

# Create data directory if it doesn't exist
if [ ! -d "data" ]; then
    mkdir -p data
    echo "Created data directory"
fi

# Set process priority 
if command -v nice &> /dev/null; then
    echo "Setting process priority..."
    # Start the agent with reduced priority to minimize system impact
    nice -n 10 python3 -O data_collector.py
else
    # Start the agent
    echo "Starting the agent..."
    python3 -O data_collector.py
fi

# This script should not normally reach here unless the agent exits
echo "Agent has stopped."
deactivate