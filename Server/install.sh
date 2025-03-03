#!/bin/bash
# Installation script for Printer Monitoring Server
# Run this script on an Ubuntu server

# Exit on any error
set -e

echo "Setting up Printer Monitoring Server..."
echo "--------------------------------------"

# Update system
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install dependencies for Docker installation
echo "Installing prerequisites..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    nginx \
    certbot \
    python3-certbot-nginx

# Add Docker's official GPG key
echo "Adding Docker repository and GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update apt package index
sudo apt-get update

# Install Docker Engine, containerd, and Docker Compose plugin
echo "Installing Docker and Docker Compose..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify Docker installation
echo "Verifying Docker installation..."
sudo docker --version
sudo docker compose version

# Setup Docker
echo "Setting up Docker permissions..."
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
echo "You may need to log out and log back in for Docker permissions to take effect"

# Create .env file for configuration
echo "Creating environment configuration..."
cat > .env << EOF
# Database Configuration
DB_USER=postgres
DB_PASSWORD=your_secure_password
DB_NAME=printer_monitor

# JWT Configuration
JWT_SECRET=your_secure_jwt_key

# Admin User
DEFAULT_ADMIN_USERNAME=admin
DEFAULT_ADMIN_PASSWORD=your_secure_admin_password
DEFAULT_ADMIN_EMAIL=admin@example.com
EOF

echo "Remember to edit the .env file with secure passwords!"

# Configure Nginx
echo "Configuring Nginx..."
sudo bash -c 'cat > /etc/nginx/sites-available/printer-monitor << EOF
server {
    listen 80;
    server_name $HOSTNAME;

    location /api/ {
        proxy_pass http://localhost:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF'

# Enable the site
sudo ln -sf /etc/nginx/sites-available/printer-monitor /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Build and start the container
echo "Building Docker containers..."
sudo docker compose build
sudo docker compose up -d

echo "--------------------------------------"
echo "Installation complete!"
echo ""
echo "Access your server at: http://$HOSTNAME"
echo ""
echo "Important next steps:"
echo "1. Edit .env with secure passwords"
echo "2. Restart the application: sudo docker compose restart"
echo "3. Set up SSL with: sudo certbot --nginx -d $HOSTNAME"
echo "4. Implement a firewall: sudo ufw enable && sudo ufw allow 'Nginx Full' && sudo ufw allow ssh"
echo "--------------------------------------"