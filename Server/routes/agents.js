const express = require("express");
const { v4: uuidv4 } = require("uuid");
const { pool } = require("../models/db");
const {
  authenticateToken,
  authorize,
  authenticateAgent,
} = require("../middleware/auth");

const router = express.Router();

// Generate API key for agents
function generateApiKey() {
  return uuidv4();
}

// Get all agents (admin only)
router.get("/", authenticateToken, authorize(["admin"]), async (req, res) => {
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
});

// Register an agent
router.post("/register", async (req, res) => {
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
             os_info = $4, version = $5, last_seen = NOW(), status = 'active'
         WHERE agent_id = $6`,
        [name, hostname, ip_address, os_info, version, agent_id]
      );

      console.log(`Agent ${name} (${agent_id}) reconnected`);
    } else {
      // Create new agent
      apiKey = generateApiKey();

      await pool.query(
        `INSERT INTO agents 
         (agent_id, name, hostname, ip_address, os_info, version, api_key) 
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [agent_id, name, hostname, ip_address, os_info, version, apiKey]
      );

      console.log(`New agent ${name} (${agent_id}) registered`);
    }

    res.json({ success: true, token: apiKey });
  } catch (err) {
    console.error("Agent registration error:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Get agent status (authenticated)
router.get("/status", authenticateAgent, async (req, res) => {
  try {
    // Agent is already authenticated via middleware
    const agent = req.agent;

    // Get printer count for this agent
    const printerCount = await pool.query(
      "SELECT COUNT(*) FROM printers WHERE agent_id = $1",
      [agent.id]
    );

    res.json({
      agent_id: agent.agent_id,
      name: agent.name,
      status: agent.status,
      last_seen: agent.last_seen,
      printer_count: parseInt(printerCount.rows[0].count),
    });
  } catch (err) {
    console.error("Error fetching agent status:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Get agent by ID (admin only)
router.get(
  "/:id",
  authenticateToken,
  authorize(["admin"]),
  async (req, res) => {
    try {
      const agentId = req.params.id;

      const result = await pool.query("SELECT * FROM agents WHERE id = $1", [
        agentId,
      ]);

      if (result.rows.length === 0) {
        return res.status(404).json({ error: "Agent not found" });
      }

      const agent = result.rows[0];

      // Get printer count
      const printerCount = await pool.query(
        "SELECT COUNT(*) FROM printers WHERE agent_id = $1",
        [agent.id]
      );

      // Get organization info if any
      const orgResult = await pool.query(
        `
      SELECT o.id, o.name FROM organizations o
      JOIN organization_agents oa ON o.id = oa.organization_id
      WHERE oa.agent_id = $1
    `,
        [agent.id]
      );

      const organization = orgResult.rows.length > 0 ? orgResult.rows[0] : null;

      res.json({
        ...agent,
        printer_count: parseInt(printerCount.rows[0].count),
        organization,
      });
    } catch (err) {
      console.error("Error fetching agent:", err);
      res.status(500).json({ error: "Server error" });
    }
  }
);

// Update agent (admin only)
router.put(
  "/:id",
  authenticateToken,
  authorize(["admin"]),
  async (req, res) => {
    try {
      const agentId = req.params.id;
      const { name, status } = req.body;

      if (!name) {
        return res.status(400).json({ error: "Name is required" });
      }

      const result = await pool.query(
        "UPDATE agents SET name = $1, status = $2 WHERE id = $3 RETURNING *",
        [name, status || "active", agentId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: "Agent not found" });
      }

      res.json(result.rows[0]);
    } catch (err) {
      console.error("Error updating agent:", err);
      res.status(500).json({ error: "Server error" });
    }
  }
);

module.exports = router;
