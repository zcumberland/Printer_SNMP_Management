#!/bin/bash
# Printer SNMP Management - Installer Script
# This script can be run directly via curl/wget:
# curl -fsSL https://raw.githubusercontent.com/zcumberland/Printer_SNMP_Management/master/install.sh | bash
# or
# wget -qO- https://raw.githubusercontent.com/zcumberland/Printer_SNMP_Management/master/install.sh | bash

set -e

echo "========================================================="
echo "Printer SNMP Management - Installation Script"
echo "========================================================="

# Check for required tools
check_requirements() {
    echo "Checking requirements..."
    
    # Check for git
    if ! command -v git &> /dev/null; then
        echo "Git is not installed. Installing..."
        if command -v apt &> /dev/null; then
            sudo apt update
            sudo apt install -y git
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y git
        elif command -v yum &> /dev/null; then
            sudo yum install -y git
        elif command -v pacman &> /dev/null; then
            sudo pacman -Sy --noconfirm git
        elif command -v zypper &> /dev/null; then
            sudo zypper install -y git
        else
            echo "Unsupported package manager. Please install git manually and run this script again."
            exit 1
        fi
    fi
    
    # Check for Node.js
    if ! command -v node &> /dev/null; then
        echo "Node.js is not installed. Installing..."
        if command -v apt &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt install -y nodejs
        elif command -v dnf &> /dev/null; then
            curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
            sudo dnf install -y nodejs
        elif command -v yum &> /dev/null; then
            curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
            sudo yum install -y nodejs
        elif command -v pacman &> /dev/null; then
            sudo pacman -Sy --noconfirm nodejs npm
        elif command -v zypper &> /dev/null; then
            sudo zypper install -y nodejs nodejs-devel
        else
            echo "Unsupported package manager. Please install Node.js manually."
            exit 1
        fi
    fi
    
    # Check for Python
    if ! command -v python3 &> /dev/null; then
        echo "Python 3 is not installed. Installing..."
        if command -v apt &> /dev/null; then
            sudo apt update
            sudo apt install -y python3 python3-pip python3-venv
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y python3 python3-pip
        elif command -v yum &> /dev/null; then
            sudo yum install -y python3 python3-pip
        elif command -v pacman &> /dev/null; then
            sudo pacman -Sy --noconfirm python python-pip
        elif command -v zypper &> /dev/null; then
            sudo zypper install -y python3 python3-pip
        else
            echo "Unsupported package manager. Please install Python 3 manually."
            exit 1
        fi
    fi
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Do you want to install it? (y/n)"
        read -r install_docker
        if [[ "$install_docker" =~ ^[Yy]$ ]]; then
            echo "Installing Docker..."
            
            # Check if running in WSL
            if grep -q Microsoft /proc/version; then
                echo "WSL detected. Docker Desktop for Windows is recommended."
                echo "Please install Docker Desktop from https://www.docker.com/products/docker-desktop/"
                echo "Skipping Docker installation. You can continue setup without Docker."
                echo "Once Docker Desktop is installed, run 'docker --version' to verify the installation."
            else
                # Install Docker on non-WSL Linux
                curl -fsSL https://get.docker.com | sh
                
                # Add current user to docker group
                sudo usermod -aG docker $(whoami)
                echo "Please log out and back in for Docker group changes to take effect."
            fi
        else
            echo "Skipping Docker installation. Note that production mode requires Docker."
        fi
    fi
}

# Clone the repository
clone_repository() {
    echo "Cloning the repository..."
    
    # Ask for installation directory
    read -p "Enter installation directory (default: $HOME/Printer_SNMP_Management): " INSTALL_DIR
    INSTALL_DIR=${INSTALL_DIR:-$HOME/Printer_SNMP_Management}
    
    if [ -d "$INSTALL_DIR" ]; then
        echo "Directory already exists. Do you want to overwrite? (y/n)"
        read -r overwrite
        if [[ "$overwrite" =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
        else
            echo "Installation aborted."
            exit 1
        fi
    fi
    
    # Clone the repository
    git clone https://github.com/zcumberland/Printer_SNMP_Management.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
}

# Setup the system components
setup_system() {
    echo "Setting up the system..."
    
    # Run the setup script
    cd "$INSTALL_DIR"
    bash scripts/Linux/setup_all.sh
    
    # Create a symbolic link to the start scripts
    sudo ln -sf "$INSTALL_DIR/start_dev.sh" /usr/local/bin/printer-monitor-dev
    sudo ln -sf "$INSTALL_DIR/start_prod.sh" /usr/local/bin/printer-monitor-prod
    
    # Make sure scripts are executable
    find "$INSTALL_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
    chmod +x "$INSTALL_DIR/start_dev.sh" "$INSTALL_DIR/start_prod.sh"
}

# Main installation process
main() {
    check_requirements
    clone_repository
    setup_system
    
    echo "========================================================="
    echo "Installation Complete!"
    echo ""
    echo "To start the system in development mode:"
    echo "  printer-monitor-dev"
    echo "  or: $INSTALL_DIR/start_dev.sh"
    echo ""
    echo "To start the system in production mode (requires Docker):"
    echo "  printer-monitor-prod"
    echo "  or: $INSTALL_DIR/start_prod.sh"
    echo ""
    echo "Admin credentials:"
    echo "  Username: admin"
    echo "  Password: $(grep DEFAULT_ADMIN_PASSWORD "$INSTALL_DIR/Server/.env" | cut -d '=' -f2)"
    echo ""
    echo "For more information, see the README file: $INSTALL_DIR/README.md"
    echo "========================================================="
}

# Run the script
main