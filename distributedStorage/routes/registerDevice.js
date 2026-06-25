const express = require('express');
const router = express.Router();
const { pool } = require('../db/db');
const authenticate = require('../middleware/authenticate');

router.post('/register-device', authenticate, async (req, res) => {
    const { ip_address, mac_address, device_type, storage_capacity } = req.body;
    const userId = req.user.userId;

    try {
        // Check if device already exists
        const deviceExists = await pool.query(
            'SELECT * FROM devices WHERE mac_address = $1',
            [mac_address]
        );

        if (deviceExists.rows.length > 0) {
            return res.status(400).json({ error: 'Device already registered' });
        }

        // Register new device
        const newDevice = await pool.query(
            `INSERT INTO devices 
            (user_id, ip_address, mac_address, device_type, storage_capacity, free_storage, status)
            VALUES ($1, $2, $3, $4, $5, $6, 'connected') 
            RETURNING *`,
            [userId, ip_address, mac_address, device_type, storage_capacity, storage_capacity]
        );

        res.status(201).json(newDevice.rows[0]);
    } catch (err) {
        console.error(err.message);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;