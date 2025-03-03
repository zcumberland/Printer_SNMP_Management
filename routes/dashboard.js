const express = require("express");
const bcrypt = require("bcrypt");
const { pool } = require("../models/db");
const { authenticateToken, authorize } = require("../middleware/auth");

const router = express.Router();

// Get all users (admin only)
router.get("/", authenticateToken, authorize(["admin"]), async (req, res) => {
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
});

// Create new user (admin only)
router.post("/", authenticateToken, authorize(["admin"]), async (req, res) => {
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
});

// Get user by ID (admin or self)
router.get("/:id", authenticateToken, async (req, res) => {
  try {
    const userId = req.params.id;

    // Only admins can view other users
    if (req.user.id.toString() !== userId && req.user.role !== "admin") {
      return res.status(403).json({ error: "Unauthorized to view this user" });
    }

    const result = await pool.query(
      `SELECT id, username, email, role, created_at, last_login
       FROM users WHERE id = $1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error("Error fetching user:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Update user (admin or self)
router.put("/:id", authenticateToken, async (req, res) => {
  try {
    const userId = req.params.id;
    const { email, password, role } = req.body;

    // Only admins can update role or other users
    if (req.user.id.toString() !== userId && req.user.role !== "admin") {
      return res
        .status(403)
        .json({ error: "Unauthorized to update this user" });
    }

    // Non-admins cannot change their role
    if (role && req.user.role !== "admin") {
      return res.status(403).json({ error: "Unauthorized to change role" });
    }

    // Start building the query
    let query = "UPDATE users SET ";
    const values = [];
    let paramCount = 1;

    if (email) {
      query += `email = $${paramCount++}`;
      values.push(email);
    }

    if (password) {
      if (values.length > 0) query += ", ";

      // Hash the new password
      const hashedPassword = await bcrypt.hash(password, 10);
      query += `password = $${paramCount++}`;
      values.push(hashedPassword);
    }

    if (role && req.user.role === "admin") {
      if (values.length > 0) query += ", ";
      query += `role = $${paramCount++}`;
      values.push(role);
    }

    if (values.length === 0) {
      return res.status(400).json({ error: "No update fields provided" });
    }

    query += ` WHERE id = $${paramCount} RETURNING id, username, email, role`;
    values.push(userId);

    const result = await pool.query(query, values);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error("Error updating user:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Delete user (admin only)
router.delete(
  "/:id",
  authenticateToken,
  authorize(["admin"]),
  async (req, res) => {
    try {
      const userId = req.params.id;

      // Prevent deleting the last admin
      if (req.user.id.toString() === userId) {
        const adminCount = await pool.query(
          "SELECT COUNT(*) FROM users WHERE role = 'admin'"
        );

        if (parseInt(adminCount.rows[0].count) <= 1) {
          return res
            .status(400)
            .json({ error: "Cannot delete the last admin user" });
        }
      }

      const result = await pool.query(
        "DELETE FROM users WHERE id = $1 RETURNING id",
        [userId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: "User not found" });
      }

      res.json({ message: "User deleted successfully" });
    } catch (err) {
      console.error("Error deleting user:", err);
      res.status(500).json({ error: "Server error" });
    }
  }
);

module.exports = router;
