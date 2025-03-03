const { Pool } = require("pg");
const bcrypt = require("bcrypt");

// Create a new pool using environment variables
const pool = new Pool({
  user: process.env.DB_USER || "postgres",
  host: process.env.DB_HOST || "localhost",
  database: process.env.DB_NAME || "printer_monitor",
  password: process.env.DB_PASSWORD || "postgres",
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
        first_name VARCHAR(50),
        last_name VARCHAR(50),
        role VARCHAR(20) NOT NULL DEFAULT 'user',
        is_active BOOLEAN DEFAULT TRUE,
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

      CREATE TABLE IF NOT EXISTS organizations (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) UNIQUE NOT NULL,
        contact_name VARCHAR(100),
        contact_email VARCHAR(100),
        phone VARCHAR(50),
        address VARCHAR(255),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
      
      CREATE TABLE IF NOT EXISTS printers (
        id SERIAL PRIMARY KEY,
        agent_id INTEGER REFERENCES agents(id) ON DELETE CASCADE,
        organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
        ip_address VARCHAR(50) NOT NULL,
        serial_number VARCHAR(100),
        model VARCHAR(100),
        name VARCHAR(100),
        status VARCHAR(50) DEFAULT 'unknown',
        location VARCHAR(100),
        department VARCHAR(100),
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
      
      CREATE TABLE IF NOT EXISTS agent_configs (
        id SERIAL PRIMARY KEY,
        agent_id INTEGER REFERENCES agents(id) ON DELETE CASCADE,
        organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
        subnet_ranges JSONB NOT NULL DEFAULT '[]',
        snmp_community VARCHAR(50) DEFAULT 'public',
        snmp_timeout INTEGER DEFAULT 2,
        polling_interval INTEGER DEFAULT 300,
        discovery_interval INTEGER DEFAULT 86400,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(agent_id)
      );

      CREATE TABLE IF NOT EXISTS organization_users (
        organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        role VARCHAR(20) NOT NULL DEFAULT 'member',
        PRIMARY KEY (organization_id, user_id)
      );

      CREATE TABLE IF NOT EXISTS organization_agents (
        organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
        agent_id INTEGER REFERENCES agents(id) ON DELETE CASCADE,
        PRIMARY KEY (organization_id, agent_id)
      );
    `);

    console.log("Database tables initialized");

    // Create an admin user if none exists
    const adminExists = await client.query(
      "SELECT COUNT(*) FROM users WHERE role = 'admin'"
    );

    if (parseInt(adminExists.rows[0].count) === 0) {
      const username = process.env.DEFAULT_ADMIN_USERNAME || "admin";
      const email = process.env.DEFAULT_ADMIN_EMAIL || "admin@example.com";
      const defaultPassword = process.env.DEFAULT_ADMIN_PASSWORD || "admin123";
      const hashedPassword = await bcrypt.hash(defaultPassword, 10);

      await client.query(
        `INSERT INTO users (username, password, email, role) 
         VALUES ($1, $2, $3, $4)`,
        [username, hashedPassword, email, "admin"]
      );

      console.log("Created default admin user");
    }
  } catch (err) {
    console.error("Database initialization error:", err);
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  pool,
  initializeDatabase,
};