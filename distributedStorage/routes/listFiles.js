const express = require('express');
const router = express.Router();
const { pool } = require('../db/db');
const authenticate = require('../middleware/authenticate');

// Route to get all files owned by a user
router.get('/files', authenticate, async (req, res) => {
    const userId = req.user.userId;
    
    try {
        // Query to get all files owned by the user
        const filesResult = await pool.query(
            `SELECT f.* 
             FROM files f
             WHERE f.owner_id = $1
             ORDER BY f.created_at DESC`,
            [userId]
        );
        
        // For each file, fetch its chunks and check availability
        const files = await Promise.all(filesResult.rows.map(async (file) => {
            // Get chunks for this file with device status
            const chunksResult = await pool.query(
                `SELECT c.*, d.status as device_status, d.ip_address as device_ip_address
                 FROM chunks c
                 JOIN devices d ON c.device_id = d.id
                 WHERE c.file_id = $1
                 ORDER BY c.chunk_order`,
                [file.id]
            );
            
            // Add debug logging
            console.log(`File ${file.id} (${file.filename}) has ${chunksResult.rows.length} chunks`);
            chunksResult.rows.forEach(chunk => {
                console.log(`  Chunk ${chunk.chunk_order}: Device ${chunk.device_id} status: ${chunk.device_status}`);
            });
            
            // Return file with chunks and availability flag
            return {
                ...file,
                chunks: chunksResult.rows,
                available: chunksResult.rows.length > 0 && 
                          chunksResult.rows.every(chunk => chunk.device_status === 'connected')
            };
        }));
        
        res.json(files);
    } catch (err) {
        console.error('Error getting user files:', err.message);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;