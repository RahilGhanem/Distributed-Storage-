const fs = require('fs');
const path = require('path');
const { pool } = require('./db/db');

async function initializeDatabase() {
  console.log('🔍 Starting database initialization...');
  
  const sqlPath = path.join(__dirname, 'db', 'db.sql');
  console.log('📂 SQL path:', sqlPath);
  
  try {
    // Verify file exists
    fs.accessSync(sqlPath, fs.constants.R_OK);
    console.log('✅ SQL file exists and is readable');

    const sql = fs.readFileSync(sqlPath, 'utf8');
    console.log('📜 SQL content length:', sql.length, 'characters');

    // Test with a simple query first
    await pool.query('SELECT 1+1 AS test');
    console.log('🔌 Database connection test passed');

    // Execute the schema SQL
    console.log('🚀 Executing schema SQL...');
    const result = await pool.query(sql);
    console.log('🎉 Database initialized successfully!', result);
    
  } catch (err) {
    console.error('💥 INITIALIZATION FAILED:', err.message);
    console.error('Full error:', err);
  }
}

initializeDatabase();