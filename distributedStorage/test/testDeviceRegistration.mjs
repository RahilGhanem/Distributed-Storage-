// testDeviceRegistration.mjs

const fetch = (await import('node-fetch')).default;

const loginAndRegisterDevice = async () => {
    try {
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

        const deviceResponse = await fetch('http://localhost:5000/api/devices/register-device', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify({
                ip_address: '10.80.0.3',
                mac_address: 'AA:BB:CC:DD:EE:02',
                device_type: 'android',
                storage_capacity: 1073741824
            })
        });

        const deviceData = await deviceResponse.json();

        if (!deviceResponse.ok) {
            console.error('❌ Device registration failed:', deviceData);
        } else {
            console.log('✅ Device registered:', deviceData);
        }
    } catch (err) {
        console.error('🔥 Error:', err);
    }
};

loginAndRegisterDevice();
