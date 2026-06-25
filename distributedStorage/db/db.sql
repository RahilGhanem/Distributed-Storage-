-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Devices table
CREATE TABLE devices (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    ip_address VARCHAR(45) NOT NULL,
    mac_address VARCHAR(17) NOT NULL,
    device_type VARCHAR(10) CHECK (device_type IN ('android', 'macos', 'other')),
    storage_capacity BIGINT NOT NULL, -- in bytes
    free_storage BIGINT NOT NULL, -- in bytes
    status VARCHAR(15) CHECK (status IN ('connected', 'disconnected')) DEFAULT 'disconnected',
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (mac_address)
);

-- Files table
CREATE TABLE files (
    id SERIAL PRIMARY KEY,
    owner_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    original_device_id INTEGER REFERENCES devices(id) ON DELETE SET NULL,
    filename VARCHAR(255) NOT NULL,
    size BIGINT NOT NULL, -- in bytes
    file_hash VARCHAR(64) NOT NULL, -- SHA-256 hash of the complete file
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    encryption_key_hash VARCHAR(255) NOT NULL -- hash of the encryption key
);

-- Chunks table
CREATE TABLE chunks (
    id SERIAL PRIMARY KEY,
    file_id INTEGER REFERENCES files(id) ON DELETE CASCADE,
    device_id INTEGER REFERENCES devices(id) ON DELETE SET NULL,
    chunk_order INTEGER NOT NULL,
    size INTEGER NOT NULL, -- in bytes
    chunk_hash VARCHAR(64) NOT NULL, -- SHA-256 hash of this chunk
    encryption_algorithm VARCHAR(50) NOT NULL,
    encrypted_key TEXT NOT NULL, -- encrypted chunk key
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CHECK (chunk_order >= 0)
);