const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const dotenv = require("dotenv");
const path = require("path");
const { initializeDatabase } = require("./models/db");

// Load environment variables
dotenv.config();

// Create Express app
const app = express();

// Apply middleware
app.use(helmet()); // Security headers
app.use(cors());
app.use(express.json({ limit: "10mb" }));
app.use(morgan("combined")); // Request logging

// Import routes
const authRoutes = require("./routes/auth");
const agentRoutes = require("./routes/agents");
const printerRoutes = require("./routes/printers");
const dataRoutes = require("./routes/data");
const userRoutes = require("./routes/users");
const dashboardRoutes = require("./routes/dashboard");

// Define API routes
app.use("/api/auth", authRoutes);
app.use("/api/agents", agentRoutes);
app.use("/api/printers", printerRoutes);
app.use("/api/data", dataRoutes);
app.use("/api/users", userRoutes);
app.use("/api/dashboard", dashboardRoutes);

// Serve static files in production
if (process.env.NODE_ENV === "production") {
  // Serve static files from the React frontend app
  app.use(express.static(path.join(__dirname, "../frontend/build")));

  // Handle React routing, return all requests to React app
  app.get("*", (req, res) => {
    res.sendFile(path.join(__dirname, "../frontend/build", "index.html"));
  });
}

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    error: "Server error",
    message:
      process.env.NODE_ENV === "development"
        ? err.message
        : "An unexpected error occurred",
  });
});

// Start the server
const PORT = process.env.PORT || 3000;

// Initialize database and then start server
initializeDatabase()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error("Failed to start server:", err);
    process.exit(1);
  });
