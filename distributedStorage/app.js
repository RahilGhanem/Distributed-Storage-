const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const helmet = require('helmet');
const { pool } = require('./db/db'); // Add this line for the test endpoint
// const initializeDatabase = require('./initDb');
const authenticate = require('./middleware/authenticate');

require('dotenv').config();

const app = express();

// Middleware
app.use(cors());
app.use(helmet());
app.use(morgan('dev'));
// Increase JSON payload size limit - add this BEFORE other routes
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Routes
// Note: Only include each base route path once
app.use('/api/auth', require('./routes/registerUser'));
app.use('/api/auth', require('./routes/connectUser'));

app.use('/api/devices', require('./routes/registerDevice'));
app.use('/api/devices', require('./routes/resetDeviceAddress'));
app.use('/api/devices', require('./routes/discoverConnectedDevices'));
app.use('/api/devices', require('./routes/checkAvailability'));

app.use('/api/storage', require('./routes/sendChunk'));
app.use('/api/storage', require('./routes/checkChunk'));
// In your app.js file where routes are registered
app.use('/api/storage', require('./routes/retrieveChunk'));
app.use('/api/storage', require('./routes/registerFile'));
// Add this route to your app.js file
app.use('/api/storage', require('./routes/listFiles'));
// Add the new route to your app.js file

app.use('/api/devices', require('./routes/updateDeviceStatus'));
// Add the new route to your app.js file

app.use('/api/storage', require('./routes/listFileChunks'));
// Add health check endpoint
app.get('/api/storage/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString() 
  });
});
// Add this to your app.js file

// Add test endpoint that doesn't require device pings
app.get('/api/devices/simple-availability', authenticate, async (req, res) => {
  try {
    // Get all connected devices from database
    const devices = await pool.query(
      'SELECT id, ip_address, status FROM devices WHERE status = $1',
      ['connected']
    );
    
    res.json({
      available: devices.rows.length,
      devices: devices.rows
    });
  } catch (err) {
    console.error('Error in simple availability check:', err);
    res.status(500).json({ error: err.message });
  }
});
// Add test endpoint
app.get('/test-device-check', async (req, res) => {
  try {
    const devices = await pool.query('SELECT id FROM devices WHERE status = $1', ['connected']);
    const deviceIds = devices.rows.map(d => d.id);
    
    res.json({
      message: 'Use these device IDs to test your /api/devices/check-availability endpoint',
      device_ids: deviceIds,
      test_url: '/api/devices/check-availability',
      test_body: { device_ids: deviceIds }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Error handling
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Something broke!' });
});

const PORT = process.env.PORT || 5000;
// initializeDatabase(); // This will run your SQL script
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});