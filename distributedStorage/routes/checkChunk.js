const express = require('express');
const router = express.Router();
const { pool } = require('../db/db');
const authenticate = require('../middleware/authenticate');

router.get('/check-chunk/:fileId/:chunkOrder', authenticate, async (req, res) => {
    const { fileId, chunkOrder } = req.params;
    const userId = req.user.userId;

    try {
        // Verify file belongs to user
        const file = await pool.query(
            'SELECT * FROM files WHERE id = $1 AND owner_id = $2',
            [fileId, userId]
        );

        if (file.rows.length === 0) {
            return res.status(404).json({ error: 'File not found or not owned by user' });
        }

        // Get chunk info
        const chunk = await pool.query(
            `SELECT c.*, d.ip_address, d.status
            FROM chunks c
            JOIN devices d ON c.device_id = d.id
            WHERE c.file_id = $1 AND c.chunk_order = $2`,
            [fileId, chunkOrder]
        );

        if (chunk.rows.length === 0) {
            return res.status(404).json({ error: 'Chunk not found' });
        }

        res.json(chunk.rows[0]);
    } catch (err) {
        console.error(err.message);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;