// const express = require('express');
// const router = express.Router();
// const { pool } = require('../db/db');
// const authenticate = require('../middleware/authenticate');
// const axios = require('axios');

// // Check availability of devices
// router.post('/check-availability', authenticate, async (req, res) => {
//   try {
//     const { device_ids } = req.body;
    
//     if (!device_ids || !Array.isArray(device_ids) || device_ids.length === 0) {
//       return res.status(400).json({ error: 'No device IDs provided' });
//     }
    
//     // Query devices by ID
//     const devices = await pool.query(
//       'SELECT id, ip_address, status FROM devices WHERE id = ANY($1)',
//       [device_ids]
//     );
    
//     // Filter for connected devices
//     const availableDevices = devices.rows.filter(device => device.status === 'connected');
    
//     console.log(`Found ${availableDevices.length} available devices out of ${device_ids.length} requested`);
    
//     // Try to ping each device to verify it's actually accessible
//     const verifiedDevices = [];
    
//     for (const device of availableDevices) {
//       try {
//         console.log(`Pinging device ${device.id} at ${device.ip_address}...`);
        
//         // Add timeout to avoid waiting too long
//         const pingResponse = await axios.get(`http://${device.ip_address}/ping`, {
//           timeout: 5000
//         });
        
//         if (pingResponse.status === 200) {
//           console.log(`✅ Device ${device.id} is responsive`);
//           verifiedDevices.push({
//             id: device.id,
//             ip_address: device.ip_address,
//             status: 'connected',
//             ping: pingResponse.data
//           });
//         }
//       } catch (pingError) {
//         console.log(`❌ Failed to ping device ${device.id}: ${pingError.message}`);
//         // Device is in DB but not responding - keep in list but mark as unreachable
//         verifiedDevices.push({
//           id: device.id,
//           ip_address: device.ip_address, 
//           status: 'unreachable',
//           error: pingError.message
//         });
//       }
//     }
    
//     res.json({
//       requested: device_ids.length,
//       available: verifiedDevices.filter(d => d.status === 'connected').length,
//       devices: verifiedDevices
//     });
//   } catch (error) {
//     console.error('Error checking device availability:', error);
//     res.status(500).json({ error: 'Server error' });
//   }
// });

// module.exports = router;


const express = require('express');
const router = express.Router();
const { pool } = require('../db/db');
const authenticate = require('../middleware/authenticate');

// Check availability of devices
router.post('/check-availability', authenticate, async (req, res) => {
  try {
    console.log('Received device availability check request');
    
    const { device_ids } = req.body;
    console.log('Received device_ids:', device_ids);
    
    if (!device_ids || !Array.isArray(device_ids) || device_ids.length === 0) {
      console.log('Invalid device_ids format:', device_ids);
      return res.status(400).json({ error: 'No device IDs provided' });
    }
    
    // Query devices by ID
    const queryText = 'SELECT id, ip_address, status FROM devices WHERE id = ANY($1)';
    console.log('Executing query:', queryText, 'with params:', [device_ids]);
    
    const devices = await pool.query(queryText, [device_ids]);
    console.log('Query returned', devices.rows.length, 'devices');
    
    // Filter for connected devices
    const availableDevices = devices.rows.filter(device => device.status === 'connected');
    
    console.log(`Found ${availableDevices.length} available devices out of ${device_ids.length} requested`);
    
    // For now, trust the database status and consider all connected devices as available
    res.json({
      requested: device_ids.length,
      available: availableDevices.length,
      devices: availableDevices.map(d => ({
        id: d.id,
        ip_address: d.ip_address,
        status: d.status
      }))
    });
  } catch (error) {
    console.error('Error checking device availability:', error);
    res.status(500).json({ error: 'Server error', details: error.message });
  }
});

module.exports = router;