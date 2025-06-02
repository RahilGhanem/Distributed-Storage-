const axios = require('axios');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const API_BASE_URL = 'http://localhost:5000';
const fileId = 1;
const chunkOrder = 0;

// Use the full normalized path
const CHUNK_SENDER_PATH = path.normalize(
    'C:/Users/ASUS/OneDrive/Desktop/New/sendChunkToServer.js'
);

const OUTPUT_DIR = path.join(__dirname, '../retrieved_chunks');

async function test() {
    try {
        // 1. Verify sender exists
        if (!fs.existsSync(CHUNK_SENDER_PATH)) {
            throw new Error(`Sender script not found at: ${CHUNK_SENDER_PATH}`);
        }

        // 2. Login
        console.log('🔑 Logging in...');
        const login = await axios.post(`${API_BASE_URL}/api/auth/login`, {
            username: 'BordjibaHadjer',
            password: 'SecurePass123'
        });
        const token = login.data.token;

        // 3. Start chunk transfer
        console.log(`📥 Requesting chunk ${fileId}-${chunkOrder}`);
        
        // Start sender after 1 second
        setTimeout(() => {
            console.log(`🚀 Launching: node "${CHUNK_SENDER_PATH}"`);
            const senderProcess = exec(`node "${CHUNK_SENDER_PATH}"`, 
                { timeout: 10000 },
                (error, stdout, stderr) => {
                    if (error) {
                        console.error('❌ Sender error:', error.message);
                        return;
                    }
                    console.log(stdout);
                });
            
            senderProcess.stdout.on('data', data => console.log(data));
            senderProcess.stderr.on('data', data => console.error(data));
        }, 1000);

        // 4. Make the request
        const response = await axios.post(
            `${API_BASE_URL}/api/storage/retrieve-chunk/${fileId}/${chunkOrder}`,
            {},
            {
                headers: { Authorization: `Bearer ${token}` },
                responseType: 'arraybuffer',
                timeout: 30000
            }
        );

        // 5. Save result
        if (!fs.existsSync(OUTPUT_DIR)) {
            fs.mkdirSync(OUTPUT_DIR, { recursive: true });
        }

        const outFile = path.join(OUTPUT_DIR, `chunk_${fileId}_${chunkOrder}.bin`);
        fs.writeFileSync(outFile, response.data);
        console.log(`✅ Chunk saved to ${outFile}`);

    } catch (err) {
        console.error('❌ Test failed:');
        if (err.response) {
            console.error(`Status: ${err.response.status}`);
            console.error(`Data: ${err.response.data.toString()}`);
        } else {
            console.error(err.message);
        }
        process.exit(1);
    }
}

test();