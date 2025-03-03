#!/bin/bash
# Printer SNMP Management - Agent Setup Script
# Works on Linux systems including ARM-based and common distributions

set -e

echo "========================================================="
echo "Printer SNMP Management - Agent Setup"
echo "========================================================="

# Check if running with arguments
if [ $# -eq 1 ]; then
    SERVER_URL=$1
    echo "Using server URL: $SERVER_URL"
else
    SERVER_URL="http://localhost:3000/api"
    echo "No server URL provided, using default: $SERVER_URL"
    echo "You can specify a server URL: ./setup_agent.sh http://your-server:3000/api"
fi

# Function to check and install packages based on distribution
install_dependencies() {
    echo "Checking system and installing dependencies..."
    
    # Check for Python 3
    if ! command -v python3 &> /dev/null; then
        echo "Python 3 not found. Installing..."
        
        if command -v apt &> /dev/null; then
            # Debian/Ubuntu
            sudo apt update
            sudo apt install -y python3 python3-pip python3-venv
        elif command -v dnf &> /dev/null; then
            # Fedora/RHEL/CentOS
            sudo dnf install -y python3 python3-pip
        elif command -v yum &> /dev/null; then
            # Older RHEL/CentOS
            sudo yum install -y python3 python3-pip
        elif command -v pacman &> /dev/null; then
            # Arch Linux
            sudo pacman -Sy python python-pip
        elif command -v zypper &> /dev/null; then
            # openSUSE
            sudo zypper install -y python3 python3-pip
        else
            echo "Unsupported package manager. Please install Python 3 manually."
            exit 1
        fi
    else
        echo "Python 3 is already installed."
    fi
}

# Install dependencies
install_dependencies

# Navigate to agent directory
cd "$(dirname "$0")/../Agent"
AGENT_DIR=$(pwd)
echo "Setting up agent in: $AGENT_DIR"

# Create a virtual environment
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install required packages
echo "Installing required packages..."
pip install --upgrade pip
pip install -r requirements.txt

# Create data directory
mkdir -p data

# Generate a unique agent ID
AGENT_ID=$(python3 -c "import uuid; print(str(uuid.uuid4()))")
echo "Generated agent ID: $AGENT_ID"

# Create configuration file
echo "Creating/updating configuration..."
cat > config.ini << EOF
[agent]
id = $AGENT_ID
name = PrinterMonitorAgent
polling_interval = 300
discovery_interval = 86400
data_dir = ./data

[server]
enabled = true
url = $SERVER_URL

[network]
subnets = ["192.168.1.0/24"]
snmp_community = public
snmp_timeout = 2
EOF

echo "Configuration created. Edit config.ini to match your network settings."

# Initialize the database
echo "Initializing the database..."
python3 -c '
import sqlite3
import os

os.makedirs("./data", exist_ok=True)
db_path = os.path.join("./data", "printers.db")
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Create printers table
cursor.execute("""
CREATE TABLE IF NOT EXISTS printers (
    id INTEGER PRIMARY KEY,
    ip_address TEXT UNIQUE,
    serial_number TEXT,
    model TEXT,
    name TEXT,
    status TEXT,
    last_seen TIMESTAMP
)
""")

# Create metrics table
cursor.execute("""
CREATE TABLE IF NOT EXISTS metrics (
    id INTEGER PRIMARY KEY,
    printer_id INTEGER,
    timestamp TIMESTAMP,
    page_count INTEGER,
    toner_levels TEXT,
    status TEXT,
    error_state TEXT,
    raw_data TEXT,
    FOREIGN KEY (printer_id) REFERENCES printers (id)
)
""")

conn.commit()
conn.close()
print("Database initialized successfully.")
'

# Create run scripts
echo "Creating executable scripts..."

# Create run script for Unix
cat > run_agent.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python data_collector.py "$@"
EOF
chmod +x run_agent.sh

# Create discover script
cat > discover_printers.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python data_collector.py --discover
EOF
chmod +x discover_printers.sh

# Deactivate virtual environment
deactivate

echo "========================================================="
echo "Agent setup complete!"
echo ""
echo "You can run the agent with:"
echo "  ./run_agent.sh"
echo ""
echo "To discover printers:"
echo "  ./discover_printers.sh"
echo ""
echo "To manually run:"
echo "  1. Activate the virtual environment: source venv/bin/activate"
echo "  2. Run the agent: python data_collector.py"
echo ""
echo "The agent is configured to connect to: $SERVER_URL"
echo "Edit config.ini to change any settings."
echo "========================================================="