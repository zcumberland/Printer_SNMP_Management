#!/bin/bash
# Printer SNMP Management - Production Environment Startup Script

echo "========================================================="
echo "Printer SNMP Management - Starting Production Environment"
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

# Build frontend for production
echo "Building frontend for production..."
cd "../FrontEnd"
npm run build
if [ $? -ne 0 ]; then
    echo "Failed to build frontend. Exiting."
    exit 1
fi
cd "$SCRIPT_DIR"

# Check if pm2 is available for production process management
if ! command -v pm2 &> /dev/null; then
    echo "PM2 process manager not found. Installing globally..."
    npm install -g pm2
    if [ $? -ne 0 ]; then
        echo "Failed to install PM2. Will run without process management."
    fi
fi

# Start server in production mode
echo "Starting server in production mode..."
cd "../Server"
if command -v pm2 &> /dev/null; then
    # Set production environment
    export NODE_ENV=production
    
    # Optimize Node.js for production
    export NODE_OPTIONS="--max-old-space-size=2048 --optimize-for-size"
    
    # Start with PM2 with optimized settings
    pm2 start server.js --name "printer-snmp-server" \
      --max-memory-restart 1G \
      --node-args="--optimize-for-size" \
      --exp-backoff-restart-delay=100 \
      --max-restarts=10 \
      --env production || node server.js &
else
    # Start without PM2
    export NODE_ENV=production
    export NODE_OPTIONS="--max-old-space-size=2048 --optimize-for-size"
    node --optimize-for-size server.js &
fi
SERVER_PID=$!
echo "Server started"
cd "$SCRIPT_DIR"

# Start agent in production mode
echo "Starting agent in production mode..."
cd "../Agent"
source venv/bin/activate
if command -v pm2 &> /dev/null; then
    # Start agent with PM2
    pm2 start --interpreter=python ./data_collector.py --name "printer-snmp-agent" || python data_collector.py &
else
    # Start without PM2
    python data_collector.py &
fi
AGENT_PID=$!
echo "Agent started"
deactivate
cd "$SCRIPT_DIR"

# If using PM2, save the process list
if command -v pm2 &> /dev/null; then
    echo "Saving PM2 process list..."
    pm2 save
    
    # Generate startup script to automatically start on boot
    echo "Generating PM2 startup script..."
    pm2 startup
    echo "NOTE: You may need to run the above command manually as root."
fi

echo "========================================================="
echo "Production environment started successfully!"
echo ""
if command -v pm2 &> /dev/null; then
    echo "Running processes:"
    pm2 list
    echo ""
    echo "To monitor: pm2 monit"
    echo "To stop all: pm2 stop all"
    echo "To remove all: pm2 delete all"
else
    echo "Server PID: $SERVER_PID"
    echo "Agent PID: $AGENT_PID"
    echo ""
    echo "To stop, press Ctrl+C or run: kill $SERVER_PID $AGENT_PID"
fi
echo "========================================================="

# If not using PM2, wait for a signal to terminate
if ! command -v pm2 &> /dev/null; then
    echo "Press Ctrl+C to stop all services..."
    wait
fi