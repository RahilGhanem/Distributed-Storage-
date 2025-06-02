// const express = require('express');
// const router = express.Router();
// const { pool } = require('../db/db');
// const authenticate = require('../middleware/authenticate');
// const axios = require('axios');
// const crypto = require('crypto');

// const algorithm = 'aes-256-cbc'; // Encryption algorithm

// router.post('/send-chunk', authenticate, async (req, res) => {
//     const { file_id, chunk_data, chunk_order, target_device_id, encryption_algorithm, encrypted_key, iv } = req.body;
//     const userId = req.user.userId;

//     console.log('Received request to send chunk');
//     console.log('Request Body:', req.body);

//     try {
//         // Verify file belongs to user
//         const file = await pool.query(
//             'SELECT * FROM files WHERE id = $1 AND owner_id = $2',
//             [file_id, userId]
//         );

//         if (file.rows.length === 0) {
//             console.log('File not found or not owned by user');
//             return res.status(404).json({ error: 'File not found or not owned by user' });
//         }

//         console.log('File verification passed');

//         // Get target device info
//         const targetDevice = await pool.query(
//             'SELECT ip_address, free_storage FROM devices WHERE id = $1 AND status = \'connected\'',
//             [target_device_id]
//         );

//         if (targetDevice.rows.length === 0) {
//             console.log('Target device not available or not connected');
//             return res.status(400).json({ error: 'Target device not available' });
//         }

//         console.log('Target device verification passed');
//         const targetIP = targetDevice.rows[0].ip_address;
//         const freeStorage = targetDevice.rows[0].free_storage;

//         console.log(`Target device IP: ${targetIP}`);
//         console.log(`Free storage on device: ${freeStorage}`);

//         if (freeStorage < chunk_data.length) {
//             console.log('Not enough storage on target device');
//             return res.status(400).json({ error: 'Not enough storage on target device' });
//         }

//         // Calculate chunk hash
//         const buffer = Buffer.from(chunk_data, 'base64');
//         const chunk_hash = crypto.createHash('sha256').update(buffer).digest('hex');
//         console.log(`Chunk hash: ${chunk_hash}`);

//         // Send encrypted chunk to target device - KEY FIX HERE
//         try {
//             console.log('Sending encrypted chunk to target device...');
//             const response = await axios.post(`http://${targetIP}/receive-chunk`, {
//                 chunk_data: chunk_data, // Changed from encrypted_data to chunk_data to match receiver
//                 metadata: {
//                     file_id,
//                     chunk_order,
//                     chunk_hash,
//                     encryption_algorithm,
//                     encrypted_key,
//                     iv
//                 }
//             });

//             console.log('Encrypted chunk sent successfully to target device');
//             console.log(response.data);

//             // Store chunk reference in database
//             const newChunk = await pool.query(
//                 `INSERT INTO chunks 
//                 (file_id, device_id, chunk_order, size, chunk_hash, encryption_algorithm, encrypted_key, iv)
//                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
//                 RETURNING *`,
//                 [file_id, target_device_id, chunk_order, buffer.length, chunk_hash, encryption_algorithm, encrypted_key, iv]
//             );

//             // Update target device's free storage
//             await pool.query(
//                 'UPDATE devices SET free_storage = free_storage - $1 WHERE id = $2',
//                 [buffer.length, target_device_id]
//             );

//             res.json(newChunk.rows[0]);
//         } catch (err) {
//             console.error('Error sending encrypted chunk to device:', err.message);
//             console.error('Error details:', err.response ? err.response.data : 'No response');
//             return res.status(502).json({ error: 'Failed to send encrypted chunk to target device' });
//         }

//     } catch (err) {
//         console.error('Server error:', err.message);
//         res.status(500).json({ error: 'Server error' });
//     }
// });

// module.exports = router;

// // // Modified sender route to handle encryption
// // const express = require('express');
// // const router = express.Router();
// // const { pool } = require('../db/db');
// // const authenticate = require('../middleware/authenticate');
// // const axios = require('axios');

// // router.post('/send-chunk', authenticate, async (req, res) => {
// //     const { file_id, chunk_data, chunk_order, target_device_id, encryption_algorithm, encrypted_key, iv } = req.body;
// //     const userId = req.user.userId;

// //     console.log('Received request to send encrypted chunk');
    
// //     try {
// //         // Verify file belongs to user
// //         const file = await pool.query(
// //             'SELECT * FROM files WHERE id = $1 AND owner_id = $2',
// //             [file_id, userId]
// //         );

// //         if (file.rows.length === 0) {
// //             console.log('File not found or not owned by user');
// //             return res.status(404).json({ error: 'File not found or not owned by user' });
// //         }

// //         console.log('File verification passed');

// //         // Get target device info
// //         const targetDevice = await pool.query(
// //             'SELECT ip_address, free_storage FROM devices WHERE id = $1 AND status = \'connected\'',
// //             [target_device_id]
// //         );

// //         if (targetDevice.rows.length === 0) {
// //             console.log('Target device not available or not connected');
// //             return res.status(400).json({ error: 'Target device not available' });
// //         }

// //         console.log('Target device verification passed');
// //         console.log(`Target device IP: ${targetDevice.rows[0].ip_address}`);
        
// //         // Calculate estimated size of encrypted data
// //         // For encrypted data, we need to consider the Base64 encoding overhead
// //         const estimatedSize = Math.ceil(chunk_data.length * 4/3); // Base64 adds ~33% overhead
        
// //         if (targetDevice.rows[0].free_storage < estimatedSize) {
// //             console.log('Not enough storage on target device');
// //             return res.status(400).json({ error: 'Not enough storage on target device' });
// //         }

