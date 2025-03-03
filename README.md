# Printer SNMP Management System

A comprehensive solution for monitoring and managing networked printers using SNMP.

## Project Components

### Agent
- Python-based agent for discovering and monitoring printers via SNMP
- Collects metrics like toner levels, page counts, and printer status
- Sends data to central server
- Works on Windows and Linux

### Server
- Node.js backend with Express
- RESTful API for data collection and management
- Authentication and user management
- PostgreSQL database for data storage

### Frontend
- React-based web interface
- Dashboard for printer monitoring
- User and organization management
- Responsive design using Material UI

## Setup Instructions

### Complete System Setup (Server + Frontend)

**Linux:**
```bash
cd Printer_SNMP_Management
chmod +x scripts/setup_all.sh
./scripts/setup_all.sh
```

**Windows:**
```
cd Printer_SNMP_Management
scripts\setup_all.bat
```
Note: The Windows install scripts will check for prerequisites like Node.js and Docker and provide instructions if they're missing.

### Individual Component Setup

#### Server Setup

**Linux:**
```bash
cd Printer_SNMP_Management
chmod +x scripts/setup_server.sh
./scripts/setup_server.sh
```

**Windows:**
```
cd Printer_SNMP_Management
scripts\setup_server.bat
```
The server setup will generate secure random passwords for the admin user and database.

#### Frontend Setup

**Linux:**
```bash
cd Printer_SNMP_Management
chmod +x scripts/setup_frontend.sh
./scripts/setup_frontend.sh
```

**Windows:**
```
cd Printer_SNMP_Management
scripts\setup_frontend.bat
```

#### Agent Setup

**Linux:**
```bash
cd Printer_SNMP_Management/Agent
chmod +x ../scripts/setup_agent.sh
../scripts/setup_agent.sh http://your-server-ip:3000/api
```

**Windows:**
```
cd Printer_SNMP_Management\Agent
setup_windows.bat http://your-server-ip:3000/api
```

## Running the System

### Development Mode

**Linux:**
```bash
# From the project root
./start_dev.sh

# Or individually
cd Server && ./run_dev.sh  # Terminal 1
cd FrontEnd && ./run_dev.sh # Terminal 2
```

**Windows:**
```
# From the project root
start_dev.bat

# Or individually
cd Server && run_dev.bat
cd FrontEnd && run_dev.bat
```

### Production Mode

**Linux:**
```bash
# From the project root
./start_production.sh

# Or just the server with Docker
cd Server && ./run_docker.sh
```

**Windows:**
```
# From the project root
start_production.bat

# Or just the server with Docker
cd Server && run_docker.bat
```

### Agent

**Linux:**
```bash
cd Agent
./run_agent.sh

# For discovery only
./discover_printers.sh
```

**Windows:**
```
cd Agent
run_agent.bat

# For discovery only
discover_printers.bat
```

## System Requirements
- Server: Node.js 16+, PostgreSQL 14+ (or Docker)
- Frontend: Node.js 16+
- Agent: Python 3.8+, PySNMP

## Security Notes
- Default credentials are for development only
- Change all default passwords and JWT secrets in production
- Use environment variables for sensitive configuration

## Directory Structure

```
Printer_SNMP_Management/
├── Agent/                   # SNMP monitoring agent
│   ├── agent_integration.py # Server communication
│   ├── config.ini           # Agent configuration
│   ├── data_collector.py    # Core monitoring functionality
│   ├── db_setup.py          # Database initialization
│   ├── requirements.txt     # Python dependencies
│   └── setup_windows.bat    # Windows installation script
├── FrontEnd/                # React web interface
│   ├── dockerfile.frontend  # Docker configuration
│   ├── nginx.conf           # Web server config
│   ├── package.json         # Node.js dependencies
│   └── src/                 # React source code
├── README.md                # This documentation
├── Server/                  # Backend API server
│   ├── compose.yml          # Docker Compose config
│   ├── dockerfile           # Docker configuration
│   ├── middleware/          # Express middleware
│   ├── models/              # Database models
│   ├── package.json         # Node.js dependencies
│   ├── routes/              # API endpoints
│   └── server.js            # Main server entry point
└── scripts/                 # Installation scripts
    ├── setup_agent.sh       # Agent setup (Linux)
    ├── setup_all.bat        # Full setup (Windows)
    ├── setup_all.sh         # Full setup (Linux)
    ├── setup_frontend.bat   # Frontend setup (Windows)
    ├── setup_frontend.sh    # Frontend setup (Linux)
    ├── setup_server.bat     # Server setup (Windows)
    └── setup_server.sh      # Server setup (Linux)
```

## Troubleshooting

### Common Issues

#### Agent Cannot Connect to Server
- Verify the server URL in the agent's config.ini
- Check if the server is running and accessible
- Ensure network connectivity between agent and server
- Verify firewall settings allow connections

#### Server Database Connection Issues
- Verify database credentials in the .env file
- Check if PostgreSQL is running
- Ensure the database is created

#### Frontend Not Loading
- Check browser console for errors
- Verify the server is running
- Check proxy configuration in package.json

### Getting Help
If you encounter issues not covered here, please open an issue on the project repository.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.