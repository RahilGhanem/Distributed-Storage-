// // routes/connectUser.js
// const express = require('express');
// const router = express.Router();
// const bcrypt = require('bcrypt');
// const jwt = require('jsonwebtoken');
// const { pool } = require('../db/db');

// router.post('/login', async (req, res) => {
//     const { username, password } = req.body;

//     try {
//         // Check if user exists
//         const user = await pool.query(
//             'SELECT * FROM users WHERE username = $1',
//             [username]
//         );

//         if (user.rows.length === 0) {
//             return res.status(401).json({ error: 'Invalid credentials' });
//         }

//         // Check password
//         const validPassword = await bcrypt.compare(password, user.rows[0].password_hash);
//         if (!validPassword) {
//             return res.status(401).json({ error: 'Invalid credentials' });
//         }

//         // Create JWT token
//         const token = jwt.sign(
//             { userId: user.rows[0].id },
//             process.env.JWT_SECRET,
//             { expiresIn: '24h' }
//         );

//         res.json({
//             token,
//             user: {
//                 id: user.rows[0].id,
//                 username: user.rows[0].username,
//                 email: user.rows[0].email
//             }
//         });
//     } catch (err) {
//         console.error(err.message);
//         res.status(500).json({ error: 'Server error' });
//     }
// });

// module.exports = router;

const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { pool } = require('../db/db');

router.post('/login', async (req, res) => {
    const { username, password } = req.body;

    try {
        // Check if user exists
        const user = await pool.query(
            'SELECT * FROM users WHERE username = $1',
            [username]
        );

        if (user.rows.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Check password
        const validPassword = await bcrypt.compare(password, user.rows[0].password_hash);
        if (!validPassword) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Create JWT token
        const token = jwt.sign(
            { userId: user.rows[0].id },
            process.env.JWT_SECRET,
            { expiresIn: '24h' }
        );

        res.json({
            token,
            user: {
                id: user.rows[0].id,
                username: user.rows[0].username,
                email: user.rows[0].email
            }
        });
    } catch (err) {
        console.error(err.message);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;