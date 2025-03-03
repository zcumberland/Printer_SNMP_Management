#!/usr/bin/env python3
"""
Printer SNMP Data Collector

This script discovers printers on the network and collects information using SNMP.
It stores the data locally and can send it to a central server.
"""

import os
import sys
import time
import json
import logging
import socket
import uuid
import sqlite3
import ipaddress
import argparse
import configparser
from datetime import datetime
from threading import Thread, Lock
import schedule

# Import the SNMP library
try:
    from pysnmp.hlapi import *
except ImportError:
    print("Error: pysnmp library not found. Install it using 'pip install pysnmp'")
    sys.exit(1)

# Import the server integration module (if available)
try:
    from agent_integration import ServerIntegration
    SERVER_INTEGRATION_AVAILABLE = True
except ImportError:
    SERVER_INTEGRATION_AVAILABLE = False

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("printer_monitor.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("PrinterCollector")

# Default configuration
DEFAULT_CONFIG = {
    "agent": {
        "id": str(uuid.uuid4()),
        "name": socket.gethostname(),
        "polling_interval": 300,  # seconds
        "discovery_interval": 86400,  # 24 hours in seconds
        "data_dir": "./data"
    },
    "server": {
        "enabled": False,
        "url": "http://your-server-url.com/api",
    },
    "network": {
        "subnets": ["192.168.1.0/24"],
        "snmp_community": "public",
        "snmp_timeout": 2
    }
}

class PrinterCollector:
    def __init__(self, config_file="config.ini"):
        """Initialize the printer data collector"""
        self.config = self._load_config(config_file)
        self.db_path = os.path.join(self.config["agent"]["data_dir"], "printers.db")
        self.lock = Lock()
        self._setup_data_directory()
        self._setup_database()
        
        # Set up server integration if enabled
        self.server = None
        if self.config["server"]["enabled"] and SERVER_INTEGRATION_AVAILABLE:
            self.server = ServerIntegration(
                server_url=self.config["server"]["url"],
                agent_id=self.config["agent"]["id"],
                agent_name=self.config["agent"]["name"]
            )
            
    def _load_config(self, config_file):
        """Load configuration from file or create default"""
        config = DEFAULT_CONFIG.copy()
        
        if os.path.exists(config_file):
            try:
                parser = configparser.ConfigParser()
                parser.read(config_file)
                
                for section in parser.sections():
                    if section in config:
                        for key, value in parser.items(section):
                            if key in config[section]:
                                # Convert types appropriately
                                if isinstance(config[section][key], int):
                                    config[section][key] = parser.getint(section, key)
                                elif isinstance(config[section][key], float):
                                    config[section][key] = parser.getfloat(section, key)
                                elif isinstance(config[section][key], bool):
                                    config[section][key] = parser.getboolean(section, key)
                                elif isinstance(config[section][key], list) and key == "subnets":
                                    # Parse the subnets list from string representation
                                    try:
                                        config[section][key] = json.loads(parser.get(section, key))
                                    except:
                                        # Fallback to default if parsing fails
                                        logger.error(f"Error parsing subnet list, using default")
                                else:
                                    config[section][key] = parser.get(section, key)
                
                logger.info(f"Loaded configuration from {config_file}")
            except Exception as e:
                logger.error(f"Error loading config: {e}")
                logger.info("Using default configuration")
                self._save_config(config, config_file)
        else:
            logger.info(f"Config file {config_file} not found, creating with defaults")
            self._save_config(config, config_file)
            
        return config
    
    def _save_config(self, config, config_file):
        """Save configuration to file"""
        try:
            parser = configparser.ConfigParser()
            
            for section, values in config.items():
                parser[section] = {}
                for key, value in values.items():
                    if isinstance(value, list):
                        parser[section][key] = json.dumps(value)
                    else:
                        parser[section][key] = str(value)
            
            os.makedirs(os.path.dirname(os.path.abspath(config_file)), exist_ok=True)
            with open(config_file, 'w') as f:
                parser.write(f)
                
            logger.info(f"Saved configuration to {config_file}")
        except Exception as e:
            logger.error(f"Error saving config: {e}")
    
    def _setup_data_directory(self):
        """Create data directory if it doesn't exist"""
        os.makedirs(self.config["agent"]["data_dir"], exist_ok=True)
        logger.info(f"Data directory: {self.config['agent']['data_dir']}")
        
    def _setup_database(self):
        """Set up the SQLite database for local storage"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Create printers table
                cursor.execute('''
                CREATE TABLE IF NOT EXISTS printers (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ip_address TEXT NOT NULL,
                    serial_number TEXT,
                    model TEXT,
                    name TEXT,
                    last_seen TIMESTAMP,
                    server_id INTEGER DEFAULT NULL,
                    UNIQUE(ip_address)
                )
                ''')
                
                # Create metrics table
                cursor.execute('''
                CREATE TABLE IF NOT EXISTS metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    printer_id INTEGER,
                    timestamp TIMESTAMP NOT NULL,
                    page_count INTEGER,
                    toner_levels TEXT,
                    status TEXT,
                    error_state TEXT,
                    raw_data TEXT,
                    sent_to_server BOOLEAN DEFAULT 0,
                    FOREIGN KEY (printer_id) REFERENCES printers(id)
                )
                ''')
                
                conn.commit()
                logger.info("Database setup complete")
        except Exception as e:
            logger.error(f"Database setup error: {e}")
            sys.exit(1)
    
    def discover_printers(self):
        """Discover printers on the network using SNMP"""
        logger.info("Starting printer discovery")
        discovered = []
        
        for subnet in self.config["network"]["subnets"]:
            try:
                network = ipaddress.ip_network(subnet)
                logger.info(f"Scanning subnet: {subnet}")
                
                # For small networks, scan all IPs
                # For larger networks, you might want to implement a more efficient scanning method
                total_ips = len(list(network.hosts()))
                logger.info(f"Scanning {total_ips} IP addresses in network {subnet}")
                
                for ip in network.hosts():
                    ip_str = str(ip)
                    if self._check_snmp_device(ip_str):
                        printer_info = self._get_printer_info(ip_str)
                        if printer_info:
                            printer_id = self._save_printer(printer_info)
                            discovered.append(printer_info)
                            
                            # Send to server if enabled
                            if self.server:
                                self.server.send_printer_data(printer_info)
            except Exception as e:
                logger.error(f"Error scanning subnet {subnet}: {e}")
        
        logger.info(f"Discovery complete. Found {len(discovered)} printers")
        return discovered
    
    def _check_snmp_device(self, ip):
        """Check if an IP address responds to SNMP and is a printer"""
        try:
            # System description OID
            oid = '1.3.6.1.2.1.1.1.0'
            community = self.config["network"]["snmp_community"]
            timeout = self.config["network"]["snmp_timeout"]
            
            error_indication, error_status, error_index, var_binds = next(
                getCmd(SnmpEngine(),
                       CommunityData(community),
                       UdpTransportTarget((ip, 161), timeout=timeout, retries=1),
                       ContextData(),
                       ObjectType(ObjectIdentity(oid)))
            )
            
            if error_indication or error_status:
                return False
            
            # Check if it's a printer (simple check - can be improved)
            for var_bind in var_binds:
                value = str(var_bind[1])
                if any(keyword in value.lower() for keyword in ['print', 'hp', 'xerox', 'canon', 'epson', 'brother', 'ricoh', 'lexmark']):
                    logger.info(f"Found printer at {ip}: {value}")
                    return True
            
            return False
        except Exception as e:
            logger.debug(f"SNMP check failed for {ip}: {e}")
            return False
    
    def _get_printer_info(self, ip):
        """Get detailed information about a printer using SNMP"""
        try:
            # OIDs for common printer information
            oids = {
                'model': '1.3.6.1.2.1.25.3.2.1.3.1',
                'name': '1.3.6.1.2.1.1.5.0',
                'serial': '1.3.6.1.2.1.43.5.1.1.17.1'  # This OID might vary by manufacturer
            }
            
            info = {'ip_address': ip}
            community = self.config["network"]["snmp_community"]
            
            for key, oid in oids.items():
                error_indication, error_status, error_index, var_binds = next(
                    getCmd(SnmpEngine(),
                           CommunityData(community),
                           UdpTransportTarget((ip, 161)),
                           ContextData(),
                           ObjectType(ObjectIdentity(oid)))
                )
                
                if not error_indication and not error_status:
                    for var_bind in var_binds:
                        info[key] = str(var_bind[1])
            
            # If we couldn't get the serial number, mark it as unknown
            if 'serial' not in info:
                info['serial'] = 'UNKNOWN'
                
            logger.info(f"Retrieved printer info: {info}")
            return info
        except Exception as e:
            logger.error(f"Error getting printer info for {ip}: {e}")
            return None
    
    def _save_printer(self, printer_info):
        """Save or update printer information in the database"""
        try:
            with self.lock, sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Check if printer already exists
                cursor.execute(
                    "SELECT id, server_id FROM printers WHERE ip_address = ?",
                    (printer_info['ip_address'],)
                )
                result = cursor.fetchone()
                
                if result:
                    # Update existing printer
                    printer_id = result[0]
                    server_id = result[1]
                    cursor.execute(
                        """UPDATE printers 
                           SET model = ?, name = ?, 
                               serial_number = ?, last_seen = ? 
                           WHERE id = ?""",
                        (
                            printer_info.get('model', ''),
                            printer_info.get('name', ''),
                            printer_info.get('serial', 'UNKNOWN'),
                            datetime.now().isoformat(),
                            printer_id
                        )
                    )
                    logger.info(f"Updated printer: {printer_info['ip_address']}")
                else:
                    # Insert new printer
                    cursor.execute(
                        """INSERT INTO printers 
                           (ip_address, model, name, serial_number, last_seen) 
                           VALUES (?, ?, ?, ?, ?)""",
                        (
                            printer_info['ip_address'],
                            printer_info.get('model', ''),
                            printer_info.get('name', ''),
                            printer_info.get('serial', 'UNKNOWN'),
                            datetime.now().isoformat()
                        )
                    )
                    printer_id = cursor.lastrowid
                    server_id = None
                    logger.info(f"Added new printer: {printer_info['ip_address']}")
                
                conn.commit()
                return printer_id
        except Exception as e:
            logger.error(f"Error saving printer: {e}")
            return None
    
    def collect_metrics(self):
        """Collect metrics from all known printers"""
        logger.info("Starting metrics collection")
        
        try:
            with self.lock, sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                
                # Get all printers
                cursor.execute("SELECT * FROM printers")
                printers = cursor.fetchall()
                
                for printer in printers:
                    try:
                        metrics = self._get_printer_metrics(dict(printer))
                        if metrics:
                            self._save_metrics(printer['id'], metrics)
                            
                            # Send to server if enabled
                            if self.server and printer['server_id'] is not None:
                                self.server.send_metrics(printer['server_id'], metrics)
                    except Exception as e:
                        logger.error(f"Error collecting metrics for printer {printer['ip_address']}: {e}")
                
                logger.info(f"Completed metrics collection for {len(printers)} printers")
        except Exception as e:
            logger.error(f"Error in metrics collection: {e}")
    
    def _get_printer_metrics(self, printer):
        """Get current metrics from a printer using SNMP"""
        try:
            ip = printer['ip_address']
            
            # OIDs for common printer metrics
            oids = {
                'page_count': '1.3.6.1.2.1.43.10.2.1.4.1.1',  # Total pages printed
                'status': '1.3.6.1.2.1.25.3.5.1.1.1',  # Printer status
                'error_state': '1.3.6.1.2.1.25.3.5.1.2.1',  # Error state
                # Toner levels - these OIDs might vary by manufacturer
                'black_toner': '1.3.6.1.2.1.43.11.1.1.9.1.1',
                'cyan_toner': '1.3.6.1.2.1.43.11.1.1.9.1.2',
                'magenta_toner': '1.3.6.1.2.1.43.11.1.1.9.1.3',
                'yellow_toner': '1.3.6.1.2.1.43.11.1.1.9.1.4'
            }
            
            metrics = {
                'timestamp': datetime.now().isoformat(),
                'toner_levels': {}
            }
            
            community = self.config["network"]["snmp_community"]
            
            for key, oid in oids.items():
                error_indication, error_status, error_index, var_binds = next(
                    getCmd(SnmpEngine(),
                           CommunityData(community),
                           UdpTransportTarget((ip, 161)),
                           ContextData(),
                           ObjectType(ObjectIdentity(oid)))
                )
                
                if not error_indication and not error_status:
                    for var_bind in var_binds:
                        value = str(var_bind[1])
                        # Handle special cases for toner
                        if key.endswith('_toner'):
                            color = key.replace('_toner', '')
                            metrics['toner_levels'][color] = value
                        else:
                            metrics[key] = value
            
            # Convert toner_levels dict to JSON string
            metrics['toner_levels'] = json.dumps(metrics.get('toner_levels', {}))
            metrics['raw_data'] = json.dumps(metrics)  # Store all data for future reference
            
            logger.info(f"Collected metrics for {ip}")
            return metrics
        except Exception as e:
            logger.error(f"Error getting metrics for {printer['ip_address']}: {e}")
            return None
    
    def _save_metrics(self, printer_id, metrics):
        """Save metrics to the database"""
        try:
            with self.lock, sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute(
                    """INSERT INTO metrics 
                       (printer_id, timestamp, page_count, toner_levels, status, error_state, raw_data) 
                       VALUES (?, ?, ?, ?, ?, ?, ?)""",
                    (
                        printer_id,
                        metrics.get('timestamp'),
                        metrics.get('page_count'),
                        metrics.get('toner_levels'),
                        metrics.get('status'),
                        metrics.get('error_state'),
                        metrics.get('raw_data')
                    )
                )
                
                conn.commit()
                logger.debug(f"Saved metrics for printer ID {printer_id}")
                return True
        except Exception as e:
            logger.error(f"Error saving metrics: {e}")
            return False

    def set_printer_serial(self, ip_address, serial_number):
        """Manually set a printer's serial number"""
        try:
            with self.lock, sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute(
                    "UPDATE printers SET serial_number = ? WHERE ip_address = ?",
                    (serial_number, ip_address)
                )
                
                if cursor.rowcount > 0:
                    conn.commit()
                    logger.info(f"Set serial number {serial_number} for printer {ip_address}")
                    return True
                else:
                    logger.error(f"Printer with IP {ip_address} not found")
                    return False
        except Exception as e:
            logger.error(f"Error setting serial number: {e}")
            return False
    
    def register_with_server(self):
        """Register with the central server"""
        if not self.server:
            logger.warning("Server integration not available or disabled")
            return False
        
        success = self.server.register()
        if success:
            logger.info("Successfully registered with server")
            return True
        else:
            logger.error("Failed to register with server")
            return False
    
    def sync_unregistered_printers(self):
        """Send any unregistered printers to the server"""
        if not self.server:
            logger.warning("Server integration not available or disabled")
            return False
        
        try:
            with self.lock, sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                
                # Get all printers without server_id
                cursor.execute("SELECT * FROM printers WHERE server_id IS NULL")
                printers = cursor.fetchall()
                
                success_count = 0
                for printer in printers:
                    printer_data = {
                        'ip_address': printer['ip_address'],
                        'serial_number': printer['serial_number'],
                        'model': printer['model'],
                        'name': printer['name']
                    }
                    
                    if self.server.send_printer_data(printer_data):
                        # Update with the server response when we have integration to get server IDs
                        # For now, just mark as sent by setting a placeholder server ID
                        cursor.execute(
                            "UPDATE printers SET server_id = ? WHERE id = ?",
                            (1, printer['id'])  # Placeholder ID, will need proper integration
                        )
                        conn.commit()
                        success_count += 1
                
                logger.info(f"Synced {success_count} of {len(printers)} printers with server")
                return success_count > 0
        except Exception as e:
            logger.error(f"Error syncing printers with server: {e}")
            return False
    
    def run(self):
        """Run the data collector with scheduled tasks"""
        logger.info("Starting Printer Data Collector")
        
        # Try to register with server if enabled
        if self.config["server"]["enabled"] and SERVER_INTEGRATION_AVAILABLE:
            self.register_with_server()
        
        # Setup schedules
        schedule.every(self.config['agent']['polling_interval']).seconds.do(self.collect_metrics)
        schedule.every(self.config['agent']['discovery_interval']).seconds.do(self.discover_printers)
        
        if self.config["server"]["enabled"] and SERVER_INTEGRATION_AVAILABLE:
            schedule.every(60).seconds.do(self.sync_unregistered_printers)
        
        # Do an initial discovery
        self.discover_printers()
        
        # Main loop
        while True:
            try:
                schedule.run_pending()
                time.sleep(1)
            except KeyboardInterrupt:
                logger.info("Shutting down")
                break
            except Exception as e:
                logger.error(f"Error in main loop: {e}")
                time.sleep(5)  # Wait a bit before retrying

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Printer SNMP Data Collector")
    parser.add_argument("--config", default="config.ini", help="Path to config file")
    parser.add_argument("--discover", action="store_true", help="Run printer discovery")
    parser.add_argument("--collect", action="store_true", help="Collect metrics once")
    parser.add_argument("--set-serial", nargs=2, metavar=("IP", "SERIAL"), help="Set printer serial number")
    parser.add_argument("--register", action="store_true", help="Register agent with server")
    
    args = parser.parse_args()
    
    collector = PrinterCollector(config_file=args.config)
    
    if args.discover:
        collector.discover_printers()
    elif args.collect:
        collector.collect_metrics()
    elif args.set_serial:
        collector.set_printer_serial(args.set_serial[0], args.set_serial[1])
    elif args.register:
        collector.register_with_server()
    else:
        collector.run()  # Run as service

if __name__ == "__main__":
    main()