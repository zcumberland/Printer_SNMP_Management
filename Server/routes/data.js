const express = require("express");
const { pool } = require("../models/db");
const { authenticateAgent } = require("../middleware/auth");

const router = express.Router();

// Data ingestion endpoint
router.post("/", authenticateAgent, async (req, res) => {
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
          data.timestamp || new Date().toISOString(),
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

      console.log(`Metrics received for printer ${printerId}`);
      res.json({ success: true });
    } else if (type === "printer_discovery" || type === "printer_update") {
      // Process printer update or discovery
      const { ip_address, serial_number, model, name } = data;

      if (!ip_address) {
        return res
          .status(400)
          .json({ error: "Printer IP address is required" });
      }

      // Find printer
      const printerResult = await pool.query(
        "SELECT id FROM printers WHERE ip_address = $1 AND agent_id = $2",
        [ip_address, agentId]
      );

      let printerId;

      if (printerResult.rows.length > 0) {
        // Update existing printer
        printerId = printerResult.rows[0].id;

        await pool.query(
          `UPDATE printers 
           SET serial_number = COALESCE($1, serial_number),
               model = COALESCE($2, model),
               name = COALESCE($3, name),
               last_seen = NOW()
           WHERE id = $4`,
          [serial_number, model, name, printerId]
        );

        console.log(`Updated printer ${ip_address}`);
      } else {
        // Create new printer
        const result = await pool.query(
          `INSERT INTO printers 
           (agent_id, ip_address, serial_number, model, name, last_seen) 
           VALUES ($1, $2, $3, $4, $5, NOW())
           RETURNING id`,
          [agentId, ip_address, serial_number, model, name]
        );

        printerId = result.rows[0].id;
        console.log(`Discovered new printer ${ip_address}`);
      }

      res.json({ success: true, printer_id: printerId });
    } else {
      return res.status(400).json({ error: "Unknown data type" });
    }
  } catch (err) {
    console.error("Data ingestion error:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Get configuration for agent
router.get("/config", authenticateAgent, async (req, res) => {
  try {
    const agent = req.agent;

    // Return configuration data for the agent
    res.json({
      polling_interval: 300, // seconds
      discovery_interval: 86400, // 24 hours
      snmp_community: "public",
      snmp_timeout: 2,
    });
  } catch (err) {
    console.error("Error fetching agent config:", err);
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router;
