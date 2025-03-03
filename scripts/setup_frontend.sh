#!/bin/bash
# Printer SNMP Management - Frontend Setup Script
# Works on Linux systems including ARM-based and common distributions

set -e

echo "========================================================="
echo "Printer SNMP Management - Frontend Setup"
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
}

# Install dependencies
install_dependencies

# Navigate to frontend directory
cd "$(dirname "$0")/../FrontEnd"
FRONTEND_DIR=$(pwd)
echo "Setting up frontend in: $FRONTEND_DIR"

# Install npm dependencies
echo "Installing npm dependencies..."
npm install

# Configure proxy for development
if grep -q "\"proxy\":" package.json; then
    echo "Proxy configuration already exists in package.json"
else
    # Add proxy configuration to package.json if not present
    echo "Adding proxy configuration to package.json..."
    # Using temporary file to handle the manipulation
    jq '.proxy = "http://localhost:3000"' package.json > package.json.tmp
    mv package.json.tmp package.json
fi

# Create startup scripts
echo "Creating startup scripts..."

# Create run script for development
cat > run_dev.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
npm start
EOF
chmod +x run_dev.sh

# Create build script 
cat > build.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
npm run build
EOF
chmod +x build.sh

# Create Windows batch script for development
cat > run_dev.bat << 'EOF'
@echo off
cd %~dp0
npm start
EOF

# Create Windows batch script for building
cat > build.bat << 'EOF'
@echo off
cd %~dp0
npm run build
EOF

echo "========================================================="
echo "Frontend setup complete!"
echo ""
echo "For development mode:"
echo "  ./run_dev.sh or run_dev.bat (Windows)"
echo "  This will start the development server at http://localhost:3000"
echo ""
echo "To build for production:"
echo "  ./build.sh or build.bat (Windows)"
echo "  This will create a production build in the 'build' directory"
echo ""
echo "NOTE: Make sure the backend server is running before using the frontend."
echo "========================================================="