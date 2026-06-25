const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const { pool } = require('../db/db');

router.post('/register', async (req, res) => {
    const { username, email, password } = req.body;

    console.log('[INFO] Received registration request');
    console.log('[DEBUG] Request body:', req.body);

    try {
        // Check if user already exists
        console.log('[INFO] Checking if user already exists...');
        const userExists = await pool.query(
            'SELECT * FROM users WHERE username = $1 OR email = $2',
            [username, email]
        );

        if (userExists.rows.length > 0) {
            console.warn('[WARN] Username or email already exists');
            return res.status(400).json({ error: 'Username or email already exists' });
        }

        // Hash password
        console.log('[INFO] Hashing password...');
        const saltRounds = 10;
        const passwordHash = await bcrypt.hash(password, saltRounds);
        console.log('[DEBUG] Password hashed successfully');

        // Insert new user
        console.log('[INFO] Inserting new user into database...');
        const newUser = await pool.query(
            'INSERT INTO users (username, email, password_hash) VALUES ($1, $2, $3) RETURNING *',
            [username, email, passwordHash]
        );

        console.log('[SUCCESS] New user registered:', newUser.rows[0]);

        res.status(201).json({
            id: newUser.rows[0].id,
            username: newUser.rows[0].username,
            email: newUser.rows[0].email
        });
    } catch (err) {
        console.error('[ERROR] Registration failed:', err.message);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;
