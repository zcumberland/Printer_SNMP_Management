const express = require("express");
const { pool } = require("../models/db");
const { authenticateToken } = require("../middleware/auth");

const router = express.Router();

// Get all printers
router.get("/", authenticateToken, async (req, res) => {
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
router.get("/:id", authenticateToken, async (req, res) => {
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

    // Get toner level history
    const tonerHistory = await pool.query(
      `
      SELECT timestamp, toner_levels
      FROM metrics
      WHERE printer_id = $1 AND toner_levels IS NOT NULL
      ORDER BY timestamp DESC
      LIMIT 10
    `,
      [printerId]
    );

    res.json({
      printer: printerResult.rows[0],
      metrics: latestMetrics.rows[0] || null,
      pageCountHistory: pageCountHistory.rows,
      tonerHistory: tonerHistory.rows,
    });
  } catch (err) {
    console.error("Error fetching printer details:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Update printer info
router.put("/:id", authenticateToken, async (req, res) => {
  try {
    const printerId = req.params.id;
    const { name, serial_number } = req.body;

    if (!name && !serial_number) {
      return res.status(400).json({ error: "No update fields provided" });
    }

    let query = "UPDATE printers SET ";
    const values = [];
    let paramCount = 1;

    if (name) {
      query += `name = ${paramCount++}`;
      values.push(name);
    }

    if (serial_number) {
      if (values.length > 0) query += ", ";
      query += `serial_number = ${paramCount++}`;
      values.push(serial_number);
    }

    query += ` WHERE id = ${paramCount} RETURNING *`;
    values.push(printerId);

    const result = await pool.query(query, values);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Printer not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error("Error updating printer:", err);
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router;
