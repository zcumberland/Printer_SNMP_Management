#!/bin/bash
# Script to set up the Printer Monitoring Server

# Exit on any error
set -e

echo "Setting up Printer Monitoring Server..."
echo "--------------------------------------"

# Check if Node.js is installed
if ! command -v node &> /dev/null
then
    echo "Node.js is not installed. Installing..."
    curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js is already installed"
fi

# Navigate to server directory
cd ../Server

# Install dependencies
echo "Installing dependencies..."
npm install

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker is not installed. Installing..."
    # Install dependencies for Docker installation
    sudo apt-get update
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up the Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update apt package index
    sudo apt-get update

    # Install Docker Engine, containerd, and Docker Compose plugin
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Setup Docker
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    echo "You may need to log out and log back in for Docker permissions to take effect"
else
    echo "Docker is already installed"
fi

# Check for .env file
if [ ! -f ".env" ]; then
    echo "Creating default .env file..."
    cat > .env << 'EOF'
# Server Configuration
PORT=3000
NODE_ENV=development

# Database Configuration
DB_USER=postgres
DB_PASSWORD=postgres_password
DB_HOST=localhost
DB_NAME=printer_monitor
DB_PORT=5432

# JWT Configuration
JWT_SECRET=your_jwt_secret_key_change_this_in_production
JWT_EXPIRES_IN=24h

# Admin User
DEFAULT_ADMIN_USERNAME=admin
DEFAULT_ADMIN_PASSWORD=admin123
DEFAULT_ADMIN_EMAIL=admin@example.com
EOF
    echo "Default .env file created. Please update with secure passwords!"
fi

# Check for PostgreSQL
if ! command -v psql &> /dev/null && ! command -v docker compose &> /dev/null
then
    echo "PostgreSQL is not installed and Docker Compose is not available."
    echo "Installing PostgreSQL locally..."
    sudo apt-get install -y postgresql postgresql-contrib
    
    # Start PostgreSQL service
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    
    # Create database user and database
    echo "Creating database and user..."
    sudo -u postgres psql -c "CREATE USER ${DB_USER:-postgres} WITH PASSWORD '${DB_PASSWORD:-postgres_password}';"
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME:-printer_monitor} OWNER ${DB_USER:-postgres};"
else
    # Try to use Docker Compose if available
    if command -v docker compose &> /dev/null
    then
        echo "Using Docker Compose to set up PostgreSQL..."
        
        # Create a temporary docker-compose file for just the database
        cat > docker-compose.db.yml << 'EOF'
services:
  db:
    image: postgres:14-alpine
    container_name: printer-monitor-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${DB_USER:-postgres}
      - POSTGRES_PASSWORD=${DB_PASSWORD:-postgres_password}
      - POSTGRES_DB=${DB_NAME:-printer_monitor}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
EOF
        
        # Start just the database service
        docker compose -f docker-compose.db.yml up -d
        
        # Wait for PostgreSQL to be ready
        echo "Waiting for PostgreSQL to be ready..."
        sleep 10
    fi
fi

echo "--------------------------------------"
echo "Server setup complete!"
echo ""
echo "For development:"
echo "  npm run dev"
echo ""
echo "For production:"
echo "  npm start"
echo ""
echo "Or use Docker Compose:"
echo "  docker compose up -d"
echo "--------------------------------------"