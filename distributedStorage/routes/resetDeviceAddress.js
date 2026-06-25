const express = require('express');
const router = express.Router();
const { pool } = require('../db/db');
const authenticate = require('../middleware/authenticate');

router.post('/reset-device-address', authenticate, async (req, res) => {
    const { device_id, new_ip_address } = req.body;
    const userId = req.user.userId;

    try {
        // Verify device belongs to user (using device_id instead of mac_address)
        const device = await pool.query(
            'SELECT * FROM devices WHERE device_id = $1 AND user_id = $2',
            [device_id, userId]
        );

        if (device.rows.length === 0) {
            // If device doesn't exist, create a new entry
            const newDevice = await pool.query(
                `INSERT INTO devices (device_id, user_id, ip_address, status, last_seen, created_at) 
                 VALUES ($1, $2, $3, 'connected', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) 
                 RETURNING *`,
                [device_id, userId, new_ip_address]
            );
            
            return res.json({
                message: 'New device registered and IP address set',
                device: newDevice.rows[0]
            });
        }

        // Update IP address and status for existing device
        const updatedDevice = await pool.query(
            `UPDATE devices 
             SET ip_address = $1, status = 'connected', last_seen = CURRENT_TIMESTAMP
             WHERE device_id = $2 AND user_id = $3
             RETURNING *`,
            [new_ip_address, device_id, userId]
        );

        res.json({
            message: 'Device IP address updated successfully',
            device: updatedDevice.rows[0]
        });
    } catch (err) {
        console.error('Error updating device IP:', err.message);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;