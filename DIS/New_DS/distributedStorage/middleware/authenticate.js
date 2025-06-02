// middleware/authenticate.js
const jwt = require('jsonwebtoken');
const { pool } = require('../db/db.js');

module.exports = async (req, res, next) => {
    try {
        // Get token from header
        const token = req.header('Authorization')?.replace('Bearer ', '');
        
        if (!token) {
            return res.status(401).json({ error: 'No token, authorization denied' });
        }

        // Verify token
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        
        // Check if user still exists
        const user = await pool.query(
            'SELECT * FROM users WHERE id = $1',
            [decoded.userId]
        );

        if (user.rows.length === 0) {
            return res.status(401).json({ error: 'Token is not valid' });
        }

        req.user = { userId: decoded.userId };
        next();
    } catch (err) {
        console.error(err.message);
        res.status(401).json({ error: 'Token is not valid' });
    }
};