// //         // Send encrypted chunk to target device
// //         try {
// //             console.log('Sending encrypted chunk to target device...');
// //             const response = await axios.post(`http://${targetDevice.rows[0].ip_address}/receive-chunk`, {
// //                 chunk_data,
// //                 metadata: {
// //                     file_id,
// //                     chunk_order,
// //                     encryption_algorithm,
// //                     encrypted_key,
// //                     iv // Include the IV needed for decryption
// //                 }
// //             });

// //             console.log('Encrypted chunk sent successfully to target device');
            
// //             // If successful, store chunk reference in database
// //             const newChunk = await pool.query(
// //                 `INSERT INTO chunks 
// //                 (file_id, device_id, chunk_order, size, encryption_algorithm, encrypted_key, iv)
// //                 VALUES ($1, $2, $3, $4, $5, $6, $7)
// //                 RETURNING *`,
// //                 [file_id, target_device_id, chunk_order, estimatedSize, encryption_algorithm, encrypted_key, iv]
// //             );

// //             // Update target device's free storage
// //             await pool.query(
// //                 'UPDATE devices SET free_storage = free_storage - $1 WHERE id = $2',
// //                 [estimatedSize, target_device_id]
// //             );

// //             res.json(newChunk.rows[0]);
// //         } catch (err) {
// //             console.error('Error sending chunk to device:', err.message);
// //             console.error('Error details:', err.response ? err.response.data : 'No response');
// //             return res.status(502).json({ error: 'Failed to send chunk to target device' });
// //         }
// //     } catch (err) {
// //         console.error('Server error:', err.message);
// //         res.status(500).json({ error: 'Server error' });
// //     }
// // });

// // module.exports = router;





// // const express = require('express');
// // const router = express.Router();
// // const { pool } = require('../db/db');
// // const authenticate = require('../middleware/authenticate');
// // const axios = require('axios');

// // router.post('/send-chunk', authenticate, async (req, res) => {
// //     const { file_id, chunk_data, chunk_order, target_device_id, encryption_algorithm, encrypted_key } = req.body;
// //     const userId = req.user.userId;

// //     console.log('Received request to send chunk');
// //     console.log('Request Body:', req.body);

// //     try {
// //         // Verify file belongs to user
// //         const file = await pool.query(
// //             'SELECT * FROM files WHERE id = $1 AND owner_id = $2',
// //             [file_id, userId]
// //         );

// //         if (file.rows.length === 0) {
// //             console.log('File not found or not owned by user');
// //             return res.status(404).json({ error: 'File not found or not owned by user' });
// //         }

// //         console.log('File verification passed');

// //         // Get target device info
// //         const targetDevice = await pool.query(
// //             'SELECT ip_address, free_storage FROM devices WHERE id = $1 AND status = \'connected\'',
// //             [target_device_id]
// //         );

// //         if (targetDevice.rows.length === 0) {
// //             console.log('Target device not available or not connected');
// //             return res.status(400).json({ error: 'Target device not available' });
// //         }

// //         console.log('Target device verification passed');
// //         console.log(`Target device IP: ${targetDevice.rows[0].ip_address}`);
// //         console.log(`Free storage on device: ${targetDevice.rows[0].free_storage}`);

// //         if (targetDevice.rows[0].free_storage < chunk_data.length) {
// //             console.log('Not enough storage on target device');
// //             return res.status(400).json({ error: 'Not enough storage on target device' });
// //         }

// //         // Calculate chunk hash (simplified - should be done client-side)
// //         const chunk_hash = require('crypto').createHash('sha256').update(chunk_data).digest('hex');
// //         console.log(`Chunk hash: ${chunk_hash}`);

// //         // Send chunk to target device
// //         try {
// //             console.log('Sending chunk to target device...');
// //             const response = await axios.post(`http://${targetDevice.rows[0].ip_address}/receive-chunk`, {
// //                 chunk_data,
// //                 metadata: {
// //                     file_id,
// //                     chunk_order,
// //                     chunk_hash,
// //                     encryption_algorithm,
// //                     encrypted_key
// //                 }
// //             });

// //             console.log('Chunk sent successfully to target device');
// //             console.log(response.data);

// //             // If successful, store chunk reference in database
// //             const newChunk = await pool.query(
// //                 `INSERT INTO chunks 
// //                 (file_id, device_id, chunk_order, size, chunk_hash, encryption_algorithm, encrypted_key)
// //                 VALUES ($1, $2, $3, $4, $5, $6, $7)
// //                 RETURNING *`,
// //                 [file_id, target_device_id, chunk_order, chunk_data.length, chunk_hash, encryption_algorithm, encrypted_key]
// //             );

// //             // Update target device's free storage
// //             await pool.query(
// //                 'UPDATE devices SET free_storage = free_storage - $1 WHERE id = $2',
// //                 [chunk_data.length, target_device_id]
// //             );

// //             res.json(newChunk.rows[0]);
// //         } catch (err) {
// //             console.error('Error sending chunk to device:', err.message);
// //             console.error('Error details:', err.response ? err.response.data : 'No response');
// //             return res.status(502).json({ error: 'Failed to send chunk to target device' });
// //         }
// //     } catch (err) {
// //         console.error('Server error:', err.message);
// //         res.status(500).json({ error: 'Server error' });
// //     }
// // });

const express = require('express');
const router = express.Router();
const { pool } = require('../db/db');
const authenticate = require('../middleware/authenticate');

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
        console.error(err.message);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;