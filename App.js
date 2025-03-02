// src/App.js
import React, { useState, useEffect } from "react";
import {
  BrowserRouter as Router,
  Routes,
  Route,
  Navigate,
  Link,
} from "react-router-dom";
import axios from "axios";
import {
  AppBar,
  Toolbar,
  Typography,
  Container,
  Paper,
  Box,
  TextField,
  Button,
  CircularProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  IconButton,
  Drawer,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  Divider,
  Card,
  CardContent,
  Grid,
  Chip,
  Menu,
  MenuItem,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  FormControl,
  InputLabel,
  Select,
  Alert,
  Snackbar,
} from "@mui/material";
import {
  Dashboard as DashboardIcon,
  Print as PrinterIcon,
  Computer as AgentIcon,
  Person as UserIcon,
  Business as OrgIcon,
  Settings as SettingsIcon,
  Menu as MenuIcon,
  Logout as LogoutIcon,
  Refresh as RefreshIcon,
  Search as SearchIcon,
  Visibility as ViewIcon,
  Edit as EditIcon,
  DeleteOutline as DeleteIcon,
  Warning as WarningIcon,
  CheckCircle as CheckIcon,
  Error as ErrorIcon,
} from "@mui/icons-material";

// API base URL
const API_URL = process.env.REACT_APP_API_URL || "http://localhost:3000/api";

// Set up axios with auth token
const setupAxiosInterceptors = (token) => {
  axios.defaults.baseURL = API_URL;

  if (token) {
    axios.defaults.headers.common["Authorization"] = `Bearer ${token}`;
  } else {
    delete axios.defaults.headers.common["Authorization"];
  }

  // Handle 401 responses
  axios.interceptors.response.use(
    (response) => response,
    (error) => {
      if (error.response && error.response.status === 401) {
        localStorage.removeItem("token");
        localStorage.removeItem("user");
        window.location.href = "/login";
      }
      return Promise.reject(error);
    }
  );
};

// Main App Component
const App = () => {
  const [user, setUser] = useState(null);
  const [drawerOpen, setDrawerOpen] = useState(false);

  useEffect(() => {
    // Check for stored token on app load
    const token = localStorage.getItem("token");
    const storedUser = localStorage.getItem("user");

    if (token && storedUser) {
      setupAxiosInterceptors(token);
      setUser(JSON.parse(storedUser));
    }
  }, []);

  const handleLogin = (userData) => {
    setUser(userData);
  };

  const handleLogout = () => {
    localStorage.removeItem("token");
    localStorage.removeItem("user");
    setUser(null);
    delete axios.defaults.headers.common["Authorization"];
  };

  const toggleDrawer = () => {
    setDrawerOpen(!drawerOpen);
  };

  // If not logged in, show login page
  if (!user) {
    return <Login onLogin={handleLogin} />;
  }

  return (
    <Router>
      <Box sx={{ display: "flex" }}>
        {/* App Bar */}
        <AppBar position="fixed">
          <Toolbar>
            <IconButton
              color="inherit"
              edge="start"
              onClick={toggleDrawer}
              sx={{ mr: 2 }}
            >
              <MenuIcon />
            </IconButton>
            <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
              Printer Monitoring System
            </Typography>
            <Button
              color="inherit"
              onClick={handleLogout}
              startIcon={<LogoutIcon />}
            >
              Logout
            </Button>
          </Toolbar>
        </AppBar>

        {/* Side Drawer */}
        <Drawer
          open={drawerOpen}
          onClose={toggleDrawer}
          sx={{
            width: 240,
            flexShrink: 0,
            "& .MuiDrawer-paper": {
              width: 240,
              boxSizing: "border-box",
            },
          }}
        >
          <Toolbar />
          <Box sx={{ overflow: "auto" }}>
            <List>
              <ListItem button component={Link} to="/" onClick={toggleDrawer}>
                <ListItemIcon>
                  <DashboardIcon />
                </ListItemIcon>
                <ListItemText primary="Dashboard" />
              </ListItem>
              <ListItem
                button
                component={Link}
                to="/printers"
                onClick={toggleDrawer}
              >
                <ListItemIcon>
                  <PrinterIcon />
                </ListItemIcon>
                <ListItemText primary="Printers" />
              </ListItem>
              <ListItem
                button
                component={Link}
                to="/agents"
                onClick={toggleDrawer}
              >
                <ListItemIcon>
                  <AgentIcon />
                </ListItemIcon>
                <ListItemText primary="Agents" />
              </ListItem>
            </List>
            <Divider />
            {user.role === "admin" && (
              <List>
                <ListItem
                  button
                  component={Link}
                  to="/users"
                  onClick={toggleDrawer}
                >
                  <ListItemIcon>
                    <UserIcon />
                  </ListItemIcon>
                  <ListItemText primary="Users" />
                </ListItem>
                <ListItem
                  button
                  component={Link}
                  to="/settings"
                  onClick={toggleDrawer}
                >
                  <ListItemIcon>
                    <SettingsIcon />
                  </ListItemIcon>
                  <ListItemText primary="Settings" />
                </ListItem>
              </List>
            )}
          </Box>
        </Drawer>

        {/* Main Content */}
        <Box component="main" sx={{ flexGrow: 1, p: 3 }}>
          <Toolbar /> {/* Spacer for fixed app bar */}
          <Container maxWidth="xl">
            <Routes>
              <Route path="/" element={<Dashboard />} />
              <Route path="/printers" element={<Printers />} />
              <Route path="/agents" element={<Agents />} />
              {user.role === "admin" && (
                <>
                  <Route path="/users" element={<Users />} />
                  <Route
                    path="/settings"
                    element={
                      <Typography>Settings Page (Coming Soon)</Typography>
                    }
                  />
                </>
              )}
              <Route path="*" element={<Navigate to="/" />} />
            </Routes>
          </Container>
        </Box>
      </Box>
    </Router>
  );
};

