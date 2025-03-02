#!/bin/bash
# Raspberry Pi Setup Script for Printer Monitoring Agent
# Run this script on a fresh Raspberry Pi OS installation

# Exit on any error
set -e

echo "Setting up Printer Monitoring Agent on Raspberry Pi..."
echo "-----------------------------------------------------"

# Update system
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install dependencies
echo "Installing required packages..."
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    libsnmp-dev \
    snmp-mibs-downloader \
    git \
    docker.io \
    docker-compose

# Setup Docker
echo "Setting up Docker..."
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
echo "You may need to log out and log back in for Docker permissions to take effect"

# Create directory for the agent
echo "Creating directory structure..."
mkdir -p ~/printer-agent/agent/data

# Download agent code
echo "Downloading agent code..."
cd ~/printer-agent

# Create agent directory and download files
cat > agent/printer_monitor.py << 'EOF'
# Paste printer_monitor.py content here
EOF

# Create requirements.txt
cat > agent/requirements.txt << 'EOF'
pysnmp==4.4.12
requests==2.28.1
schedule==1.1.0
ipaddress==1.0.23
configparser==5.3.0
EOF

# Create default config.ini
cat > agent/config.ini << 'EOF'
[agent]
id = 
name = RaspberryPi
polling_interval = 300
discovery_interval = 86400
data_dir = ./data

[server]
url = https://your-server-url.com/api
token = 

[network]
subnets = ["192.168.1.0/24"]
snmp_community = public
snmp_timeout = 2
EOF

# Create Dockerfile
cat > Dockerfile.agent << 'EOF'
FROM python:3.9-slim

WORKDIR /app

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        libsnmp-dev \
        snmp-mibs-downloader \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY agent/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy agent code
COPY agent/printer_monitor.py .

# Create required directories
RUN mkdir -p data

# Set the entrypoint
ENTRYPOINT ["python", "printer_monitor.py"]
EOF

# Create docker-compose file
cat > docker-compose.yml << 'EOF'
version: '3'

services:
  agent:
    build:
      context: .
      dockerfile: Dockerfile.agent
    container_name: printer-agent
    restart: unless-stopped
    network_mode: host  # Use host network to scan local network
    volumes:
      - ./agent/data:/app/data
      - ./agent/config.ini:/app/config.ini
    environment:
      - TZ=UTC
EOF

# Create systemd service for auto-start
echo "Creating systemd service for auto-start..."
cat > printer-agent.service << 'EOF'
[Unit]
Description=Printer Monitoring Agent
After=docker.service
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=/home/pi/printer-agent
ExecStart=/usr/bin/docker-compose up
ExecStop=/usr/bin/docker-compose down
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo mv printer-agent.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable printer-agent.service

# Configure agent
echo "Please edit the configuration file at ~/printer-agent/agent/config.ini"
echo "Set your subnets to scan and server URL"

# Build and start the agent
echo "Building Docker image..."
docker-compose build

echo "-----------------------------------------------------"
echo "Setup complete!"
echo "Start the agent with: sudo systemctl start printer-agent"
echo "Check status with: sudo systemctl status printer-agent"
echo "View logs with: sudo journalctl -u printer-agent -f"
echo "-----------------------------------------------------"