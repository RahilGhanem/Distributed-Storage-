const express = require('express');
const router = express.Router();
const { pool } = require('../db/db');
const authenticate = require('../middleware/authenticate');

router.post('/update-status', authenticate, async (req, res) => {
    const { device_id, status, free_storage, chunks_stored, storage_used } = req.body;
    const userId = req.user.userId;

    try {
        // Verify device belongs to user
        const device = await pool.query(
            'SELECT * FROM devices WHERE id = $1 AND user_id = $2',
            [device_id, userId]
        );

        if (device.rows.length === 0) {
            return res.status(404).json({ error: 'Device not found or not owned by user' });
        }

        // Update device status and free storage
        const updatedDevice = await pool.query(
            `UPDATE devices 
             SET status = $1, free_storage = $2, last_seen = CURRENT_TIMESTAMP 
             WHERE id = $3
             RETURNING *`,
            [status, free_storage, device_id]
        );

        console.log(`Device ${device_id} updated: status=${status}, free_storage=${free_storage}`);
        
        res.json(updatedDevice.rows[0]);
    } catch (err) {
        console.error('Error updating device status:', err.message);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;