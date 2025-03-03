#!/usr/bin/env python3
"""
Database Setup Script for Printer SNMP Management

This script initializes the SQLite database for the agent.
"""

import os
import sys
import sqlite3
import logging
import argparse

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("db_setup.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("DBSetup")

def setup_database(db_path):
    """Set up the SQLite database"""
    try:
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(os.path.abspath(db_path)), exist_ok=True)
        
        with sqlite3.connect(db_path) as conn:
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
            logger.info(f"Database setup complete at {db_path}")
            return True
    except Exception as e:
        logger.error(f"Database setup error: {e}")
        return False

def drop_tables(db_path, confirm=False):
    """Drop all tables in the database"""
    if not confirm:
        confirm_input = input("Are you sure you want to drop all tables? This cannot be undone. (y/N): ")
        if confirm_input.lower() != 'y':
            logger.info("Operation cancelled.")
            return False
    
    try:
        with sqlite3.connect(db_path) as conn:
            cursor = conn.cursor()
            
            # Drop metrics table first (due to foreign key constraint)
            cursor.execute("DROP TABLE IF EXISTS metrics")
            
            # Drop printers table
            cursor.execute("DROP TABLE IF EXISTS printers")
            
            conn.commit()
            logger.info("All tables dropped successfully.")
            return True
    except Exception as e:
        logger.error(f"Error dropping tables: {e}")
        return False

def database_info(db_path):
    """Print information about the database"""
    try:
        if not os.path.exists(db_path):
            logger.error(f"Database file does not exist: {db_path}")
            return False
        
        with sqlite3.connect(db_path) as conn:
            cursor = conn.cursor()
            
            # Get table list
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = cursor.fetchall()
            
            print(f"\nDatabase: {db_path}")
            print(f"Tables found: {len(tables)}")
            
            for table in tables:
                table_name = table[0]
                cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
                count = cursor.fetchone()[0]
                
                # Get column info
                cursor.execute(f"PRAGMA table_info({table_name})")
                columns = cursor.fetchall()
                
                print(f"\n- Table: {table_name}")
                print(f"  Rows: {count}")
                print(f"  Columns:")
                for col in columns:
                    col_id, col_name, col_type, not_null, default, pk = col
                    print(f"    - {col_name} ({col_type}){' PRIMARY KEY' if pk else ''}{' NOT NULL' if not_null else ''}")
            
            return True
    except Exception as e:
        logger.error(f"Error getting database info: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Database setup for Printer SNMP Management")
    parser.add_argument("--path", default="./data/printers.db", help="Path to database file")
    parser.add_argument("--info", action="store_true", help="Display database information")
    parser.add_argument("--drop", action="store_true", help="Drop existing tables")
    parser.add_argument("--force", action="store_true", help="Force operations without confirmation")
    
    args = parser.parse_args()
    
    if args.info:
        database_info(args.path)
    elif args.drop:
        if drop_tables(args.path, args.force):
            # Recreate tables after dropping if successful
            setup_database(args.path)
    else:
        setup_database(args.path)

if __name__ == "__main__":
    main()