const express = require("express");
const { pool } = require("../models/db");
const { authenticateToken } = require("../middleware/auth");

const router = express.Router();

// Get dashboard stats
router.get("/stats", authenticateToken, async (req, res) => {
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

      // Get recent activity
      const recentActivityQuery = `
        SELECT 
          p.name as printer_name, 
          p.ip_address,
          m.error_state,
          m.status,
          m.timestamp,
          CASE
            WHEN m.error_state IS NOT NULL AND m.error_state != '' THEN 'error'
            WHEN m.toner_levels->>'black' < '10' OR
                 m.toner_levels->>'cyan' < '10' OR
                 m.toner_levels->>'magenta' < '10' OR
                 m.toner_levels->>'yellow' < '10' THEN 'warning'
            ELSE 'info'
          END as activity_type
        FROM metrics m
        JOIN printers p ON m.printer_id = p.id
        WHERE m.timestamp > NOW() - INTERVAL '24 hours'
        ORDER BY m.timestamp DESC
        LIMIT 10
      `;
      const recentActivity = await client.query(recentActivityQuery);

      res.json({
        printerCount: parseInt(printerCount.rows[0].count),
        agentCount: parseInt(agentCount.rows[0].count),
        lowTonerCount: parseInt(lowToner.rows[0].count),
        errorCount: parseInt(errors.rows[0].count),
        statusDistribution: statusDistribution.rows,
        recentActivity: recentActivity.rows,
      });
    } finally {
      client.release();
    }
  } catch (err) {
    console.error("Error fetching dashboard stats:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Get printer total by day
router.get("/printer-totals", authenticateToken, async (req, res) => {
  try {
    // Get printer count by day for the last 30 days
    const result = await pool.query(`
      SELECT 
        date_trunc('day', created_at)::date as date,
        COUNT(*) as count
      FROM printers
      WHERE created_at > NOW() - INTERVAL '30 days'
      GROUP BY date_trunc('day', created_at)
      ORDER BY date_trunc('day', created_at)
    `);

    res.json(result.rows);
  } catch (err) {
    console.error("Error fetching printer totals:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Get page count by day
router.get("/page-counts", authenticateToken, async (req, res) => {
  try {
    // Get total page count increase per day for the last 30 days
    const result = await pool.query(`
      WITH daily_max AS (
        SELECT 
          date_trunc('day', timestamp)::date as date,
          printer_id,
          MAX(page_count) as max_count
        FROM metrics
        WHERE 
          timestamp > NOW() - INTERVAL '30 days'
          AND page_count IS NOT NULL
        GROUP BY date_trunc('day', timestamp)::date, printer_id
      )
      SELECT 
        date,
        SUM(max_count) as total_pages
      FROM daily_max
      GROUP BY date
      ORDER BY date
    `);

    res.json(result.rows);
  } catch (err) {
    console.error("Error fetching page counts:", err);
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router;
