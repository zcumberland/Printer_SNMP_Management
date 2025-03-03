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
        self.registered = self.api_key is not None
        
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
                result = response.json()
                logger.info(f"Successfully sent printer data for {printer_data['ip_address']}")
                
                # If server returns an ID for this printer, return it
                if 'printer_id' in result:
                    return result['printer_id']
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
                f"{self.server_url}/api/agents/config/{self.agent_id}",
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
            
    def get_config(self):
        """Alias for get_server_config for compatibility"""
        return self.get_server_config()