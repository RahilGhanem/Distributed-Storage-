// checkChunkTest.js
import axios from 'axios';

const checkChunkStatus = async (fileId, chunkOrder) => {
    try {
        // Step 1: Log in and get token
        const loginRes = await axios.post('http://localhost:5000/api/auth/login', {
            username: 'BordjibaHadjer',
            password: 'SecurePass123',
        });

        const token = loginRes.data.token;
        console.log('✅ Logged in. Token:', token);

        // Step 2: Make the check-chunk request
        const checkRes = await axios.get(
            `http://localhost:5000/api/storage/check-chunk/${fileId}/${chunkOrder}`,
            {
                headers: {
                    Authorization: `Bearer ${token}`,
                },
            }
        );

        console.log('✅ Chunk info retrieved:');
        console.log(checkRes.data);

    } catch (err) {
        console.error('❌ Error checking chunk:', err.response?.data || err.message);
    }
};

// Replace with actual file ID and chunk order you want to test
const fileId = 1;
const chunkOrder = 0;

checkChunkStatus(fileId, chunkOrder);
