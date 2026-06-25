const express = require('express');
const router = express.Router();
const { pool } = require('../db/db');
const authenticate = require('../middleware/authenticate');

// Route to get chunks for a specific file
router.get('/file-chunks/:fileId', authenticate, async (req, res) => {
    const userId = req.user.userId;
    const fileId = req.params.fileId;
    
    try {
        // First, check if the file exists and belongs to the requesting user
        const fileResult = await pool.query(
            `SELECT * FROM files WHERE id = $1 AND owner_id = $2`,
            [fileId, userId]
        );
        
        if (fileResult.rows.length === 0) {
            return res.status(404).json({ error: 'File not found or you do not have access to it' });
        }
        
        // Then get all chunks for this file with device information
        const chunksResult = await pool.query(
            `SELECT c.*, d.status as device_status, d.ip_address as device_ip_address
             FROM chunks c
             JOIN devices d ON c.device_id = d.id
             WHERE c.file_id = $1
             ORDER BY c.chunk_order`,
            [fileId]
        );
        
        // Log the number of chunks found
        console.log(`Found ${chunksResult.rows.length} chunks for file ${fileId}`);
        
        if (chunksResult.rows.length === 0) {
            return res.status(404).json({ 
                error: 'No chunks found for this file',
                fileId: fileId,
                fileName: fileResult.rows[0].filename
            });
        }
        
        // Add debug info about chunks
        chunksResult.rows.forEach(chunk => {
            console.log(`  Chunk ${chunk.chunk_order}: Device ${chunk.device_id} status: ${chunk.device_status}`);
        });
        
        res.json(chunksResult.rows);
    } catch (err) {
        console.error(`Error getting chunks for file ${fileId}:`, err.message);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;