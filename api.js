// Central Server for Printer Monitoring System
// Express.js API with PostgreSQL Database

const express = require("express");
const bodyParser = require("body-parser");
const cors = require("cors");
const helmet = require("helmet");
const { Pool } = require("pg");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const dotenv = require("dotenv");
const morgan = require("morgan");
const { v4: uuidv4 } = require("uuid");
const path = require("path");
const fs = require("fs");

// Load environment variables
dotenv.config();

// Create Express app
const app = express();

// Set up middleware
app.use(helmet()); // Security headers
app.use(cors());
app.use(bodyParser.json({ limit: "10mb" }));
app.use(morgan("combined")); // Request logging

// Database connection
const pool = new Pool({
  user: process.env.DB_USER || "postgres",
  host: process.env.DB_HOST || "localhost",
  database: process.env.DB_NAME || "printer_monitor",
  password: process.env.DB_PASSWORD || "postgres",
  port: process.env.DB_PORT || 5432,
});

// Helper to generate API key for agents
function generateApiKey() {
  return uuidv4();
}

// Initialize database tables
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

      CREATE TABLE IF NOT EXISTS organizations (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) UNIQUE NOT NULL,
        contact_name VARCHAR(100),
        contact_email VARCHAR(100),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
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

    // Create an admin user if none exists
    const adminExists = await client.query(
      "SELECT COUNT(*) FROM users WHERE role = 'admin'"
    );

    if (parseInt(adminExists.rows[0].count) === 0) {
      const defaultPassword = process.env.DEFAULT_ADMIN_PASSWORD || "admin123";
      const hashedPassword = await bcrypt.hash(defaultPassword, 10);

      await client.query(
        `INSERT INTO users (username, password, email, role) 
         VALUES ($1, $2, $3, $4)`,
        ["admin", hashedPassword, "admin@example.com", "admin"]
      );

      console.log("Created default admin user");
    }
  } catch (err) {
    console.error("Database initialization error:", err);
    process.exit(1);
  } finally {
    client.release();
  }
}

