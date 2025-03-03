#!/bin/bash
# Script to set up the Printer Monitoring Agent

# Exit on any error
set -e

echo "Setting up Printer Monitoring Agent..."
echo "--------------------------------------"

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null
then
    echo "Python 3 is not installed. Installing..."
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv
else
    echo "Python 3 is already installed"
fi

# Navigate to agent directory
cd ../Agent

# Create a virtual environment
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install required packages
echo "Installing required packages..."
pip install -r requirements.txt

# Create data directory
mkdir -p data

# Create configuration file if it doesn't exist
if [ ! -f "config.ini" ]; then
    echo "Creating default configuration..."
    cat > config.ini << 'EOF'
[agent]
id = 
name = PrinterMonitorAgent
polling_interval = 300
discovery_interval = 86400
data_dir = ./data

[server]
enabled = true
url = http://localhost:3000/api

[network]
subnets = ["192.168.1.0/24"]
snmp_community = public
snmp_timeout = 2
EOF
    echo "Default configuration created. Please edit config.ini to match your network."
fi

# Initialize the database
echo "Initializing the database..."
python3 db_setup.py

echo "--------------------------------------"
echo "Agent setup complete!"
echo ""
echo "You can now run the agent with:"
echo "  source venv/bin/activate  # If not already activated"
echo "  python data_collector.py"
echo ""
echo "To discover printers:"
echo "  python data_collector.py --discover"
echo ""
echo "To collect metrics once:"
echo "  python data_collector.py --collect"
echo ""
echo "To register with the server:"
echo "  python data_collector.py --register"
echo "--------------------------------------"

# Deactivate virtual environment
deactivate