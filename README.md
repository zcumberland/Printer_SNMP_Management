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
./scripts/start_dev.sh

# Or individually
cd scripts && ./run_server.sh  # Terminal 1
cd scripts && ./run_frontend.sh # Terminal 2
cd scripts && ./run_agent.sh # Terminal 3 (if needed)
```

**Windows:**
```
# From the project root
scripts\start_dev.bat

# Or individually
cd scripts && run_server.bat
cd scripts && run_frontend.bat
cd scripts && run_agent.bat
```

### Production Mode

**Linux:**
```bash
# From the project root
./scripts/start_prod.sh

# Or using Docker
./scripts/start_docker.sh
```

**Windows:**
```
# From the project root
scripts\start_prod.bat

# Or using Docker
scripts\start_docker.bat
```

### Agent

**Linux:**
```bash
# From the project root
./scripts/run_agent.sh

# Or from the scripts directory
cd scripts && ./run_agent.sh
```

**Windows:**
```
# From the project root
scripts\run_agent.bat

# Or from the scripts directory
cd scripts && run_agent.bat
```

## System Requirements
- Server: Node.js 18+, PostgreSQL 14+ (or Docker)
- Frontend: Node.js 18+
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
└── scripts/                 # Installation and runtime scripts
    ├── run_agent.bat        # Run agent (Windows)
    ├── run_agent.sh         # Run agent (Linux)
    ├── run_all.bat          # Run all components (Windows)
    ├── run_all.sh           # Run all components (Linux)
    ├── run_frontend.bat     # Run frontend (Windows)
    ├── run_frontend.sh      # Run frontend (Linux)
    ├── run_server.bat       # Run server (Windows)
    ├── run_server.sh        # Run server (Linux)
    ├── setup_agent.sh       # Agent setup (Linux)
    ├── setup_all.bat        # Full setup (Windows)
    ├── setup_all.sh         # Full setup (Linux)
    ├── setup_frontend.bat   # Frontend setup (Windows)
    ├── setup_frontend.sh    # Frontend setup (Linux)
    ├── setup_server.bat     # Server setup (Windows)
    ├── setup_server.sh      # Server setup (Linux)
    ├── start_dev.bat        # Start dev environment (Windows)
    ├── start_dev.sh         # Start dev environment (Linux)
    ├── start_docker.bat     # Start Docker environment (Windows)
    ├── start_docker.sh      # Start Docker environment (Linux)
    ├── start_prod.bat       # Start production environment (Windows)
    └── start_prod.sh        # Start production environment (Linux)
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