// API Routes
// User Authentication
app.post("/api/auth/login", async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ error: "Username and password required" });
    }

    const result = await pool.query("SELECT * FROM users WHERE username = $1", [
      username,
    ]);

    if (result.rows.length === 0) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const user = result.rows[0];
    const validPassword = await bcrypt.compare(password, user.password);

    if (!validPassword) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    // Update last login
    await pool.query("UPDATE users SET last_login = NOW() WHERE id = $1", [
      user.id,
    ]);

    // Create JWT token
    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role },
      process.env.JWT_SECRET || "your_jwt_secret",
      { expiresIn: "24h" }
    );

    res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
      },
    });
  } catch (err) {
    console.error("Login error:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Agent Registration
app.post("/api/agents/register", async (req, res) => {
  try {
    const { agent_id, name, hostname, ip_address, os_info, version } = req.body;

    if (!agent_id || !name) {
      return res.status(400).json({ error: "Agent ID and name required" });
    }

    // Check if agent already exists
    const existingAgent = await pool.query(
      "SELECT * FROM agents WHERE agent_id = $1",
      [agent_id]
    );

    let apiKey;

    if (existingAgent.rows.length > 0) {
      // Agent exists, return existing API key
      apiKey = existingAgent.rows[0].api_key;

      // Update agent info
      await pool.query(
        `UPDATE agents 
         SET name = $1, hostname = $2, ip_address = $3, 
             os_info = $4, version = $5, last_seen = NOW()
         WHERE agent_id = $6`,
        [name, hostname, ip_address, os_info, version, agent_id]
      );
    } else {
      // Create new agent
      apiKey = generateApiKey();

      await pool.query(
        `INSERT INTO agents 
         (agent_id, name, hostname, ip_address, os_info, version, api_key) 
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [agent_id, name, hostname, ip_address, os_info, version, apiKey]
      );
    }

    res.json({ success: true, token: apiKey });
  } catch (err) {
    console.error("Agent registration error:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Data ingestion endpoint
app.post("/api/data", authenticateAgent, async (req, res) => {
  try {
    const { type, data } = req.body;
    const agentId = req.agent.id;

    if (!type || !data) {
      return res.status(400).json({ error: "Invalid data format" });
    }

    if (type === "metrics") {
      // Process metrics data
      const printerId = req.body.printer_id;

      // Check if printer exists
      const printerResult = await pool.query(
        "SELECT id FROM printers WHERE id = $1 AND agent_id = $2",
        [printerId, agentId]
      );

      if (printerResult.rows.length === 0) {
        return res.status(404).json({ error: "Printer not found" });
      }

      // Insert metrics
      await pool.query(
        `INSERT INTO metrics 
         (printer_id, timestamp, page_count, toner_levels, status, error_state, raw_data) 
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          printerId,
          data.timestamp,
          data.page_count,
          data.toner_levels ? JSON.parse(data.toner_levels) : null,
          data.status,
          data.error_state,
          data.raw_data ? JSON.parse(data.raw_data) : null,
        ]
      );

      // Update printer status
      await pool.query(
        "UPDATE printers SET status = $1, last_seen = NOW() WHERE id = $2",
        [data.status || "unknown", printerId]
      );
    } else if (type === "printer_update") {
      // Process printer update
      const { ip_address, serial_number, model, name } = data;

      // Find printer
      const printerResult = await pool.query(
        "SELECT id FROM printers WHERE ip_address = $1 AND agent_id = $2",
        [ip_address, agentId]
      );

      if (printerResult.rows.length > 0) {
        // Update existing printer
        const printerId = printerResult.rows[0].id;

        await pool.query(
          `UPDATE printers 
           SET serial_number = COALESCE($1, serial_number),
               model = COALESCE($2, model),
               name = COALESCE($3, name),
               last_seen = NOW()
           WHERE id = $4`,
          [serial_number, model, name, printerId]
        );
      } else {
        // Create new printer
        await pool.query(
          `INSERT INTO printers 
           (agent_id, ip_address, serial_number, model, name, last_seen) 
           VALUES ($1, $2, $3, $4, $5, NOW())`,
          [agentId, ip_address, serial_number, model, name]
        );
      }
    } else {
      return res.status(400).json({ error: "Unknown data type" });
    }

    res.json({ success: true });
  } catch (err) {
    console.error("Data ingestion error:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Get all printers
app.get("/api/printers", authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT p.id, p.ip_address, p.serial_number, p.model, p.name, p.status, 
             p.last_seen, a.name as agent_name, a.agent_id,
             (SELECT MAX(m.page_count) FROM metrics m WHERE m.printer_id = p.id) as page_count
      FROM printers p
      JOIN agents a ON p.agent_id = a.id
      ORDER BY p.last_seen DESC
    `);

    res.json(result.rows);
  } catch (err) {
    console.error("Error fetching printers:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Get printer details with metrics
app.get("/api/printers/:id", authenticateToken, async (req, res) => {
  try {
    const printerId = req.params.id;

    // Get printer info
    const printerResult = await pool.query(
      `
      SELECT p.id, p.ip_address, p.serial_number, p.model, p.name, p.status, 
             p.last_seen, a.name as agent_name, a.agent_id
      FROM printers p
      JOIN agents a ON p.agent_id = a.id
      WHERE p.id = $1
    `,
      [printerId]
    );

    if (printerResult.rows.length === 0) {
      return res.status(404).json({ error: "Printer not found" });
    }

    // Get latest metrics
    const latestMetrics = await pool.query(
      `
      SELECT * FROM metrics
      WHERE printer_id = $1
      ORDER BY timestamp DESC
      LIMIT 1
    `,
      [printerId]
    );

    // Get historical page count data
    const pageCountHistory = await pool.query(
      `
      SELECT timestamp::date as date, MAX(page_count) as page_count
      FROM metrics
      WHERE printer_id = $1 AND page_count IS NOT NULL
      GROUP BY timestamp::date
      ORDER BY date
      LIMIT 30
    `,
      [printerId]
    );

    res.json({
      printer: printerResult.rows[0],
      metrics: latestMetrics.rows[0] || null,
      pageCountHistory: pageCountHistory.rows,
    });
  } catch (err) {
    console.error("Error fetching printer details:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Get all agents
app.get(
  "/api/agents",
  authenticateToken,
  authorize(["admin"]),
  async (req, res) => {
    try {
      const result = await pool.query(`
      SELECT id, agent_id, name, hostname, ip_address, 
             os_info, version, status, last_seen
      FROM agents
      ORDER BY last_seen DESC
    `);

      res.json(result.rows);
    } catch (err) {
      console.error("Error fetching agents:", err);
      res.status(500).json({ error: "Server error" });
    }
  }
);

// User management (admin only)
app.get(
  "/api/users",
  authenticateToken,
  authorize(["admin"]),
  async (req, res) => {
    try {
      const result = await pool.query(`
      SELECT id, username, email, role, created_at, last_login
      FROM users
      ORDER BY username
    `);

      res.json(result.rows);
    } catch (err) {
      console.error("Error fetching users:", err);
      res.status(500).json({ error: "Server error" });
    }
  }
);

app.post(
  "/api/users",
  authenticateToken,
  authorize(["admin"]),
  async (req, res) => {
    try {
      const { username, email, password, role } = req.body;

      if (!username || !email || !password) {
        return res
          .status(400)
          .json({ error: "Username, email and password required" });
      }

      // Check if user exists
      const existingUser = await pool.query(
        "SELECT id FROM users WHERE username = $1 OR email = $2",
        [username, email]
      );

      if (existingUser.rows.length > 0) {
        return res
          .status(409)
          .json({ error: "Username or email already exists" });
      }

      // Hash password
      const hashedPassword = await bcrypt.hash(password, 10);

      // Create user
      const result = await pool.query(
        `INSERT INTO users (username, email, password, role) 
       VALUES ($1, $2, $3, $4)
       RETURNING id, username, email, role`,
        [username, email, hashedPassword, role || "user"]
      );

      res.status(201).json(result.rows[0]);
    } catch (err) {
      console.error("Error creating user:", err);
      res.status(500).json({ error: "Server error" });
    }
  }
);

// Dashboard stats
app.get("/api/dashboard/stats", authenticateToken, async (req, res) => {
  try {
    const client = await pool.connect();

    try {
      // Get printer count
      const printerCount = await client.query("SELECT COUNT(*) FROM printers");

      // Get agents count
      const agentCount = await client.query("SELECT COUNT(*) FROM agents");

      // Get printers with low toner
      const lowTonerQuery = `
        SELECT COUNT(DISTINCT p.id)
        FROM printers p
        JOIN metrics m ON p.id = m.printer_id
        WHERE m.timestamp > NOW() - INTERVAL '24 hours'
        AND (
          m.toner_levels->>'black' < '10' OR
          m.toner_levels->>'cyan' < '10' OR
          m.toner_levels->>'magenta' < '10' OR
          m.toner_levels->>'yellow' < '10'
        )
      `;
      const lowToner = await client.query(lowTonerQuery);

      // Get printer status distribution
      const statusDistribution = await client.query(`
        SELECT status, COUNT(*) as count
        FROM printers
        GROUP BY status
      `);

      // Get printers with errors
      const errorsQuery = `
        SELECT COUNT(DISTINCT p.id)
        FROM printers p
        JOIN metrics m ON p.id = m.printer_id
        WHERE m.timestamp > NOW() - INTERVAL '24 hours'
        AND m.error_state IS NOT NULL
        AND m.error_state != ''
      `;
      const errors = await client.query(errorsQuery);

      res.json({
        printerCount: parseInt(printerCount.rows[0].count),
        agentCount: parseInt(agentCount.rows[0].count),
        lowTonerCount: parseInt(lowToner.rows[0].count),
        errorCount: parseInt(errors.rows[0].count),
        statusDistribution: statusDistribution.rows,
      });
    } finally {
      client.release();
    }
  } catch (err) {
    console.error("Error fetching dashboard stats:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Serve frontend static files
if (process.env.NODE_ENV === "production") {
  // Serve static files from the React frontend app
  const frontendPath = path.join(__dirname, "../frontend/build");
  if (fs.existsSync(frontendPath)) {
    app.use(express.static(frontendPath));

    // Handle React routing, return all requests to React app
    app.get("*", (req, res) => {
      res.sendFile(path.join(frontendPath, "index.html"));
    });
  }
}

// Start server
const PORT = process.env.PORT || 3000;

// Initialize database then start server
initializeDatabase()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error("Failed to start server:", err);
  });

// Authentication middleware
function authenticateToken(req, res, next) {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    return res.status(401).json({ error: "Authentication required" });
  }

  jwt.verify(
    token,
    process.env.JWT_SECRET || "your_jwt_secret",
    (err, user) => {
      if (err) {
        return res.status(403).json({ error: "Invalid or expired token" });
      }
      req.user = user;
      next();
    }
  );
}

// Role-based authorization middleware
function authorize(roles = []) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: "Authentication required" });
    }

    if (roles.length && !roles.includes(req.user.role)) {
      return res.status(403).json({ error: "Insufficient permissions" });
    }

    next();
  };
}

// Agent authentication middleware
async function authenticateAgent(req, res, next) {
  const authHeader = req.headers["authorization"];
  const apiKey = authHeader && authHeader.split(" ")[1];

  if (!apiKey) {
    return res.status(401).json({ error: "Agent authentication required" });
  }

  try {
    const result = await pool.query("SELECT * FROM agents WHERE api_key = $1", [
      apiKey,
    ]);

    if (result.rows.length === 0) {
      return res.status(403).json({ error: "Invalid agent API key" });
    }

    // Update last seen timestamp
    await pool.query("UPDATE agents SET last_seen = NOW() WHERE id = $1", [
      result.rows[0].id,
    ]);

    req.agent = result.rows[0];
    next();
  } catch (err) {
    console.error("Agent authentication error:", err);
    return res.status(500).json({ error: "Authentication error" });
  }
}
