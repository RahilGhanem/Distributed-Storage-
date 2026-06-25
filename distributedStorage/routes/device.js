const express = require('express');
const router = express.Router();
const { pool } = require('../db/db');
const authenticate = require('../middleware/authenticate');

// Simple endpoint to get all devices
router.get('/', authenticate, async (req, res) => {
    try {
        const devices = await pool.query('SELECT * FROM devices');
        res.json(devices.rows);
    } catch (error) {
        console.error('Error fetching devices:', error);
        res.status(500).json({ error: 'Failed to retrieve devices' });
    }
});

// Export the router
module.exports = router;