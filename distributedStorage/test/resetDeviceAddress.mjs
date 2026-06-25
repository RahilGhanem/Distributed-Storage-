const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));

const resetDeviceAddress = async () => {
    try {
        // 1. Login to get token
        const loginResponse = await fetch('http://localhost:5000/api/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
               username: 'leila.mohammedi',
            password: 'securePassword123'
            })
        });

        const loginData = await loginResponse.json();

        if (!loginResponse.ok) {
            console.error('❌ Login failed:', loginData);
            return;
        }

        const token = loginData.token;
        console.log('✅ Logged in. Token:', token);

        // 2. Send reset-device-address request
        const resetResponse = await fetch('http://localhost:5000/api/devices/reset-device-address', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify({
                mac_address: 'AA:BB:CC:DD:EE:02',
                new_ip_address: '10.80.13.9'
            })
        });

        const resetData = await resetResponse.json();

        if (!resetResponse.ok) {
            console.error('❌ Failed to reset device address:', resetData);
        } else {
            console.log('✅ Device IP address updated:', resetData);
        }

    } catch (err) {
        console.error('🔥 Error:', err);
    }
};

resetDeviceAddress();
