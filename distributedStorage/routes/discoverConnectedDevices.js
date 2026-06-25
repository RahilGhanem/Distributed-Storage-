const express = require('express');
const router = express.Router();
const { pool } = require('../db/db');
const authenticate = require('../middleware/authenticate');
const ping = require('ping');

router.get('/discover-devices', authenticate, async (req, res) => {
    const userId = req.user.userId;

    try {
        // Step 1: Get all devices not owned by the current user
        const result = await pool.query(
            `SELECT id, ip_address, mac_address, device_type, free_storage, status
             FROM devices 
             WHERE user_id != $1`,
            [userId]
        );

        const devices = result.rows;

        console.log(`🔍 Starting discovery for ${devices.length} device(s)...`);

        // Step 2: Ping all devices and update their status
        const updatedDevices = await Promise.all(devices.map(async device => {
            console.log(`📡 Pinging device ${device.mac_address} at ${device.ip_address}...`);

            const pingResult = await ping.promise.probe(device.ip_address, { timeout: 2 });

            const newStatus = pingResult.alive ? 'connected' : 'disconnected';
            console.log(`   ➤ Result: ${pingResult.alive ? '✅ Alive' : '❌ Unreachable'}`);

            if (device.status !== newStatus) {
                await pool.query(
                    `UPDATE devices 
                     SET status = $1, last_seen = CURRENT_TIMESTAMP 
                     WHERE id = $2`,
                    [newStatus, device.id]
                );
                console.log(`   🔄 Status updated from '${device.status}' to '${newStatus}' in DB.`);
                device.status = newStatus;
            } else {
                console.log(`   ℹ️ Status unchanged ('${device.status}').`);
            }

            return device;
        }));

        // Step 3: Return ALL devices (both connected and disconnected)
        console.log(`✅ Discovery complete. Found ${updatedDevices.length} device(s) in total.`);
        console.log(`   ├─ ${updatedDevices.filter(d => d.status === 'connected').length} connected`);
        console.log(`   └─ ${updatedDevices.filter(d => d.status === 'disconnected').length} disconnected`);

        res.json(updatedDevices);
    } catch (err) {
        console.error('❌ Error during device discovery:', err.message);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;