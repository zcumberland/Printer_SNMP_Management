const jwt = require("jsonwebtoken");
const { pool } = require("../models/db");

// User authentication middleware
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

module.exports = {
  authenticateToken,
  authorize,
  authenticateAgent,
};
