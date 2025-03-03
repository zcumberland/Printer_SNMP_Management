# Printer SNMP Management System

A comprehensive solution for monitoring and managing printers across multiple locations via SNMP. The system consists of a central server, distributed agents, and a web frontend.

## Overview

This system allows IT administrators and managed service providers to monitor printer status, toner levels, page counts, and other metrics remotely. The architecture supports multi-tenant deployment with organization separation.

### Key Features

- **Centralized Dashboard**: Monitor all printers across multiple locations
- **Printer Discovery**: Automatic discovery of printers on the network
- **SNMP Monitoring**: Track printer metrics including page counts, toner levels, and status
- **Multi-tenant**: Separate organizations with isolated data
- **Role-based Access Control**: Admin and user roles with appropriate permissions
- **Distributed Agents**: Deploy lightweight agents at customer sites
- **Alerts & Notifications**: Get notified of printer issues and low supplies

## Components

The system consists of three main components:

### Central Server

- **REST API**: Provides endpoints for the frontend and agents
- **Database**: Stores printer information, metrics, users, and configuration
- **Authentication**: Handles user authentication and authorization

### Monitoring Agents

- **Printer Discovery**: Finds printers on configured network segments
- **SNMP Polling**: Collects metrics from printers at regular intervals
- **Local Database**: Stores data locally when offline
- **Data Synchronization**: Sends metrics to the central server

### Web Frontend

- **Dashboard**: Visualize printer metrics and status
- **Printer Management**: View and manage printers
- **User Management**: Add, remove, and manage user permissions
- **Organization Management**: Configure customer organizations
- **Agent Configuration**: Configure agent polling settings

## Installation

Follow these steps to set up the complete system:

### Server Setup

1. Ensure you have Docker and Docker Compose installed
2. Clone this repository
3. Navigate to the Server directory: `cd Server`
4. Run the installation script: `./install.sh`

This will start the server and database containers.

### Agent Setup

For each location where you want to monitor printers:

1. Copy the Agent directory to a computer on the network
2. Install Python 3.6+ if not already installed
3. Install requirements: `pip install -r requirements.txt`
4. Configure the agent: Edit `config.ini` with server URL and network settings
5. Run the agent: `python data_collector.py`

For automated installation, use the provided script:
```
./scripts/setup_agent.sh <server_url>
```

### Frontend Setup

The frontend can be installed separately or as part of the server:

1. Navigate to the Frontend directory: `cd Frontend`
2. Install dependencies: `npm install`
3. Build the frontend: `npm run build`
4. Configure nginx: Edit `nginx.conf` with your server URL
5. Start the frontend: `docker-compose up -d`

## Development

### Server

The server uses Node.js with Express. To run in development mode:

```
cd Server
npm install
npm run dev
```

### Agent

The agent is written in Python. To run in development mode:

```
cd Agent
pip install -r requirements.txt
python data_collector.py --discover
```

### Frontend

The frontend is built with React. To run in development mode:

```
cd Frontend
npm install
npm start
```

## Configuration

### Server

Server configuration is managed through environment variables. See `Server/compose.yml`.

### Agent

Agent configuration is in `Agent/config.ini`. You can configure:

- Network subnets to scan
- SNMP community string
- Polling intervals
- Server connection details

## License

This project is licensed under the MIT License - see the LICENSE file for details.