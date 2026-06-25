// Add this in your /send-chunk route where you're calling axios.post:

try {
    console.log(`Sending chunk to device at http://${targetDevice.ip_address}/receive-chunk`);
    
    const response = await axios.post(`http://${targetDevice.ip_address}/receive-chunk`, {
        chunk_data: chunk_data,
        metadata: {
            file_id,
            chunk_order,
            chunk_hash,
            encryption_algorithm,
            encrypted_key,
            iv
        }
    }, {
        timeout: 30000 // 30 seconds timeout
    });

    console.log(`Device response: ${JSON.stringify(response.data)}`);

    // Rest of your code...
} catch (err) {
    console.error('Error sending encrypted chunk to device:', err);
    
    // Better error logging
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