// Modified sendFileChunks function with encryption
import fs from 'fs';
import axios from 'axios';
import crypto from 'crypto';

const loginAndSendChunks = async () => {
    try {
        // STEP 1: LOGIN to get the token
        const loginResponse = await axios.post('http://localhost:5000/api/auth/login', {
            username: 'BordjibaHadjer',
            password: 'SecurePass123' // Replace with actual password
        });

        const token = loginResponse.data.token;
        console.log('✅ Logged in. Token:', token);

        // STEP 2: Proceed to send the file
        await sendFileChunks('explanation.txt', 2, token);
    } catch (err) {
        console.error('❌ Login failed:', err.response?.data || err.message);
    }
};

// Function to encrypt data using AES-256-CBC
const encryptData = (data, secretKey) => {
    // Generate a random initialization vector
    const iv = crypto.randomBytes(16);
    
    // Create cipher using the key and iv
    const cipher = crypto.createCipheriv('aes-256-cbc', secretKey, iv);
    
    // Encrypt the data
    let encrypted = cipher.update(data);
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    
    // Return both the IV and encrypted data
    return {
        iv: iv.toString('base64'),
        encryptedData: encrypted.toString('base64')
    };
};

// Function to read the file, split it into chunks, encrypt and send each chunk
const sendFileChunks = async (filePath, targetDeviceId, token) => {
    try {
        const fileData = fs.readFileSync(filePath);
        const chunkSize = 1024 * 1024; // 1MB
        const totalChunks = Math.ceil(fileData.length / chunkSize);

        console.log(`File size: ${fileData.length} bytes`);
        console.log(`Total chunks: ${totalChunks}`);

        // Generate a random encryption key
        const encryptionKey = crypto.randomBytes(32); // 256 bits key for AES-256

        // Encrypt the encryption key with the receiver's public key
        // For this example, we'll just use a placeholder
        // In a real implementation, you'd use the receiver's RSA public key
        const encrypted_key = encryptionKey.toString('base64');
        
        console.log('Generated encryption key for file');

        for (let chunkOrder = 0; chunkOrder < totalChunks; chunkOrder++) {
            const chunkData = fileData.slice(chunkOrder * chunkSize, (chunkOrder + 1) * chunkSize);
            
            // Encrypt the chunk data
            const { iv, encryptedData } = encryptData(chunkData, encryptionKey);

            const requestBody = {
                file_id: 1,
                chunk_data: encryptedData, // Send encrypted data
                chunk_order: chunkOrder,
                target_device_id: targetDeviceId,
                encryption_algorithm: 'AES-256-CBC',
                encrypted_key: encrypted_key,
                iv: iv // Send the IV needed for decryption
            };

            try {
                console.log(`🚀 Sending encrypted chunk ${chunkOrder + 1}...`);

                const response = await axios.post(
                    'http://localhost:5000/api/storage/send-chunk',
                    requestBody,
                    {
                        headers: {
                            'Content-Type': 'application/json',
                            'Authorization': `Bearer ${token}`,
                        },
                    }
                );

                console.log(`✅ Chunk ${chunkOrder + 1} sent:`, response.data);
            } catch (err) {
                console.error(`❌ Failed to send chunk ${chunkOrder + 1}:`, err.response?.data || err.message);
            }
        }
    } catch (err) {
        console.error('❌ Error reading file:', err.message);
    }
};

loginAndSendChunks();

// import fs from 'fs';
// import axios from 'axios';

// const loginAndSendChunks = async () => {
//     try {
//         // STEP 1: LOGIN to get the token
//         const loginResponse = await axios.post('http://localhost:5000/api/auth/login', {
//             username: 'BordjibaHadjer',
//             password: 'SecurePass123' // Replace with actual password
//         });

//         const token = loginResponse.data.token;
//         console.log('✅ Logged in. Token:', token);

//         // STEP 2: Proceed to send the file
//         await sendFileChunks('explanation.txt', 2, token);
//     } catch (err) {
//         console.error('❌ Login failed:', err.response?.data || err.message);
//     }
// };

// // Function to read the file, split it into chunks, and send each chunk
// const sendFileChunks = async (filePath, targetDeviceId, token) => {
//     try {
//         const fileData = fs.readFileSync(filePath);
//         const chunkSize = 1024 * 1024; // 1MB
//         const totalChunks = Math.ceil(fileData.length / chunkSize);

//         console.log(`File size: ${fileData.length} bytes`);
//         console.log(`Total chunks: ${totalChunks}`);

//         for (let chunkOrder = 0; chunkOrder < totalChunks; chunkOrder++) {
//             const chunkData = fileData.slice(chunkOrder * chunkSize, (chunkOrder + 1) * chunkSize);

//             const requestBody = {
//                 file_id: 1,
//                 chunk_data: chunkData.toString('base64'), // Important: convert binary to base64
//                 chunk_order: chunkOrder,
//                 target_device_id: targetDeviceId,
//                 encryption_algorithm: 'AES',
//                 encrypted_key: 'sample_encrypted_key',
//             };

//             try {
//                 console.log(`🚀 Sending chunk ${chunkOrder + 1}...`);

//                 const response = await axios.post(
//                     'http://localhost:5000/api/storage/send-chunk',
//                     requestBody,
//                     {
//                         headers: {
//                             'Content-Type': 'application/json',
//                             'Authorization': `Bearer ${token}`,
//                         },
//                     }
//                 );

//                 console.log(`✅ Chunk ${chunkOrder + 1} sent:`, response.data);
//             } catch (err) {
//                 console.error(`❌ Failed to send chunk ${chunkOrder + 1}:`, err.response?.data || err.message);
//             }
//         }
//     } catch (err) {
//         console.error('❌ Error reading file:', err.message);
//     }
// };

// loginAndSendChunks();
