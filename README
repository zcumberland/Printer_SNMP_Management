# Printer Monitoring Server Installation Guide

This guide will walk you through installing the printer monitoring server on an Ubuntu system.

## Prerequisites

- Ubuntu 20.04 LTS or newer
- Root/sudo privileges
- Internet connection
- Domain name (optional, for production use)

## Option 1: Automated Installation (Recommended)

### 1. Download the installation script

```bash
curl -o install.sh https://raw.githubusercontent.com/zcumberland/Printer_SNMP_Management/main/Server/install.sh
```

### 2. Make the script executable

```bash
chmod +x install.sh
```

### 3. Run the installation script

```bash
./install.sh
```

### 4. Secure your configuration

After installation, edit the environment configuration file to set secure passwords:

```bash
nano ~/printer-monitor/.env
```

Change the following values:
- `DB_PASSWORD`: A secure database password
- `JWT_SECRET`: A long, random string for JWT token signing
- `DEFAULT_ADMIN_PASSWORD`: A secure password for the admin user

### 5. Restart the services to apply changes

```bash
cd ~/printer-monitor
docker-compose restart
```

## Option 2: Manual Installation

If you prefer to install the components manually, follow these steps:

### 1. Install system dependencies

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y docker.io docker-compose git curl nginx
```

### 2. Set up Docker

```bash
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
# Log out and log back in for this to take effect
```

### 3. Create the directory structure

```bash
mkdir -p ~/printer-monitor
cd ~/printer-monitor
mkdir -p models routes middleware
```

### 4. Create the server files

Create the main server file (`server.js`):

```javascript
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const dotenv = require('dotenv');
const path = require('path');
const { initializeDatabase } = require('./models/db');

// Load environment variables
dotenv.config();

// Create Express app
const app = express();

// Apply middleware
app.use(helmet()); // Security headers
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(morgan('combined')); // Request logging

// Import routes
const authRoutes = require('./routes/auth');
const agentRoutes = require('./routes/agents');
const printerRoutes = require('./routes/printers');
const dataRoutes = require('./routes/data');
const userRoutes = require('./routes/users');
const dashboardRoutes = require('./routes/dashboard');

// Define API routes
app.use('/api/auth', authRoutes);
app.use('/api/agents', agentRoutes);
app.use('/api/printers', printerRoutes);
app.use('/api/data', dataRoutes);
app.use('/api/users', userRoutes);
app.use('/api/dashboard', dashboardRoutes);

// Serve static files in production
if (process.env.NODE_ENV === 'production') {
  // Serve static files from the React frontend app
  app.use(express.static(path.join(__dirname, '../frontend/build')));
  
  // Handle React routing, return all requests to React app
  app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../frontend/build', 'index.html'));
  });
}

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    error: 'Server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'An unexpected error occurred'
  });
});

// Start the server
const PORT = process.env.PORT || 3000;

// Initialize database and then start server
initializeDatabase()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  })
  .catch(err => {
    console.error('Failed to start server:', err);
    process.exit(1);
  });
```

Create the database model (`models/db.js`):

```javascript
const { Pool } = require('pg');
const bcrypt = require('bcrypt');

// Create a new pool using environment variables
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'printer_monitor',
  password: process.env.DB_PASSWORD || 'postgres',
  port: process.env.DB_PORT || 5432,
});

