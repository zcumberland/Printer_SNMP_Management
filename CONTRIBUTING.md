# Contributing to Printer SNMP Management

Thank you for considering contributing to the Printer SNMP Management project! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful to other contributors and maintainers. Create a positive environment for collaboration.

## How to Contribute

### Reporting Bugs

If you find a bug in the software, please create an issue with:

1. A clear, descriptive title
2. A detailed description of the issue
3. Steps to reproduce the bug
4. Expected vs. actual behavior
5. Screenshots if applicable
6. System information (OS, browser, etc.)

### Suggesting Enhancements

Feature requests are welcome. Please create an issue with:

1. A clear, descriptive title
2. A detailed description of the proposed feature
3. Any potential implementation details
4. Why this feature would be useful to most users

### Pull Requests

1. Fork the repository
2. Create a new branch for your changes
3. Make your changes
4. Write or update tests as needed
5. Ensure your code follows the project's style
6. Submit a pull request

## Development Setup

### Server and Frontend

1. Clone the repository
2. Run the appropriate setup script for your platform
   ```
   # Linux
   ./scripts/setup_server.sh
   ./scripts/setup_frontend.sh
   
   # Windows
   scripts\setup_server.bat
   scripts\setup_frontend.bat
   ```
3. Start in development mode
   ```
   # Linux
   cd Server && ./run_dev.sh
   cd FrontEnd && ./run_dev.sh
   
   # Windows
   cd Server && run_dev.bat
   cd FrontEnd && run_dev.bat
   ```

### Agent Development

1. Set up the development environment
   ```
   # Linux
   cd Agent
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   
   # Windows
   cd Agent
   python -m venv venv
   venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. Run the agent for testing
   ```
   python data_collector.py --discover
   ```

## Project Structure

- **Agent/**: Python SNMP monitoring agent
- **Server/**: Node.js backend server
- **FrontEnd/**: React web interface
- **scripts/**: Setup and installation scripts

## Coding Guidelines

### General

- Use meaningful variable and function names
- Write comments for complex logic
- Follow the existing code style

### Python (Agent)

- Follow PEP 8 guidelines
- Use docstrings for modules, classes, and functions
- Handle exceptions appropriately

### JavaScript (Server & Frontend)

- Use ES6+ features
- Follow ESLint guidelines
- Use meaningful component names
- Document API endpoints

## Testing

Please write tests for your code when applicable:

- Agent: Use unittest or pytest
- Server: Use Jest
- Frontend: Use Jest and React Testing Library

## Documentation

Update documentation when you change functionality:

- Update README.md for user-facing changes
- Update inline code documentation
- Update API documentation for endpoints

## Questions?

If you have questions about contributing, please create an issue with the "question" label.