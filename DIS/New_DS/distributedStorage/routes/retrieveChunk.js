const express = require('express');
const router = express.Router();
const { pool } = require('../db/db');
const authenticate = require('../middleware/authenticate');

// Route to retrieve a specific chunk
router.post('/retrieve-chunk/:fileId/:chunkOrder', authenticate, async (req, res) => {
    const userId = req.user.userId;
    const fileId = req.params.fileId;
    const chunkOrder = req.params.chunkOrder;
    
    console.log(`Retrieving chunk ${chunkOrder} of file ${fileId} for user ${userId}`);
    
    try {
        // First verify the file belongs to the user
        const fileResult = await pool.query(
            `SELECT * FROM files WHERE id = $1 AND owner_id = $2`,
            [fileId, userId]
        );
        
        if (fileResult.rows.length === 0) {
            return res.status(404).json({ error: 'File not found or you do not have access to it' });
        }
        
        // Get the chunk information and device it's stored on
        const chunkResult = await pool.query(
            `SELECT c.*, d.ip_address, d.status
             FROM chunks c
             JOIN devices d ON c.device_id = d.id
             WHERE c.file_id = $1 AND c.chunk_order = $2`,
            [fileId, chunkOrder]
        );
        
        if (chunkResult.rows.length === 0) {
            return res.status(404).json({ error: `Chunk ${chunkOrder} not found for this file` });
        }
        
        const chunk = chunkResult.rows[0];
        
        if (chunk.status !== 'connected') {
            return res.status(503).json({ 
                error: 'Device storing this chunk is currently offline',
                deviceId: chunk.device_id,
                deviceStatus: chunk.status
            });
        }
        
        console.log(`Found chunk ${chunkOrder} for file ${fileId} on device ${chunk.device_id}`);
        
        try {
            // Get the actual chunk data from chunk_data table
            // Note: We need to make sure this table exists and has the right data
            const chunkDataResult = await pool.query(
                `SELECT chunk_data FROM chunk_data WHERE chunk_id = $1`,
                [chunk.id]
            );
            
            if (chunkDataResult.rows.length === 0) {
                console.error(`No data found for chunk ${chunk.id} in chunk_data table`);
                return res.status(404).json({ error: 'Chunk data not found in storage' });
            }
            
            // Return the raw chunk data
            console.log(`Successfully retrieved chunk ${chunkOrder} data for file ${fileId}`);
            const chunkData = chunkDataResult.rows[0].chunk_data;
            
            // Determine if the data is Base64-encoded or raw bytes
            let responseData;
            if (typeof chunkData === 'string') {
                responseData = Buffer.from(chunkData, 'base64');
            } else {
                responseData = chunkData; // Assuming it's already a Buffer
            }
            
            res.set('Content-Type', 'application/octet-stream');
            res.send(responseData);
            
        } catch (err) {
            console.error(`Error retrieving chunk data: ${err.message}`);
            
            // Check if the error is related to missing table
            if (err.message.includes('relation "chunk_data" does not exist')) {
                return res.status(500).json({ 
                    error: 'Chunk data storage table does not exist',
                    details: 'Server is missing chunk_data table. Check database setup.'
                });
            }
            
            res.status(500).json({ error: `Failed to retrieve chunk data: ${err.message}` });
        }
    } catch (err) {
        console.error(`Error processing chunk request: ${err.message}`);
        res.status(500).json({ error: 'Server error', details: err.message });
    }
});

module.exports = router;