export default App;

// Agents Component
const Agents = () => {
  const [agents, setAgents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchAgents();
  }, []);

  const fetchAgents = async () => {
    setLoading(true);
    try {
      const response = await axios.get("/agents");
      setAgents(response.data);
    } catch (err) {
      setError("Failed to load agent data");
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString) => {
    if (!dateString) return "Never";
    const date = new Date(dateString);
    return new Intl.DateTimeFormat("en-US", {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(date);
  };

  if (loading) {
    return (
      <Box
        display="flex"
        justifyContent="center"
        alignItems="center"
        minHeight="60vh"
      >
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error" sx={{ mt: 2 }}>
        {error}
      </Alert>
    );
  }

  return (
    <Box>
      <Box
        display="flex"
        justifyContent="space-between"
        alignItems="center"
        mb={3}
      >
        <Typography variant="h4">Monitoring Agents</Typography>
        <Button
          startIcon={<RefreshIcon />}
          onClick={fetchAgents}
          variant="outlined"
        >
          Refresh
        </Button>
      </Box>

      <Paper>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Agent Name</TableCell>
                <TableCell>Hostname</TableCell>
                <TableCell>IP Address</TableCell>
                <TableCell>Version</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Last Seen</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {agents.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} align="center">
                    No agents found
                  </TableCell>
                </TableRow>
              ) : (
                agents.map((agent) => (
                  <TableRow key={agent.id}>
                    <TableCell>
                      <Typography variant="body2" fontWeight="bold">
                        {agent.name}
                      </Typography>
                      <Typography variant="caption" color="textSecondary">
                        ID: {agent.agent_id.substring(0, 8)}...
                      </Typography>
                    </TableCell>
                    <TableCell>{agent.hostname || "Unknown"}</TableCell>
                    <TableCell>{agent.ip_address || "Unknown"}</TableCell>
                    <TableCell>{agent.version || "Unknown"}</TableCell>
                    <TableCell>
                      <Chip
                        label={agent.status}
                        color={
                          agent.status === "active" ? "success" : "default"
                        }
                        size="small"
                      />
                    </TableCell>
                    <TableCell>{formatDate(agent.last_seen)}</TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>
    </Box>
  );
};

// Users Management Component (Admin only)
const Users = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [newUser, setNewUser] = useState({
    username: "",
    email: "",
    password: "",
    role: "user",
  });
  const [notification, setNotification] = useState({
    open: false,
    message: "",
    severity: "success",
  });

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const response = await axios.get("/users");
      setUsers(response.data);
    } catch (err) {
      setError("Failed to load user data");
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setNewUser({
      ...newUser,
      [name]: value,
    });
  };

  const handleCreateUser = async () => {
    try {
      await axios.post("/users", newUser);
      setDialogOpen(false);
      fetchUsers();
      setNotification({
        open: true,
        message: "User created successfully",
        severity: "success",
      });
      setNewUser({
        username: "",
        email: "",
        password: "",
        role: "user",
      });
    } catch (err) {
      setNotification({
        open: true,
        message: err.response?.data?.error || "Failed to create user",
        severity: "error",
      });
    }
  };

  const closeNotification = () => {
    setNotification({
      ...notification,
      open: false,
    });
  };

  const formatDate = (dateString) => {
    if (!dateString) return "Never";
    const date = new Date(dateString);
    return new Intl.DateTimeFormat("en-US", {
      dateStyle: "medium",
    }).format(date);
  };

  if (loading) {
    return (
      <Box
        display="flex"
        justifyContent="center"
        alignItems="center"
        minHeight="60vh"
      >
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error" sx={{ mt: 2 }}>
        {error}
      </Alert>
    );
  }

  return (
    <Box>
      <Box
        display="flex"
        justifyContent="space-between"
        alignItems="center"
        mb={3}
      >
        <Typography variant="h4">User Management</Typography>
        <Button
          variant="contained"
          color="primary"
          onClick={() => setDialogOpen(true)}
        >
          Add User
        </Button>
      </Box>

      <Paper>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Username</TableCell>
                <TableCell>Email</TableCell>
                <TableCell>Role</TableCell>
                <TableCell>Created</TableCell>
                <TableCell>Last Login</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {users.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} align="center">
                    No users found
                  </TableCell>
                </TableRow>
              ) : (
                users.map((user) => (
                  <TableRow key={user.id}>
                    <TableCell>{user.username}</TableCell>
                    <TableCell>{user.email}</TableCell>
                    <TableCell>
                      <Chip
                        label={user.role}
                        color={user.role === "admin" ? "primary" : "default"}
                        size="small"
                      />
                    </TableCell>
                    <TableCell>{formatDate(user.created_at)}</TableCell>
                    <TableCell>{formatDate(user.last_login)}</TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      {/* Create User Dialog */}
      <Dialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>Create New User</DialogTitle>
        <DialogContent>
          <Box component="form" sx={{ mt: 2 }}>
            <TextField
              fullWidth
              margin="normal"
              label="Username"
              name="username"
              value={newUser.username}
              onChange={handleInputChange}
              required
            />
            <TextField
              fullWidth
              margin="normal"
              label="Email"
              name="email"
              type="email"
              value={newUser.email}
              onChange={handleInputChange}
              required
            />
            <TextField
              fullWidth
              margin="normal"
              label="Password"
              name="password"
              type="password"
              value={newUser.password}
              onChange={handleInputChange}
              required
            />
            <FormControl fullWidth margin="normal">
              <InputLabel>Role</InputLabel>
              <Select
                name="role"
                value={newUser.role}
                onChange={handleInputChange}
                label="Role"
              >
                <MenuItem value="user">User</MenuItem>
                <MenuItem value="admin">Admin</MenuItem>
              </Select>
            </FormControl>
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
          <Button
            onClick={handleCreateUser}
            variant="contained"
            color="primary"
            disabled={!newUser.username || !newUser.email || !newUser.password}
          >
            Create
          </Button>
        </DialogActions>
      </Dialog>

      {/* Notification Snackbar */}
      <Snackbar
        open={notification.open}
        autoHideDuration={6000}
        onClose={closeNotification}
      >
        <Alert
          onClose={closeNotification}
          severity={notification.severity}
          sx={{ width: "100%" }}
        >
          {notification.message}
        </Alert>
      </Snackbar>
    </Box>
  );
};

// Login Component
const Login = ({ onLogin }) => {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const response = await axios.post(`${API_URL}/auth/login`, {
        username,
        password,
      });

      const { token, user } = response.data;
      localStorage.setItem("token", token);
      localStorage.setItem("user", JSON.stringify(user));

      setupAxiosInterceptors(token);
      onLogin(user);
    } catch (err) {
      setError(err.response?.data?.error || "Login failed. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const closeDialog = () => {
    setDialogOpen(false);
    setSelectedPrinter(null);
  };

  if (loading) {
    return (
      <Box
        display="flex"
        justifyContent="center"
        alignItems="center"
        minHeight="60vh"
      >
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error" sx={{ mt: 2 }}>
        {error}
      </Alert>
    );
  }

  return (
    <Box>
      <Box
        display="flex"
        justifyContent="space-between"
        alignItems="center"
        mb={3}
      >
        <Typography variant="h4">Printers</Typography>
        <Button
          startIcon={<RefreshIcon />}
          onClick={fetchPrinters}
          variant="outlined"
        >
          Refresh
        </Button>
      </Box>

      <Paper>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Name/Model</TableCell>
                <TableCell>IP Address</TableCell>
                <TableCell>Serial Number</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Page Count</TableCell>
                <TableCell>Last Seen</TableCell>
                <TableCell>Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {printers.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={7} align="center">
                    No printers found
                  </TableCell>
                </TableRow>
              ) : (
                printers.map((printer) => (
                  <TableRow key={printer.id}>
                    <TableCell>
                      <Typography variant="body2" fontWeight="bold">
                        {printer.name || "Unnamed Printer"}
                      </Typography>
                      <Typography variant="body2" color="textSecondary">
                        {printer.model || "Unknown Model"}
                      </Typography>
                      <Typography variant="caption" color="textSecondary">
                        Agent: {printer.agent_name}
                      </Typography>
                    </TableCell>
                    <TableCell>{printer.ip_address}</TableCell>
                    <TableCell>{printer.serial_number || "Unknown"}</TableCell>
                    <TableCell>{getStatusChip(printer.status)}</TableCell>
                    <TableCell>{printer.page_count || "Unknown"}</TableCell>
                    <TableCell>{formatDate(printer.last_seen)}</TableCell>
                    <TableCell>
                      <IconButton
                        size="small"
                        onClick={() => handleViewPrinter(printer.id)}
                      >
                        <ViewIcon />
                      </IconButton>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      {/* Printer Details Dialog */}
      <Dialog open={dialogOpen} onClose={closeDialog} maxWidth="md" fullWidth>
        {selectedPrinter && (
          <>
            <DialogTitle>
              {selectedPrinter.printer.name || "Printer Details"}
            </DialogTitle>
            <DialogContent>
              <Grid container spacing={3}>
                <Grid item xs={12} md={6}>
                  <Typography variant="h6" gutterBottom>
                    Printer Information
                  </Typography>
                  <TableContainer component={Paper} variant="outlined">
                    <Table size="small">
                      <TableBody>
                        <TableRow>
                          <TableCell>
                            <strong>Model</strong>
                          </TableCell>
                          <TableCell>
                            {selectedPrinter.printer.model || "Unknown"}
                          </TableCell>
                        </TableRow>
                        <TableRow>
                          <TableCell>
                            <strong>IP Address</strong>
                          </TableCell>
                          <TableCell>
                            {selectedPrinter.printer.ip_address}
                          </TableCell>
                        </TableRow>
                        <TableRow>
                          <TableCell>
                            <strong>Serial Number</strong>
                          </TableCell>
                          <TableCell>
                            {selectedPrinter.printer.serial_number || "Unknown"}
                          </TableCell>
                        </TableRow>
                        <TableRow>
                          <TableCell>
                            <strong>Status</strong>
                          </TableCell>
                          <TableCell>
                            {getStatusChip(selectedPrinter.printer.status)}
                          </TableCell>
                        </TableRow>
                        <TableRow>
                          <TableCell>
                            <strong>Agent</strong>
                          </TableCell>
                          <TableCell>
                            {selectedPrinter.printer.agent_name}
                          </TableCell>
                        </TableRow>
                        <TableRow>
                          <TableCell>
                            <strong>Last Seen</strong>
                          </TableCell>
                          <TableCell>
                            {formatDate(selectedPrinter.printer.last_seen)}
                          </TableCell>
                        </TableRow>
                      </TableBody>
                    </Table>
                  </TableContainer>
                </Grid>

                <Grid item xs={12} md={6}>
                  <Typography variant="h6" gutterBottom>
                    Current Metrics
                  </Typography>

                  {selectedPrinter.metrics ? (
                    <TableContainer component={Paper} variant="outlined">
                      <Table size="small">
                        <TableBody>
                          <TableRow>
                            <TableCell>
                              <strong>Page Count</strong>
                            </TableCell>
                            <TableCell>
                              {selectedPrinter.metrics.page_count || "Unknown"}
                            </TableCell>
                          </TableRow>
                          <TableRow>
                            <TableCell>
                              <strong>Status</strong>
                            </TableCell>
                            <TableCell>
                              {selectedPrinter.metrics.status || "Unknown"}
                            </TableCell>
                          </TableRow>
                          <TableRow>
                            <TableCell>
                              <strong>Error State</strong>
                            </TableCell>
                            <TableCell>
                              {selectedPrinter.metrics.error_state ? (
                                <Chip
                                  label={selectedPrinter.metrics.error_state}
                                  color="error"
                                  size="small"
                                />
                              ) : (
                                "None"
                              )}
                            </TableCell>
                          </TableRow>
                          <TableRow>
                            <TableCell>
                              <strong>Last Updated</strong>
                            </TableCell>
                            <TableCell>
                              {formatDate(selectedPrinter.metrics.timestamp)}
                            </TableCell>
                          </TableRow>
                        </TableBody>
                      </Table>
                    </TableContainer>
                  ) : (
                    <Typography color="textSecondary">
                      No metrics data available
                    </Typography>
                  )}
                </Grid>

                {/* Toner Levels */}
                {selectedPrinter.metrics &&
                  selectedPrinter.metrics.toner_levels && (
                    <Grid item xs={12}>
                      <Typography variant="h6" gutterBottom>
                        Toner Levels
                      </Typography>
                      <Grid container spacing={2}>
                        {Object.entries(
                          selectedPrinter.metrics.toner_levels
                        ).map(([color, level]) => {
                          const percentage = parseInt(level, 10);
                          let displayColor;

                          switch (color.toLowerCase()) {
                            case "black":
                              displayColor = "#000000";
                              break;
                            case "cyan":
                              displayColor = "#00bcd4";
                              break;
                            case "magenta":
                              displayColor = "#e91e63";
                              break;
                            case "yellow":
                              displayColor = "#ffeb3b";
                              break;
                            default:
                              displayColor = "#9e9e9e";
                          }

                          return (
                            <Grid item xs={6} sm={3} key={color}>
                              <Typography variant="body2">
                                {color.charAt(0).toUpperCase() + color.slice(1)}
                              </Typography>
                              <Box sx={{ position: "relative", pt: 1 }}>
                                <Box
                                  sx={{
                                    width: "100%",
                                    backgroundColor: "#e0e0e0",
                                    height: 20,
                                    borderRadius: 1,
                                  }}
                                >
                                  <Box
                                    sx={{
                                      width: `${percentage}%`,
                                      backgroundColor: displayColor,
                                      height: 20,
                                      borderRadius: 1,
                                    }}
                                  />
                                </Box>
                                <Box
                                  sx={{
                                    position: "absolute",
                                    top: "50%",
                                    left: "50%",
                                    transform: "translate(-50%, -50%)",
                                    color: percentage > 50 ? "white" : "black",
                                  }}
                                >
                                  {percentage}%
                                </Box>
                              </Box>
                            </Grid>
                          );
                        })}
                      </Grid>
                    </Grid>
                  )}

                {/* Page Count History */}
                {selectedPrinter.pageCountHistory &&
                  selectedPrinter.pageCountHistory.length > 0 && (
                    <Grid item xs={12}>
                      <Typography variant="h6" gutterBottom>
                        Page Count History
                      </Typography>
                      <Typography
                        variant="body2"
                        color="textSecondary"
                        paragraph
                      >
                        This chart shows the maximum page count recorded each
                        day
                      </Typography>
                      <Box height={300}>
                        {/* Placeholder for a chart - would use Recharts in a real implementation */}
                        <Paper
                          variant="outlined"
                          sx={{
                            height: "100%",
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "center",
                          }}
                        >
                          <Typography color="textSecondary">
                            Page count chart would be displayed here
                          </Typography>
                        </Paper>
                      </Box>
                    </Grid>
                  )}
              </Grid>
            </DialogContent>
            <DialogActions>
              <Button onClick={closeDialog}>Close</Button>
            </DialogActions>
          </>
        )}
      </Dialog>
    </Box>
  );

  const formatDate = (dateString) => {
    if (!dateString) return "Never";
    const date = new Date(dateString);
    return new Intl.DateTimeFormat("en-US", {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(date);
  };

  const getStatusChip = (status) => {
    let color = "default";
    let icon = null;

    switch (status?.toLowerCase()) {
      case "ready":
      case "online":
      case "active":
        color = "success";
        icon = <CheckIcon />;
        break;
      case "warning":
      case "low":
        color = "warning";
        icon = <WarningIcon />;
        break;
      case "error":
      case "offline":
        color = "error";
        icon = <ErrorIcon />;
        break;
      default:
        color = "default";
    }

    return (
      <Chip
        label={status || "Unknown"}
        color={color}
        size="small"
        icon={icon}
      />
    );
  };

  return (
    <Container maxWidth="sm">
      <Box my={8}>
        <Paper elevation={3} sx={{ p: 4 }}>
          <Box display="flex" flexDirection="column" alignItems="center">
            <Typography component="h1" variant="h5">
              Printer Monitoring System
            </Typography>

            {error && (
              <Alert severity="error" sx={{ width: "100%", mt: 2 }}>
                {error}
              </Alert>
            )}

            <Box
              component="form"
              onSubmit={handleSubmit}
              sx={{ mt: 3, width: "100%" }}
            >
              <TextField
                variant="outlined"
                margin="normal"
                required
                fullWidth
                id="username"
                label="Username"
                name="username"
                autoComplete="username"
                autoFocus
                value={username}
                onChange={(e) => setUsername(e.target.value)}
              />
              <TextField
                variant="outlined"
                margin="normal"
                required
                fullWidth
                name="password"
                label="Password"
                type="password"
                id="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              <Button
                type="submit"
                fullWidth
                variant="contained"
                color="primary"
                disabled={loading}
                sx={{ mt: 3, mb: 2 }}
              >
                {loading ? <CircularProgress size={24} /> : "Sign In"}
              </Button>
            </Box>
          </Box>
        </Paper>
      </Box>
    </Container>
  );
};

// Dashboard Component
const Dashboard = () => {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchDashboardStats();
  }, []);

  const fetchDashboardStats = async () => {
    setLoading(true);
    try {
      const response = await axios.get("/dashboard/stats");
      setStats(response.data);
    } catch (err) {
      setError("Failed to load dashboard data");
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <Box
        display="flex"
        justifyContent="center"
        alignItems="center"
        minHeight="60vh"
      >
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error" sx={{ mt: 2 }}>
        {error}
      </Alert>
    );
  }

  if (!stats) {
    return null;
  }

  const getStatusColor = (status) => {
    switch (status.toLowerCase()) {
      case "active":
      case "online":
      case "ready":
        return "success";
      case "warning":
      case "low":
        return "warning";
      case "error":
      case "offline":
        return "error";
      default:
        return "default";
    }
  };

  return (
    <Box>
      <Box
        display="flex"
        justifyContent="space-between"
        alignItems="center"
        mb={3}
      >
        <Typography variant="h4">Dashboard</Typography>
        <Button
          startIcon={<RefreshIcon />}
          onClick={fetchDashboardStats}
          variant="outlined"
        >
          Refresh
        </Button>
      </Box>

      <Grid container spacing={3}>
        {/* Summary Cards */}
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom>
                Total Printers
              </Typography>
              <Typography variant="h3">{stats.printerCount}</Typography>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom>
                Active Agents
              </Typography>
              <Typography variant="h3">{stats.agentCount}</Typography>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent sx={{ display: "flex", flexDirection: "column" }}>
              <Typography color="textSecondary" gutterBottom>
                Low Toner Alerts
              </Typography>
              <Box display="flex" alignItems="center">
                <Typography variant="h3">{stats.lowTonerCount}</Typography>
                {stats.lowTonerCount > 0 && (
                  <WarningIcon color="warning" sx={{ ml: 1 }} />
                )}
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent sx={{ display: "flex", flexDirection: "column" }}>
              <Typography color="textSecondary" gutterBottom>
                Error State Printers
              </Typography>
              <Box display="flex" alignItems="center">
                <Typography variant="h3">{stats.errorCount}</Typography>
                {stats.errorCount > 0 && (
                  <ErrorIcon color="error" sx={{ ml: 1 }} />
                )}
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Status Distribution */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Printer Status Distribution
              </Typography>

              <Box sx={{ mt: 2 }}>
                {stats.statusDistribution.map((item) => (
                  <Box key={item.status} sx={{ mb: 1 }}>
                    <Box display="flex" justifyContent="space-between" mb={0.5}>
                      <Typography variant="body2">
                        {item.status || "unknown"}
                      </Typography>
                      <Typography variant="body2">
                        {item.count} printer{item.count !== 1 ? "s" : ""}
                      </Typography>
                    </Box>
                    <Box
                      sx={{
                        width: "100%",
                        backgroundColor: "#e0e0e0",
                        borderRadius: 1,
                      }}
                    >
                      <Box
                        sx={{
                          width: `${(item.count / stats.printerCount) * 100}%`,
                          backgroundColor:
                            getStatusColor(item.status) === "success"
                              ? "#4caf50"
                              : getStatusColor(item.status) === "warning"
                              ? "#ff9800"
                              : getStatusColor(item.status) === "error"
                              ? "#f44336"
                              : "#9e9e9e",
                          height: 10,
                          borderRadius: 1,
                        }}
                      />
                    </Box>
                  </Box>
                ))}
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Recent Activity (placeholder) */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Recent Activity
              </Typography>
              <List>
                <ListItem>
                  <ListItemIcon>
                    <WarningIcon color="warning" />
                  </ListItemIcon>
                  <ListItemText
                    primary="Printer HR-01 is low on black toner (5%)"
                    secondary="10 minutes ago"
                  />
                </ListItem>
                <ListItem>
                  <ListItemIcon>
                    <ErrorIcon color="error" />
                  </ListItemIcon>
                  <ListItemText
                    primary="Printer Dev-3 is reporting a paper jam"
                    secondary="25 minutes ago"
                  />
                </ListItem>
                <ListItem>
                  <ListItemIcon>
                    <CheckIcon color="success" />
                  </ListItemIcon>
                  <ListItemText
                    primary="Agent Finance-Agent reconnected"
                    secondary="1 hour ago"
                  />
                </ListItem>
              </List>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

// Printers Component
const Printers = () => {
  const [printers, setPrinters] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedPrinter, setSelectedPrinter] = useState(null);
  const [dialogOpen, setDialogOpen] = useState(false);

  useEffect(() => {
    fetchPrinters();
  }, []);

  const fetchPrinters = async () => {
    setLoading(true);
    try {
      const response = await axios.get("/printers");
      setPrinters(response.data);
    } catch (err) {
      setError("Failed to load printer data");
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleViewPrinter = async (printerId) => {
    try {
      const response = await axios.get(`/printers/${printerId}`);
      setSelectedPrinter(response.data);
      setDialogOpen(true);
    } catch (err) {
      console.error("Error fetching printer details:", err);
    }
  };
};