// Initialize the database with tables
async function initializeDatabase() {
  const client = await pool.connect();
  try {
    // Create tables if they don't exist
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        password VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        role VARCHAR(20) NOT NULL DEFAULT 'user',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        last_login TIMESTAMP WITH TIME ZONE
      );

      CREATE TABLE IF NOT EXISTS agents (
        id SERIAL PRIMARY KEY,
        agent_id VARCHAR(100) UNIQUE NOT NULL,
        name VARCHAR(100) NOT NULL,
        hostname VARCHAR(100),
        ip_address VARCHAR(50),
        os_info VARCHAR(100),
        version VARCHAR(20),
        api_key VARCHAR(100) UNIQUE NOT NULL,
        status VARCHAR(20) DEFAULT 'active',
        last_seen TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS printers (
        id SERIAL PRIMARY KEY,
        agent_id INTEGER REFERENCES agents(id) ON DELETE CASCADE,
        ip_address VARCHAR(50) NOT NULL,
        serial_number VARCHAR(100),
        model VARCHAR(100),
        name VARCHAR(100),
        status VARCHAR(50) DEFAULT 'unknown',
        last_seen TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(agent_id, ip_address)
      );

      CREATE TABLE IF NOT EXISTS metrics (
        id SERIAL PRIMARY KEY,
        printer_id INTEGER REFERENCES printers(id) ON DELETE CASCADE,
        timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
        page_count INTEGER,
        toner_levels JSONB,
        status VARCHAR(50),
        error_state VARCHAR(100),
        raw_data JSONB
      );
    `);

    console.log('Database tables initialized');

    // Create an admin user if none exists
    const adminExists = await client.query(
      "SELECT COUNT(*) FROM users WHERE role = 'admin'"
    );
    
    if (parseInt(adminExists.rows[0].count) === 0) {
      const username = process.env.DEFAULT_ADMIN_USERNAME || 'admin';
      const email = process.env.DEFAULT_ADMIN_EMAIL || 'admin@example.com';
      const defaultPassword = process.env.DEFAULT_ADMIN_PASSWORD || 'admin123';
      const hashedPassword = await bcrypt.hash(defaultPassword, 10);
      
      await client.query(
        `INSERT INTO users (username, password, email, role) 
         VALUES ($1, $2, $3, $4)`,
        [username, hashedPassword, email, 'admin']
      );
      
      console.log('Created default admin user');
    }
  } catch (err) {
    console.error('Database initialization error:', err);
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  pool,
  initializeDatabase
};
```

Create the auth middleware (`middleware/auth.js`):

```javascript
const jwt = require('jsonwebtoken');
const { pool } = require('../models/db');

// User authentication middleware
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'your_jwt_secret', (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
}

// Role-based authorization middleware
function authorize(roles = []) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    if (roles.length && !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    
    next();
  };
}

// Agent authentication middleware
async function authenticateAgent(req, res, next) {
  const authHeader = req.headers['authorization'];
  const apiKey = authHeader && authHeader.split(' ')[1];
  
  if (!apiKey) {
    return res.status(401).json({ error: 'Agent authentication required' });
  }

  try {
    const result = await pool.query(
      'SELECT * FROM agents WHERE api_key = $1',
      [apiKey]
    );
    
    if (result.rows.length === 0) {
      return res.status(403).json({ error: 'Invalid agent API key' });
    }
    
    // Update last seen timestamp
    await pool.query(
      'UPDATE agents SET last_seen = NOW() WHERE id = $1',
      [result.rows[0].id]
    );
    
    req.agent = result.rows[0];
    next();
  } catch (err) {
    console.error('Agent authentication error:', err);
    return res.status(500).json({ error: 'Authentication error' });
  }
}

module.exports = {
  authenticateToken,
  authorize,
  authenticateAgent
};
```

Create the routes directory with necessary route files. See the full code in the repository.

### 5. Create package.json file

```bash
cat > package.json << 'EOF'
{
  "name": "printer-monitoring-server",
  "version": "1.0.0",
  "description": "Server for Printer SNMP Management System",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "author": "",
  "license": "MIT",
  "dependencies": {
    "bcrypt": "^5.1.0",
    "cors": "^2.8.5",
    "dotenv": "^16.0.3",
    "express": "^4.18.2",
    "helmet": "^6.0.1",
    "jsonwebtoken": "^9.0.0",
    "morgan": "^1.10.0",
    "pg": "^8.10.0",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "nodemon": "^2.0.22"
  }
}
EOF
```

### 6. Create configuration files

Create the `.env` file:

```bash
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
```

Create the `Dockerfile`:

```bash
cat > Dockerfile << 'EOF'
FROM node:16-alpine

WORKDIR /app

# Copy package.json and install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Create directory structure
RUN mkdir -p models routes middleware

# Copy server code
COPY server.js .
COPY models/ models/
COPY routes/ routes/
COPY middleware/ middleware/

# Expose the port
EXPOSE 3000

# Start the server
CMD ["node", "server.js"]
EOF
```

Create the `docker-compose.yml` file:

```bash
cat > docker-compose.yml << 'EOF'
version: '3'

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: printer-monitor-api
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
      - DB_USER=${DB_USER:-postgres}
      - DB_PASSWORD=${DB_PASSWORD:-postgres_password}
      - DB_HOST=db
      - DB_NAME=${DB_NAME:-printer_monitor}
      - DB_PORT=5432
      - JWT_SECRET=${JWT_SECRET:-change_this_in_production}
      - DEFAULT_ADMIN_USERNAME=${DEFAULT_ADMIN_USERNAME:-admin}
      - DEFAULT_ADMIN_PASSWORD=${DEFAULT_ADMIN_PASSWORD:-admin123}
      - DEFAULT_ADMIN_EMAIL=${DEFAULT_ADMIN_EMAIL:-admin@example.com}
    depends_on:
      - db
    networks:
      - printer-monitor-network

  db:
    image: postgres:14-alpine
    container_name: printer-monitor-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${DB_USER:-postgres}
      - POSTGRES_PASSWORD=${DB_PASSWORD:-postgres_password}
      - POSTGRES_DB=${DB_NAME:-printer_monitor}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - printer-monitor-network

networks:
  printer-monitor-network:
    driver: bridge

volumes:
  postgres_data:
EOF
```

### 7. Configure Nginx

Create an Nginx configuration file:

```bash
sudo nano /etc/nginx/sites-available/printer-monitor
```

Add the following content:

```nginx
server {
    listen 80;
    server_name your-domain.com;  # Replace with your domain or server IP

    location /api/ {
        proxy_pass http://localhost:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the site and restart Nginx:

```bash
sudo ln -sf /etc/nginx/sites-available/printer-monitor /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 8. Build and start the Docker containers

```bash
cd ~/printer-monitor
docker-compose build
docker-compose up -d
```

## Integrating the Server with Your Agent

### Creating the Agent Integration Module

Create a new file `agent_integration.py` in your agent directory:

```python
"""
Agent Integration Module for Printer Monitoring Server

This module provides functions to integrate your existing SNMP agent with the central server.
"""

import os
import uuid
import json
import time
import logging
import requests
import socket
from datetime import datetime

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("agent_server.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("AgentServer")

class ServerIntegration:
    """
    Handles the integration with the central server.
    """
    def __init__(self, server_url, agent_id=None, agent_name=None):
        """
        Initialize the server integration.
        
        Args:
            server_url (str): The URL of the central server API
            agent_id (str, optional): Unique ID for this agent, will be generated if not provided
            agent_name (str, optional): Name for this agent, defaults to hostname
        """
        self.server_url = server_url.rstrip('/')
        self.api_key = self._load_api_key()
        self.agent_id = agent_id or self._load_agent_id()
        self.agent_name = agent_name or socket.gethostname()
        self.registered = False
        
    def _load_api_key(self):
        """Load API key from file or return None"""
        try:
            if os.path.exists("agent_key.txt"):
                with open("agent_key.txt", "r") as f:
                    return f.read().strip()
        except Exception as e:
            logger.error(f"Error loading API key: {e}")
        return None
    
    def _save_api_key(self, api_key):
        """Save API key to file"""
        try:
            with open("agent_key.txt", "w") as f:
                f.write(api_key)
            logger.info("API key saved")
        except Exception as e:
            logger.error(f"Error saving API key: {e}")
    
    def _load_agent_id(self):
        """Load agent ID from file or generate a new one"""
        try:
            if os.path.exists("agent_id.txt"):
                with open("agent_id.txt", "r") as f:
                    return f.read().strip()
            else:
                # Generate new ID
                agent_id = str(uuid.uuid4())
                with open("agent_id.txt", "w") as f:
                    f.write(agent_id)
                return agent_id
        except Exception as e:
            logger.error(f"Error with agent ID: {e}")
            return str(uuid.uuid4())
    
    def register(self):
        """
        Register this agent with the central server.
        
        Returns:
            bool: Success or failure
        """
        try:
            # Prepare registration data
            data = {
                "agent_id": self.agent_id,
                "name": self.agent_name,
                "hostname": socket.gethostname(),
                "ip_address": socket.gethostbyname(socket.gethostname()),
                "os_info": os.name,
                "version": "1.0.0"
            }
            
            headers = {'Content-Type': 'application/json'}
            
            # If we have an API key, include it
            if self.api_key:
                headers['Authorization'] = f"Bearer {self.api_key}"
            
            # Make the request
            response = requests.post(
                f"{self.server_url}/api/agents/register",
                json=data,
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                if 'token' in result:
                    self.api_key = result['token']
                    self._save_api_key(self.api_key)
                
                self.registered = True
                logger.info("Successfully registered with server")
                return True
            else:
                logger.error(f"Registration failed: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"Error during registration: {e}")
            return False
    
    def send_printer_data(self, printer_data):
        """
        Send printer data to the server.
        
        Args:
            printer_data (dict): Dictionary with printer information
                {
                    'ip_address': str,
                    'serial_number': str,
                    'model': str,
                    'name': str
                }
        
        Returns:
            bool: Success or failure
        """
        if not self.api_key:
            logger.warning("No API key available, try registering first")
            return False
        
        try:
            # Ensure we have the minimum required data
            if 'ip_address' not in printer_data:
                logger.error("Printer data missing IP address")
                return False
            
            # Prepare data for server
            data = {
                'type': 'printer_discovery',
                'data': printer_data
            }
            
            headers = {
                'Authorization': f"Bearer {self.api_key}",
                'Content-Type': 'application/json'
            }
            
            # Send the data
            response = requests.post(
                f"{self.server_url}/api/data",
                json=data,
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                logger.info(f"Successfully sent printer data for {printer_data['ip_address']}")
                return True
            else:
                logger.error(f"Error sending printer data: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending printer data: {e}")
            return False
    
    def send_metrics(self, printer_id, metrics_data):
        """
        Send printer metrics to the server.
        
        Args:
            printer_id (int): ID of the printer in the database
            metrics_data (dict): Dictionary with metrics information
                {
                    'page_count': int,
                    'toner_levels': dict,
                    'status': str,
                    'error_state': str,
                    'timestamp': str (ISO format)
                }
        
        Returns:
            bool: Success or failure
        """
        if not self.api_key:
            logger.warning("No API key available, try registering first")
            return False
        
        try:
            # Ensure we have required data
            if not metrics_data:
                logger.error("No metrics data provided")
                return False
                
            # Make sure timestamp is in ISO format
            if 'timestamp' not in metrics_data:
                metrics_data['timestamp'] = datetime.now().isoformat()
            
            # Convert toner_levels to JSON string if it's a dict
            if 'toner_levels' in metrics_data and isinstance(metrics_data['toner_levels'], dict):
                metrics_data['toner_levels'] = json.dumps(metrics_data['toner_levels'])
            
            # Prepare data for server
            data = {
                'type': 'metrics',
                'printer_id': printer_id,
                'data': metrics_data
            }
            
            headers = {
                'Authorization': f"Bearer {self.api_key}",
                'Content-Type': 'application/json'
            }
            
            # Send the data
            response = requests.post(
                f"{self.server_url}/api/data",
                json=data,
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                logger.info(f"Successfully sent metrics data for printer ID {printer_id}")
                return True
            else:
                logger.error(f"Error sending metrics data: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending metrics data: {e}")
            return False
    
    def get_server_config(self):
        """
        Get configuration from the server.
        
        Returns:
            dict: Configuration settings or None on failure
        """
        if not self.api_key:
            logger.warning("No API key available, try registering first")
            return None
        
        try:
            headers = {
                'Authorization': f"Bearer {self.api_key}",
                'Content-Type': 'application/json'
            }
            
            response = requests.get(
                f"{self.server_url}/api/data/config",
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                config = response.json()
                logger.info("Successfully retrieved server configuration")
                return config
            else:
                logger.error(f"Error getting config: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"Error getting server config: {e}")
            return None
```

### Usage in Your Agent Code

Update your agent code to use the integration module:

```python
from agent_integration import ServerIntegration

# Initialize server connection
server = ServerIntegration(
    server_url="http://your-server-url.com",
    agent_name="Customer Site Name"
)

# Register with server
if not server.registered:
    success = server.register()
    if not success:
        print("Failed to register with server")

# When you discover a printer:
printer_data = {
    'ip_address': '192.168.1.100',
    'serial_number': 'ABC123456',
    'model': 'HP LaserJet Pro M404dn',
    'name': 'Office Printer'
}
server.send_printer_data(printer_data)

# When you collect metrics:
metrics_data = {
    'page_count': 12345,
    'toner_levels': {
        'black': 75,
        'cyan': 80,
        'magenta': 90,
        'yellow': 85
    },
    'status': 'ready',
    'error_state': None,
    'timestamp': datetime.now().isoformat()
}
server.send_metrics(1, metrics_data)  # 1 is the printer ID from the server
```

## Post-Installation Steps

### 1. Secure your server with SSL (recommended for production)

Install Certbot and obtain an SSL certificate:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### 2. Set up a firewall

```bash
sudo ufw enable
sudo ufw allow 'Nginx Full'
sudo ufw allow ssh
```

### 3. Access the web interface

Visit your server in a web browser:
- http://your-domain.com (or https:// if you set up SSL)
- or http://your-server-ip if you don't have a domain

Log in with the admin credentials specified in your .env file:
- Username: admin
- Password: (the one you set in the .env file)

## Troubleshooting

### Check container status

```bash
docker ps
docker-compose ps
```

### View container logs

```bash
docker-compose logs api
docker-compose logs db
```

### Database issues

Connect to the database container:

```bash
docker exec -it printer-monitor-db psql -U postgres -d printer_monitor
```

Check if tables were created:

```sql
\dt
```

### Restart the services

```bash
cd ~/printer-monitor
docker-compose restart
```

## Maintenance

### Updating the server

Pull the latest code and rebuild:

```bash
cd ~/printer-monitor
git pull origin main
docker-compose down
docker-compose build
docker-compose up -d
```

### Backing up the database

```bash
cd ~/printer-monitor
docker exec -t printer-monitor-db pg_dumpall -c -U postgres > backup.sql
```

### Restoring the database from backup

```bash
cat backup.sql | docker exec -i printer-monitor-db psql -U postgres
```
