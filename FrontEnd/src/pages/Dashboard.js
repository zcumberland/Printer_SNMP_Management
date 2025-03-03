import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { useAuth } from '../context/AuthContext';

// MUI components
import { 
  Grid, 
  Paper, 
  Typography, 
  Box, 
  Card, 
  CardContent,
  Divider,
  CircularProgress
} from '@mui/material';

// MUI icons
import PrintIcon from '@mui/icons-material/Print';
import DevicesIcon from '@mui/icons-material/Devices';
import WarningIcon from '@mui/icons-material/Warning';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';

// Chart components
import { Bar, Pie } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  ArcElement,
  Title,
  Tooltip,
  Legend
} from 'chart.js';

// Register ChartJS components
ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  ArcElement,
  Title,
  Tooltip,
  Legend
);

const StatCard = ({ icon, title, value, color = 'primary' }) => (
  <Card>
    <CardContent>
      <Box sx={{ display: 'flex', alignItems: 'center' }}>
        <Box sx={{ mr: 2, color: `${color}.main` }}>
          {icon}
        </Box>
        <Box>
          <Typography variant="h6" component="div">
            {value}
          </Typography>
          <Typography variant="body2" color="text.secondary">
            {title}
          </Typography>
        </Box>
      </Box>
    </CardContent>
  </Card>
);

const Dashboard = () => {
  const { currentUser } = useAuth();
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    totalPrinters: 0,
    activePrinters: 0,
    errorPrinters: 0,
    totalAgents: 0,
    activeAgents: 0,
    organizations: 0
  });
  
  const [tonerLevels, setTonerLevels] = useState([]);
  const [pageCountsByOrg, setPageCountsByOrg] = useState([]);
  
  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        const response = await axios.get('/api/dashboard');
        
        setStats({
          totalPrinters: response.data.printerStats.total || 0,
          activePrinters: response.data.printerStats.active || 0,
          errorPrinters: response.data.printerStats.error || 0,
          totalAgents: response.data.agentStats.total || 0,
          activeAgents: response.data.agentStats.active || 0,
          organizations: response.data.organizationCount || 0
        });
        
        setTonerLevels(response.data.tonerLevels || []);
        setPageCountsByOrg(response.data.pageCountsByOrg || []);
        
        setLoading(false);
      } catch (error) {
        console.error('Error fetching dashboard data:', error);
        setLoading(false);
      }
    };
    
    fetchDashboardData();
  }, []);
  
  // Chart data for toner levels
  const tonerData = {
    labels: tonerLevels.map(t => t.name),
    datasets: [
      {
        data: tonerLevels.map(t => t.level),
        backgroundColor: [
          '#4CAF50', // Green
          '#2196F3', // Blue
          '#FFC107', // Yellow
          '#F44336', // Red
          '#9C27B0', // Purple
          '#FF9800', // Orange
        ],
        borderWidth: 1,
      },
    ],
  };
  
  // Chart data for page counts by organization
  const pageCountData = {
    labels: pageCountsByOrg.map(p => p.name),
    datasets: [
      {
        label: 'Page Counts',
        data: pageCountsByOrg.map(p => p.count),
        backgroundColor: '#2196F3',
      },
    ],
  };
  
  const pageCountOptions = {
    responsive: true,
    plugins: {
      title: {
        display: true,
        text: 'Page Counts by Organization',
      },
    },
  };
  
  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100%' }}>
        <CircularProgress />
      </Box>
    );
  }
  
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        Dashboard
      </Typography>
      
      <Typography variant="subtitle1" gutterBottom>
        Welcome back, {currentUser?.first_name || currentUser?.username}!
      </Typography>
      
      <Divider sx={{ my: 3 }} />
      
      {/* Stats Cards */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={2}>
          <StatCard 
            icon={<PrintIcon fontSize="large" />} 
            title="Total Printers" 
            value={stats.totalPrinters} 
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={2}>
          <StatCard 
            icon={<CheckCircleIcon fontSize="large" />} 
            title="Active Printers" 
            value={stats.activePrinters}
            color="success" 
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={2}>
          <StatCard 
            icon={<WarningIcon fontSize="large" />} 
            title="Error Printers" 
            value={stats.errorPrinters}
            color="error" 
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={2}>
          <StatCard 
            icon={<DevicesIcon fontSize="large" />} 
            title="Total Agents" 
            value={stats.totalAgents} 
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={2}>
          <StatCard 
            icon={<DevicesIcon fontSize="large" />} 
            title="Active Agents" 
            value={stats.activeAgents}
            color="success" 
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={2}>
          <StatCard 
            icon={<DevicesIcon fontSize="large" />} 
            title="Organizations" 
            value={stats.organizations} 
          />
        </Grid>
      </Grid>
      
      {/* Charts */}
      <Grid container spacing={3}>
        <Grid item xs={12} md={6}>
          <Paper 
            sx={{ 
              p: 2, 
              display: 'flex', 
              flexDirection: 'column',
              height: 400
            }}
          >
            <Typography variant="h6" gutterBottom component="div">
              Toner Levels
            </Typography>
            <Box sx={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {tonerLevels.length > 0 ? (
                <Pie data={tonerData} />
              ) : (
                <Typography color="text.secondary">No toner data available</Typography>
              )}
            </Box>
          </Paper>
        </Grid>
        
        <Grid item xs={12} md={6}>
          <Paper 
            sx={{ 
              p: 2, 
              display: 'flex', 
              flexDirection: 'column',
              height: 400
            }}
          >
            <Typography variant="h6" gutterBottom component="div">
              Page Counts by Organization
            </Typography>
            <Box sx={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {pageCountsByOrg.length > 0 ? (
                <Bar data={pageCountData} options={pageCountOptions} />
              ) : (
                <Typography color="text.secondary">No page count data available</Typography>
              )}
            </Box>
          </Paper>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Dashboard;