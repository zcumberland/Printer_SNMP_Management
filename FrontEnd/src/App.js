import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import Box from '@mui/material/Box';

// Auth Components
import Login from './components/auth/Login';
import { AuthProvider, useAuth } from './context/AuthContext';

// Layout Components
import AppLayout from './components/layout/AppLayout';

// Page Components
import Dashboard from './pages/Dashboard';
import Printers from './pages/printers/Printers';
import PrinterDetails from './pages/printers/PrinterDetails';
import Agents from './pages/agents/Agents';
import AgentDetails from './pages/agents/AgentDetails';
import Organizations from './pages/organizations/Organizations';
import OrganizationDetails from './pages/organizations/OrganizationDetails';
import UserManagement from './pages/admin/UserManagement';
import UserProfile from './pages/user/UserProfile';
import NotFound from './pages/NotFound';

// Create theme
const theme = createTheme({
  palette: {
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
    background: {
      default: '#f5f5f5',
    },
  },
});

// Protected route wrapper
const ProtectedRoute = ({ children, roles }) => {
  const { isAuthenticated, currentUser } = useAuth();
  
  if (!isAuthenticated) {
    return <Navigate to="/login" />;
  }
  
  // Check if user has required role
  if (roles && !roles.includes(currentUser.role)) {
    return <Navigate to="/dashboard" />;
  }
  
  return children;
};

function App() {
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <AuthProvider>
        <Router>
          <Routes>
            <Route path="/login" element={<Login />} />
            
            <Route path="/" element={
              <ProtectedRoute>
                <AppLayout />
              </ProtectedRoute>
            }>
              <Route index element={<Navigate to="/dashboard" />} />
              <Route path="dashboard" element={<Dashboard />} />
              
              <Route path="printers">
                <Route index element={<Printers />} />
                <Route path=":id" element={<PrinterDetails />} />
              </Route>
              
              <Route path="agents">
                <Route index element={<Agents />} />
                <Route path=":id" element={<AgentDetails />} />
              </Route>
              
              <Route path="organizations">
                <Route index element={<Organizations />} />
                <Route path=":id" element={<OrganizationDetails />} />
              </Route>
              
              <Route path="admin">
                <Route path="users" element={
                  <ProtectedRoute roles={['admin']}>
                    <UserManagement />
                  </ProtectedRoute>
                } />
              </Route>
              
              <Route path="profile" element={<UserProfile />} />
            </Route>
            
            <Route path="*" element={<NotFound />} />
          </Routes>
        </Router>
      </AuthProvider>
    </ThemeProvider>
  );
}

export default App;