#!/bin/bash
# Printer SNMP Management - Server Setup Script
# Works on Linux systems including ARM-based and common distributions

set -e

echo "========================================================="
echo "Printer SNMP Management - Server Setup"
echo "========================================================="

# Function to check and install packages based on distribution
install_dependencies() {
    echo "Checking system and installing dependencies..."
    
    # Install Node.js if not installed
    if ! command -v node &> /dev/null; then
        echo "Node.js not found. Installing..."
        
        if command -v apt &> /dev/null; then
            # Debian/Ubuntu
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt install -y nodejs
        elif command -v dnf &> /dev/null; then
            # Fedora/RHEL/CentOS 8+
            curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
            sudo dnf install -y nodejs
        elif command -v yum &> /dev/null; then
            # Older RHEL/CentOS
            curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
            sudo yum install -y nodejs
        elif command -v pacman &> /dev/null; then
            # Arch Linux
            sudo pacman -Sy nodejs npm
        elif command -v zypper &> /dev/null; then
            # openSUSE
            sudo zypper install -y nodejs npm
        else
            echo "Unsupported package manager. Please install Node.js manually."
            exit 1
        fi
    else
        echo "Node.js is already installed: $(node -v)"
    fi
    
    # Install Docker if not installed
    if ! command -v docker &> /dev/null; then
        echo "Docker not found."
        
        # Check if running in WSL
        if grep -q Microsoft /proc/version; then
            echo "WSL detected. Docker Desktop for Windows is recommended."
            echo "Please install Docker Desktop from https://www.docker.com/products/docker-desktop/"
            echo "Skipping Docker installation. You can continue setup without Docker."
            echo "Once Docker Desktop is installed, run 'docker --version' to verify the installation."
        else
            echo "Installing Docker..."
            if command -v apt &> /dev/null; then
                # Debian/Ubuntu
                sudo apt update
                sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt update
                sudo apt install -y docker-ce docker-ce-cli containerd.io
            elif command -v dnf &> /dev/null; then
                # Fedora
                sudo dnf -y install dnf-plugins-core
                sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                sudo dnf install -y docker-ce docker-ce-cli containerd.io
            elif command -v yum &> /dev/null; then
                # RHEL/CentOS
                sudo yum install -y yum-utils
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                sudo yum install -y docker-ce docker-ce-cli containerd.io
            elif command -v pacman &> /dev/null; then
                # Arch Linux
                sudo pacman -Sy docker
            elif command -v zypper &> /dev/null; then
                # openSUSE
                sudo zypper install -y docker
            else
                echo "Unsupported package manager. Please install Docker manually."
                exit 1
            fi
            
            # Start and enable Docker service
            sudo systemctl start docker
            sudo systemctl enable docker
            
            # Add current user to docker group
            sudo usermod -aG docker $USER
            echo "Docker installed. You may need to log out and back in for docker group permissions to take effect."
        fi
    else
        echo "Docker is already installed: $(docker --version)"
    fi
    
    # Install Docker Compose if not installed
    if ! command -v docker-compose &> /dev/null && ! command -v docker compose &> /dev/null; then
        echo "Docker Compose not found. Installing..."
        
        if command -v apt &> /dev/null || command -v dnf &> /dev/null || command -v yum &> /dev/null || command -v pacman &> /dev/null || command -v zypper &> /dev/null; then
            DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
            mkdir -p $DOCKER_CONFIG/cli-plugins
            COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
            ARCH=$(uname -m)
            if [ "$ARCH" = "aarch64" ]; then
                ARCH="aarch64"
            elif [ "$ARCH" = "x86_64" ]; then
                ARCH="x86_64"
            else
                ARCH="$(uname -m)"
            fi
            sudo curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${ARCH}" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        else
            echo "Unsupported package manager. Please install Docker Compose manually."
            exit 1
        fi
    else
        echo "Docker Compose is already installed."
    fi
}

# Install dependencies
install_dependencies

# Navigate to server directory
cd "$(dirname "$0")/../../Server"
SERVER_DIR=$(pwd)
echo "Setting up server in: $SERVER_DIR"

# Setup .env file
if [ ! -f ".env" ]; then
    echo "Creating .env file..."
    # Generate a secure random JWT secret
    JWT_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
    # Generate a secure random DB password
    DB_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
    # Generate a secure random admin password
    ADMIN_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12)
    
    cat > .env << EOF
# Database Configuration
DB_USER=postgres
DB_PASSWORD=$DB_PASSWORD
DB_HOST=db
DB_NAME=printer_monitor
DB_PORT=5432

# JWT Configuration
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=24h

# Admin User
DEFAULT_ADMIN_USERNAME=admin
DEFAULT_ADMIN_PASSWORD=$ADMIN_PASSWORD
DEFAULT_ADMIN_EMAIL=admin@example.com

# Server Configuration
PORT=3000
NODE_ENV=production
EOF

    echo "Created .env file with secure randomly generated passwords."
    echo "Admin username: admin"
    echo "Admin password: $ADMIN_PASSWORD"
    echo "Please save these credentials securely!"
else
    echo ".env file already exists. Keeping existing configuration."
fi

# Install npm dependencies
echo "Installing npm dependencies..."
npm install

# Create startup scripts
echo "Creating startup scripts..."

# Create run script for development
cat > run_dev.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
npm run dev
EOF
chmod +x run_dev.sh

# Create run script for production with Docker
cat > run_docker.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
docker compose down
docker compose up -d
EOF
chmod +x run_docker.sh

# Create Windows batch script for development
cat > run_dev.bat << 'EOF'
@echo off
cd %~dp0
npm run dev
EOF

# Create Windows batch script for production with Docker
cat > run_docker.bat << 'EOF'
@echo off
cd %~dp0
docker compose down
docker compose up -d
EOF

echo "========================================================="
echo "Server setup complete!"
echo ""
echo "For development mode:"
echo "  ./run_dev.sh or run_dev.bat (Windows)"
echo ""
echo "For production mode (with Docker):"
echo "  ./run_docker.sh or run_docker.bat (Windows)"
echo ""
echo "Admin credentials (save these):"
echo "  Username: admin"
echo "  Password: $(grep DEFAULT_ADMIN_PASSWORD .env | cut -d '=' -f2)"
echo ""
echo "These credentials will be needed to log in to the system."
echo "Make sure all necessary ports (3000, 80) are open in your firewall."
echo "========================================================="