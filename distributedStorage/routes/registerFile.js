const express = require('express');
const router = express.Router();
const { pool } = require('../db/db');
const authenticate = require('../middleware/authenticate');
const axios = require('axios');
const crypto = require('crypto');

// Add this route at the top of your file, after the imports
router.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});
// Route to register a new file for storage
router.post('/register-file', authenticate, async (req, res) => {
    const { filename, size, file_hash, encryption_key_hash } = req.body;
    const userId = req.user.userId;
    
    try {
        const newFile = await pool.query(
            `INSERT INTO files 
            (owner_id, filename, size, file_hash, encryption_key_hash)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING *`,
            [userId, filename, size, file_hash, encryption_key_hash]
        );

        res.status(201).json(newFile.rows[0]);
    } catch (err) {
        console.error('Error registering file:', err.message);
        res.status(500).json({ error: 'Server error: ' + err.message });
    }
});

// Route for sending chunks to target devices
router.post('/send-chunk', authenticate, async (req, res) => {
    const { file_id, chunk_data, chunk_order, target_device_ids, 
            encryption_algorithm, encrypted_key, iv } = req.body;
    const userId = req.user.userId;

    try {
        // Log the request payload size for debugging
        console.log(`Received chunk upload request: file_id=${file_id}, chunk_order=${chunk_order}, data size=${chunk_data.length}`);
        console.log(`Target devices: ${JSON.stringify(target_device_ids)}`);
        
        // Verify file belongs to user
        const file = await pool.query(
            'SELECT * FROM files WHERE id = $1 AND owner_id = $2',
            [file_id, userId]
        );

        if (file.rows.length === 0) {
            return res.status(404).json({ error: 'File not found or not owned by user' });
        }

        // Get target devices info
        const targetDevices = await pool.query(
            'SELECT id, ip_address, free_storage FROM devices WHERE id = ANY($1) AND status = \'connected\'',
            [target_device_ids]
        );

        console.log(`Found ${targetDevices.rows.length} available devices`);
        
        if (targetDevices.rows.length === 0) {
            return res.status(400).json({ error: 'No target devices available' });
        }

        // Calculate chunk hash
        const buffer = Buffer.from(chunk_data, 'base64');
        const chunk_hash = crypto.createHash('sha256').update(buffer).digest('hex');

        // Choose target device (simple selection for now)
        const targetDevice = targetDevices.rows[0];
        
        console.log(`Selected target device ${targetDevice.id} at ${targetDevice.ip_address}`);

        if (targetDevice.free_storage < buffer.length) {
            return res.status(400).json({ error: 'Not enough storage on target device' });
        }

        // Send encrypted chunk to target device
        try {
            // Updated to include port 8080 in the URL
            console.log(`Sending chunk to device at http://${targetDevice.ip_address}:8080/receive-chunk`);
            
            const response = await axios.post(`http://${targetDevice.ip_address}:8080/receive-chunk`, {
                chunk_data: chunk_data,
                metadata: {
                    file_id,
                    chunk_order,
                    chunk_hash,
                    encryption_algorithm,
                    encrypted_key,
                    iv
                }
            });

            console.log(`Device response: ${JSON.stringify(response.data)}`);

            // Store chunk reference in database
            const newChunk = await pool.query(
                `INSERT INTO chunks 
                (file_id, device_id, chunk_order, size, chunk_hash, encryption_algorithm, encrypted_key, iv)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                RETURNING *`,
                [file_id, targetDevice.id, chunk_order, buffer.length, chunk_hash, 
                 encryption_algorithm, encrypted_key, iv]
            );

            // Update target device's free storage
            await pool.query(
                'UPDATE devices SET free_storage = free_storage - $1 WHERE id = $2',
                [buffer.length, targetDevice.id]
            );

            res.json(newChunk.rows[0]);
        } catch (err) {
            console.error('Error sending encrypted chunk to device:', err);
            
            // Enhanced error logging
            if (err.response) {
                console.error(`Device response status: ${err.response.status}`);
                console.error(`Device response data:`, err.response.data);
            } else if (err.request) {
                console.error('No response received from device');
            } else {
                console.error('Error details:', err.message);
            }
            
            return res.status(502).json({ 
                error: 'Failed to send encrypted chunk to target device',
                details: err.message,
                targetDevice: targetDevice.ip_address
            });
        }

    } catch (err) {
        console.error('Server error in send-chunk endpoint:', err);
        res.status(500).json({ error: 'Server error: ' + err.message });
    }
});

// Export the router at the end of the file
module.exports = router;