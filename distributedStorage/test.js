const fs = require('fs');
const crypto = require('crypto');

const fileData = fs.readFileSync('explanation.txt');
const fileHash = crypto.createHash('sha256').update(fileData).digest('hex');

console.log('Size:', fileData.length, 'bytes');
console.log('SHA-256:', fileHash);

