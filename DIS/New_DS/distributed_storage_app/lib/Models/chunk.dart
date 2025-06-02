class ChunkInfo {
  final int id;
  final int fileId;
  final int deviceId;
  final int chunkOrder;
  final int size;
  final String chunkHash;
  final String encryptionAlgorithm;
  final String encryptedKey;
  final String iv;
  final String createdAt;
  final String deviceStatus;
  final String? deviceIpAddress;

  ChunkInfo({
    required this.id,
    required this.fileId,
    required this.chunkOrder,
    required this.chunkHash,
    required this.encryptionAlgorithm,
    required this.encryptedKey,
    required this.iv,
    required this.deviceId,
    required this.size,
    required this.createdAt,
    this.deviceStatus = 'unknown',
    this.deviceIpAddress,
  });

  factory ChunkInfo.fromJson(Map<String, dynamic> json) {
    // Debug the incoming data
    // print('Parsing chunk from JSON: $json');
    
    return ChunkInfo(
      id: json['id'],
      fileId: json['file_id'],
      deviceId: json['device_id'],
      chunkOrder: json['chunk_order'],
      size: json['size'] ?? 0,  // Add null safety for size
      chunkHash: json['chunk_hash'],
      encryptionAlgorithm: json['encryption_algorithm'],
      encryptedKey: json['encrypted_key'],
      iv: json['iv'],
      createdAt: json['created_at'],
      // Fix the key name to match what's coming from the server
      deviceStatus: json['device_status'] ?? 'unknown',
      deviceIpAddress: json['device_ip_address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_id': fileId,
      'device_id': deviceId,
      'chunk_order': chunkOrder,
      'size': size,
      'chunk_hash': chunkHash,
      'encryption_algorithm': encryptionAlgorithm,
      'encrypted_key': encryptedKey,
      'iv': iv,
      'created_at': createdAt,
      'device_status': deviceStatus,
      'device_ip_address': deviceIpAddress,
    };
  }
}