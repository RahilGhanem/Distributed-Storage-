const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));

const discoverDevices = async () => {
    try {
        // 1. Log in to get a valid token
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

        // 2. Call the discover-devices endpoint
        const response = await fetch('http://localhost:5000/api/devices/discover-devices', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        const data = await response.json();

        if (!response.ok) {
            console.error('❌ Failed to discover devices:', data);
        } else {
            console.log('✅ Connected devices (not owned by user):');
            console.table(data);
        }

    } catch (err) {
        console.error('🔥 Error:', err);
    }
};

discoverDevices();
