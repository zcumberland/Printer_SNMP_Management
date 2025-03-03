import configparser
import os
import time
import uuid
import json
import logging
import ipaddress
import sqlite3
import threading
from pysnmp.hlapi import *
from datetime import datetime
from agent_integration import ServerIntegration

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("agent.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Default configuration
DEFAULT_CONFIG = {
    'agent': {
        'id': '',
        'name': 'PrinterMonitorAgent',
        'polling_interval': '300',
        'discovery_interval': '86400',
        'data_dir': './data'
    },
    'server': {
        'enabled': 'true',
        'url': 'http://localhost:3000/api'
    },
    'network': {
        'subnets': '["192.168.1.0/24"]',
        'snmp_community': 'public',
        'snmp_timeout': '2'
    }
}

class PrinterMonitorAgent:
    def __init__(self, config_file='config.ini'):
        self.config_file = config_file
        self.config = configparser.ConfigParser()
        self.load_config()
        
        self.setup_agent_id()
        
        # Set up data directory
        os.makedirs(self.config['agent']['data_dir'], exist_ok=True)
        
        # Set up database
        self.db_path = os.path.join(self.config['agent']['data_dir'], 'printers.db')
        self.init_database()
        
        # Set up server integration if enabled
        self.server = None
        if self.config['server'].getboolean('enabled'):
            self.server = ServerIntegration(
                self.config['server']['url'],
                self.config['agent']['id'],
                self.config['agent']['name']
            )
            
        # Initialize state
        self.printers = {}
        self.discovery_running = False
        self.collection_running = False
        self.stop_threads = False

    def load_config(self):
        """Load configuration from file or create default"""
        # Set default configuration
        for section, options in DEFAULT_CONFIG.items():
            if not self.config.has_section(section):
                self.config.add_section(section)
            for option, value in options.items():
                self.config.set(section, option, value)
        
        # Load from file if exists
        if os.path.exists(self.config_file):
            self.config.read(self.config_file)
        else:
            # Save default configuration
            with open(self.config_file, 'w') as f:
                self.config.write(f)
    
    def setup_agent_id(self):
        """Set up agent ID from file or create new one"""
        agent_id_file = os.path.join(os.path.dirname(self.config_file), 'agent_id.txt')
        
        # Check if we already have an agent ID in config
        if not self.config['agent']['id']:
            # Check if we have an agent ID file
            if os.path.exists(agent_id_file):
                with open(agent_id_file, 'r') as f:
                    agent_id = f.read().strip()
                    if agent_id:
                        self.config['agent']['id'] = agent_id
                        logger.info(f"Loaded agent ID from file: {agent_id}")
            
            # If still no agent ID, generate one
            if not self.config['agent']['id']:
                agent_id = str(uuid.uuid4())
                self.config['agent']['id'] = agent_id
                logger.info(f"Generated new agent ID: {agent_id}")
                
                # Save agent ID to file
                with open(agent_id_file, 'w') as f:
                    f.write(agent_id)
                
                # Save updated config
                with open(self.config_file, 'w') as f:
                    self.config.write(f)
    
    def init_database(self):
        """Initialize SQLite database for storing printer data"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Create printers table
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS printers (
            id INTEGER PRIMARY KEY,
            ip_address TEXT UNIQUE,
            serial_number TEXT,
            model TEXT,
            name TEXT,
            status TEXT,
            last_seen TIMESTAMP
        )
        ''')
        
        # Create metrics table
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS metrics (
            id INTEGER PRIMARY KEY,
            printer_id INTEGER,
            timestamp TIMESTAMP,
            page_count INTEGER,
            toner_levels TEXT,
            status TEXT,
            error_state TEXT,
            raw_data TEXT,
            FOREIGN KEY (printer_id) REFERENCES printers (id)
        )
        ''')
        
        conn.commit()
        conn.close()
    
    def discover_printers(self):
        """Discover printers on the network"""
        if self.discovery_running:
            logger.info("Discovery already running, skipping...")
            return
        
        self.discovery_running = True
        logger.info("Starting printer discovery...")
        
        try:
            # Get network configuration
            subnets = json.loads(self.config['network']['subnets'])
            community = self.config['network']['snmp_community']
            timeout = int(self.config['network']['snmp_timeout'])
            
            new_printers = []
            
            # Scan each subnet
            for subnet in subnets:
                logger.info(f"Scanning subnet {subnet}")
                network = ipaddress.ip_network(subnet)
                
                # Skip scan for very large networks
                if network.num_addresses > 1024:
                    logger.warning(f"Subnet {subnet} is too large (> 1024 addresses), skipping")
                    continue
                
                # Scan each IP in the subnet
                for ip in network.hosts():
                    if self.stop_threads:
                        logger.info("Discovery thread stopped")
                        self.discovery_running = False
                        return
                    
                    ip_str = str(ip)
                    
                    # Check if this is a printer via SNMP
                    if self._check_snmp_device(ip_str, community, timeout):
                        logger.info(f"Found printer at {ip_str}")
                        new_printers.append(ip_str)
                        
                        # Add to database
                        self._add_printer_to_db(ip_str)
            
            logger.info(f"Discovery completed. Found {len(new_printers)} printers.")
            
            # Send discovery results to server
            if self.server and new_printers:
                self.server.send_printer_data(self._get_printers_from_db())
        except Exception as e:
            logger.error(f"Error in printer discovery: {e}")
        finally:
            self.discovery_running = False
    
    def _check_snmp_device(self, ip, community, timeout):
        """Check if device at IP is a printer via SNMP"""
        try:
            # Query system description
            errorIndication, errorStatus, errorIndex, varBinds = next(
                getCmd(
                    SnmpEngine(),
                    CommunityData(community),
                    UdpTransportTarget((ip, 161), timeout=timeout),
                    ContextData(),
                    ObjectType(ObjectIdentity('1.3.6.1.2.1.1.1.0'))  # sysDescr
                )
            )
            
            if errorIndication or errorStatus:
                return False
            
            # Check if this is a printer
            for varBind in varBinds:
                value = str(varBind[1])
                # Look for printer-related keywords in the description
                if any(keyword in value.lower() for keyword in ['printer', 'print', 'laserjet', 'officejet', 'imagerunner', 'workcentre', 'lexmark', 'kyocera']):
                    return True
            
            return False
        except Exception as e:
            logger.debug(f"SNMP error for {ip}: {e}")
            return False
    
    def _add_printer_to_db(self, ip):
        """Add a printer to the database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute(
                "INSERT OR IGNORE INTO printers (ip_address, last_seen) VALUES (?, ?)",
                (ip, datetime.now().isoformat())
            )
            conn.commit()
        except Exception as e:
            logger.error(f"Error adding printer to database: {e}")
        finally:
            conn.close()
    
    def _get_printers_from_db(self):
        """Get all printers from the database"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        try:
            cursor.execute("SELECT * FROM printers")
            printers = [dict(row) for row in cursor.fetchall()]
            return printers
        except Exception as e:
            logger.error(f"Error getting printers from database: {e}")
            return []
        finally:
            conn.close()
    
    def collect_metrics(self):
        """Collect metrics from discovered printers"""
        if self.collection_running:
            logger.info("Collection already running, skipping...")
            return
        
        self.collection_running = True
        logger.info("Starting metrics collection...")
        
        try:
            # Get network configuration
            community = self.config['network']['snmp_community']
            timeout = int(self.config['network']['snmp_timeout'])
            
            # Get printers from database
            printers = self._get_printers_from_db()
            
            metrics_data = []
            
            for printer in printers:
                if self.stop_threads:
                    logger.info("Collection thread stopped")
                    self.collection_running = False
                    return
                
                ip = printer['ip_address']
                printer_id = printer['id']
                
                logger.info(f"Collecting metrics from printer at {ip}")
                
                try:
                    # Collect printer information
                    info = self._get_printer_info(ip, community, timeout)
                    
                    # Update printer details in database
                    self._update_printer_info(printer_id, ip, info)
                    
                    # Collect metrics
                    metrics = self._get_printer_metrics(ip, community, timeout)
                    
                    if metrics:
                        # Add to metrics to database
                        metric_id = self._add_metrics_to_db(printer_id, metrics)
                        metrics['id'] = metric_id
                        metrics['printer_id'] = printer_id
                        metrics_data.append(metrics)
                except Exception as e:
                    logger.error(f"Error collecting metrics from {ip}: {e}")
            
            logger.info(f"Metrics collection completed for {len(metrics_data)} printers.")
            
            # Send metrics to server
            if self.server and metrics_data:
                self.server.send_metrics(metrics_data)
        except Exception as e:
            logger.error(f"Error in metrics collection: {e}")
        finally:
            self.collection_running = False
    
    def _get_printer_info(self, ip, community, timeout):
        """Get printer information via SNMP"""
        info = {}
        
        try:
            # OIDs to query for printer information
            oids = {
                'serial': '1.3.6.1.2.1.43.5.1.1.17.1',  # prtGeneralSerialNumber
                'model': '1.3.6.1.2.1.25.3.2.1.3.1',    # hrDeviceDescr
                'name': '1.3.6.1.2.1.1.5.0',            # sysName
                'status': '1.3.6.1.2.1.43.17.6.1.5.1.1'  # prtAlertDescription
            }
            
            for key, oid in oids.items():
                errorIndication, errorStatus, errorIndex, varBinds = next(
                    getCmd(
                        SnmpEngine(),
                        CommunityData(community),
                        UdpTransportTarget((ip, 161), timeout=timeout),
                        ContextData(),
                        ObjectType(ObjectIdentity(oid))
                    )
                )
                
                if not (errorIndication or errorStatus):
                    for varBind in varBinds:
                        value = str(varBind[1])
                        if value != '':
                            info[key] = value
        except Exception as e:
            logger.error(f"Error getting printer info for {ip}: {e}")
        
        return info
    
    def _update_printer_info(self, printer_id, ip, info):
        """Update printer information in the database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            # Update fields that we have values for
            updates = []
            params = []
            
            for field, value in info.items():
                if value:
                    updates.append(f"{field} = ?")
                    params.append(value)
            
            if updates:
                # Add last_seen timestamp
                updates.append("last_seen = ?")
                params.append(datetime.now().isoformat())
                
                # Add printer_id
                params.append(printer_id)
                
                query = f"UPDATE printers SET {', '.join(updates)} WHERE id = ?"
                cursor.execute(query, params)
                conn.commit()
        except Exception as e:
            logger.error(f"Error updating printer info: {e}")
        finally:
            conn.close()
    
    def _get_printer_metrics(self, ip, community, timeout):
        """Get printer metrics via SNMP"""
        metrics = {
            'timestamp': datetime.now().isoformat(),
            'raw_data': {}
        }
        
        try:
            # Get page count
            errorIndication, errorStatus, errorIndex, varBinds = next(
                getCmd(
                    SnmpEngine(),
                    CommunityData(community),
                    UdpTransportTarget((ip, 161), timeout=timeout),
                    ContextData(),
                    ObjectType(ObjectIdentity('1.3.6.1.2.1.43.10.2.1.4.1.1'))  # prtMarkerLifeCount
                )
            )
            
            if not (errorIndication or errorStatus):
                for varBind in varBinds:
                    metrics['page_count'] = int(varBind[1])
                    metrics['raw_data']['page_count'] = int(varBind[1])
            
            # Get toner levels
            toner_levels = {}
            
            # Walk through the toner entries
            g = nextCmd(
                SnmpEngine(),
                CommunityData(community),
                UdpTransportTarget((ip, 161), timeout=timeout),
                ContextData(),
                ObjectType(ObjectIdentity('1.3.6.1.2.1.43.11.1.1.9')),  # prtMarkerSuppliesLevel
                lexicographicMode=False
            )
            
            # Get toner names
            toner_names = {}
            g_names = nextCmd(
                SnmpEngine(),
                CommunityData(community),
                UdpTransportTarget((ip, 161), timeout=timeout),
                ContextData(),
                ObjectType(ObjectIdentity('1.3.6.1.2.1.43.11.1.1.6')),  # prtMarkerSuppliesDescription
                lexicographicMode=False
            )
            
            for errorIndication, errorStatus, errorIndex, varBinds in g_names:
                if not (errorIndication or errorStatus):
                    for varBind in varBinds:
                        oid = str(varBind[0])
                        value = str(varBind[1])
                        # Extract the index from the OID
                        index = oid.split('.')[-1]
                        toner_names[index] = value
            
            for errorIndication, errorStatus, errorIndex, varBinds in g:
                if not (errorIndication or errorStatus):
                    for varBind in varBinds:
                        oid = str(varBind[0])
                        value = int(varBind[1])
                        # Extract the index from the OID
                        index = oid.split('.')[-1]
                        
                        # Get the name if available
                        name = toner_names.get(index, f"Supply {index}")
                        
                        # Only include if it looks like a toner/ink level
                        if any(keyword in name.lower() for keyword in ['toner', 'ink', 'black', 'cyan', 'magenta', 'yellow']):
                            toner_levels[name] = value
            
            if toner_levels:
                metrics['toner_levels'] = json.dumps(toner_levels)
                metrics['raw_data']['toner_levels'] = toner_levels
            
            # Get status
            errorIndication, errorStatus, errorIndex, varBinds = next(
                getCmd(
                    SnmpEngine(),
                    CommunityData(community),
                    UdpTransportTarget((ip, 161), timeout=timeout),
                    ContextData(),
                    ObjectType(ObjectIdentity('1.3.6.1.2.1.25.3.5.1.1.1'))  # hrPrinterStatus
                )
            )
            
            if not (errorIndication or errorStatus):
                for varBind in varBinds:
                    status_code = int(varBind[1])
                    status_map = {
                        1: 'other',
                        2: 'unknown',
                        3: 'idle',
                        4: 'printing',
                        5: 'warmup',
                        6: 'error'
                    }
                    metrics['status'] = status_map.get(status_code, 'unknown')
                    metrics['raw_data']['status'] = status_map.get(status_code, 'unknown')
            
            # Get error state if in error
            if metrics.get('status') == 'error':
                errorIndication, errorStatus, errorIndex, varBinds = next(
                    getCmd(
                        SnmpEngine(),
                        CommunityData(community),
                        UdpTransportTarget((ip, 161), timeout=timeout),
                        ContextData(),
                        ObjectType(ObjectIdentity('1.3.6.1.2.1.43.18.1.1.8.1.1'))  # prtAlertDescription
                    )
                )
                
                if not (errorIndication or errorStatus):
                    for varBind in varBinds:
                        metrics['error_state'] = str(varBind[1])
                        metrics['raw_data']['error_state'] = str(varBind[1])
            
            metrics['raw_data'] = json.dumps(metrics['raw_data'])
            return metrics
        except Exception as e:
            logger.error(f"Error getting printer metrics for {ip}: {e}")
            return None
    
    def _add_metrics_to_db(self, printer_id, metrics):
        """Add metrics to the database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute(
                """
                INSERT INTO metrics 
                (printer_id, timestamp, page_count, toner_levels, status, error_state, raw_data) 
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    printer_id,
                    metrics['timestamp'],
                    metrics.get('page_count', None),
                    metrics.get('toner_levels', None),
                    metrics.get('status', None),
                    metrics.get('error_state', None),
                    metrics.get('raw_data', None)
                )
            )
            conn.commit()
            return cursor.lastrowid
        except Exception as e:
            logger.error(f"Error adding metrics to database: {e}")
            return None
        finally:
            conn.close()
    
    def update_config_from_server(self):
        """Get updated configuration from server"""
        if not self.server:
            return
        
        try:
            server_config = self.server.get_config()
            if server_config:
                # Update network configuration
                if 'subnets' in server_config:
                    self.config['network']['subnets'] = json.dumps(server_config['subnets'])
                
                if 'snmp_community' in server_config:
                    self.config['network']['snmp_community'] = server_config['snmp_community']
                
                if 'snmp_timeout' in server_config:
                    self.config['network']['snmp_timeout'] = str(server_config['snmp_timeout'])
                
                # Update polling intervals
                if 'polling_interval' in server_config:
                    self.config['agent']['polling_interval'] = str(server_config['polling_interval'])
                
                if 'discovery_interval' in server_config:
                    self.config['agent']['discovery_interval'] = str(server_config['discovery_interval'])
                
                # Save updated config
                with open(self.config_file, 'w') as f:
                    self.config.write(f)
                
                logger.info("Updated configuration from server")
        except Exception as e:
            logger.error(f"Error updating configuration from server: {e}")
    
    def run(self):
        """Run the agent"""
        logger.info(f"Starting Printer Monitor Agent (ID: {self.config['agent']['id']})")
        
        # Connect to server if enabled
        if self.server:
            self.server.register()
            self.update_config_from_server()
        
        # Variables to track when to run discovery and collection
        last_discovery = 0
        last_collection = 0
        last_config_update = 0
        
        discovery_interval = int(self.config['agent']['discovery_interval'])
        polling_interval = int(self.config['agent']['polling_interval'])
        
        # Run initial discovery
        threading.Thread(target=self.discover_printers).start()
        last_discovery = time.time()
        
        try:
            while not self.stop_threads:
                current_time = time.time()
                
                # Check if it's time to run discovery
                if current_time - last_discovery >= discovery_interval:
                    threading.Thread(target=self.discover_printers).start()
                    last_discovery = current_time
                
                # Check if it's time to run collection
                if current_time - last_collection >= polling_interval:
                    threading.Thread(target=self.collect_metrics).start()
                    last_collection = current_time
                
                # Check if it's time to update config (every hour)
                if self.server and current_time - last_config_update >= 3600:
                    self.update_config_from_server()
                    
                    # Update intervals from config
                    discovery_interval = int(self.config['agent']['discovery_interval'])
                    polling_interval = int(self.config['agent']['polling_interval'])
                    
                    last_config_update = current_time
                
                # Sleep for a bit
                time.sleep(10)
        except KeyboardInterrupt:
            logger.info("Stopping agent due to keyboard interrupt")
        finally:
            logger.info("Agent stopped")
    
    def stop(self):
        """Stop the agent"""
        self.stop_threads = True
        logger.info("Stopping agent...")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Printer Monitor Agent')
    parser.add_argument('--discover', action='store_true', help='Run printer discovery')
    parser.add_argument('--collect', action='store_true', help='Run metrics collection')
    parser.add_argument('--config', default='config.ini', help='Path to config file')
    
    args = parser.parse_args()
    
    agent = PrinterMonitorAgent(args.config)
    
    if args.discover:
        agent.discover_printers()
    elif args.collect:
        agent.collect_metrics()
    else:
        try:
            agent.run()
        except KeyboardInterrupt:
            agent.stop()