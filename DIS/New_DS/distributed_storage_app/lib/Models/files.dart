import 'package:distributed_storage_app/Models/chunk.dart';
import 'dart:developer' as developer;

class FileInfo {
  final int id;
  final int ownerId;
  final int? originalDeviceId;
  final String filename;
  final int size;
  final String fileHash;
  final String createdAt;
  final String encryptionKeyHash;
  final List<ChunkInfo>? chunks;

  FileInfo({
    required this.id,
    required this.ownerId,
    this.originalDeviceId,
    required this.filename,
    required this.size,
    required this.fileHash,
    required this.createdAt,
    required this.encryptionKeyHash,
    this.chunks,
  });

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    try {
      // Handle chunks if present
      List<ChunkInfo>? chunksList;
      if (json['chunks'] != null) {
        chunksList = (json['chunks'] as List)
            .map((chunk) => ChunkInfo.fromJson(chunk))
            .toList();
      }
      
      // Handle type conversions safely
      int id = _parseIntFromJson(json['id'], 'id');
      int ownerId = _parseIntFromJson(json['owner_id'], 'owner_id');
      int? originalDeviceId = json['original_device_id'] != null ? 
          _parseIntFromJson(json['original_device_id'], 'original_device_id') : null;
      int size = _parseIntFromJson(json['size'], 'size');

      return FileInfo(
        id: id,
        ownerId: ownerId,
        originalDeviceId: originalDeviceId,
        filename: json['filename'] as String,
        size: size,
        fileHash: json['file_hash'] as String,
        createdAt: json['created_at'] as String,
        encryptionKeyHash: json['encryption_key_hash'] as String,
        chunks: chunksList,
      );
    } catch (e) {
      // Log the parsing error with the raw JSON to assist debugging
      developer.log('Error parsing FileInfo: $e', name: 'FileInfo');
      developer.log('Raw JSON: $json', name: 'FileInfo');
      rethrow; // Re-throw to let the caller handle the error
    }
  }
  
  // Helper method for safe integer parsing
  static int _parseIntFromJson(dynamic value, String fieldName) {
    if (value == null) {
      throw FormatException('Missing required field: $fieldName');
    }
    
    if (value is int) {
      return value;
    } else if (value is String) {
      return int.parse(value);
    } else {
      throw FormatException('Invalid type for $fieldName: ${value.runtimeType}');
    }
  }
  
  // Convert FileInfo to JSON map
  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'original_device_id': originalDeviceId,
    'filename': filename,
    'size': size,
    'file_hash': fileHash,
    'created_at': createdAt,
    'encryption_key_hash': encryptionKeyHash,
    'chunks': chunks?.map((chunk) => chunk.toJson()).toList(),
  };
  
  @override
  String toString() {
    return 'FileInfo{id: $id, filename: $filename, size: $size, chunks: ${chunks?.length ?? 0}}';
  }
}