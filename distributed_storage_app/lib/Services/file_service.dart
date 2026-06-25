import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../Models/chunk.dart';
import '../Models/files.dart';
import '../Models/device.dart';
import 'package:path/path.dart' as path;
import 'device_service.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:file_picker/file_picker.dart';

class FileService {
  static int chunkSize = 1024 * 1024; // 1MB chunk size by default
  static const String encryptionAlgorithm = 'AES-256-CBC';
  
  static String get _baseUrl => DeviceService.getServerUrl();
  
  /// Get list of files owned by the current user
// Add or update this method in your FileService class
static Future<List<FileInfo>> getUserFiles() async {
  final token = await DeviceService.getAuthToken();
  if (token == null) {
    throw Exception('Not authenticated. Please login first.');
  }

  // Ensure there's proper URL construction
  final url = Uri.parse('$_baseUrl/api/storage/files');
  
  final response = await http.get(
    url,
    headers: {
      'Authorization': 'Bearer $token'
    },
  );

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((fileData) => FileInfo.fromJson(fileData)).toList();
  } else {
    developer.log('Failed to get user files: ${response.body}', name: 'FileService');
    throw Exception('Failed to get user files: ${response.statusCode}: ${response.body}');
  }
}

  /// Main method to upload and distribute a file
// Update the beginning of the uploadFile method

static Future<FileInfo> uploadFile(
  File file,
  List<String> deviceIds, {
  bool adaptiveRedundancy = false,
  int retries = 0,
  int timeoutSeconds = 30,
  bool continueOnPartialFailure = false,
}) async {
  developer.log('Starting file upload process...', name: 'FileService');
  
  // First check if server and devices are reachable
  final connectionsAvailable = await checkConnections(deviceIds);
  if (!connectionsAvailable) {
    developer.log('Connection check failed - either server or devices are unavailable', name: 'FileService');
    throw Exception('Could not connect to server or no devices available. Check your connection and try again.');
  }
  
  final token = await DeviceService.getAuthToken();
  if (token == null) throw Exception('Not authenticated');
  
  if (deviceIds.isEmpty) {
    throw Exception('No target devices specified for distribution');
  }

  try {
    // Read file and prepare for encryption
    final fileBytes = await file.readAsBytes();
    final fileName = path.basename(file.path);
    
    // Generate encryption key and hashes
    final key = _generateRandomKey();
    final keyHash = sha256.convert(utf8.encode(key)).toString();
    final fileHash = sha256.convert(fileBytes).toString();
    
    developer.log(
      'Preparing to upload file: $fileName (${fileBytes.length} bytes)',
      name: 'FileService'
    );

    // First register the file metadata in the database
    final fileInfo = await _registerFile(fileName, fileBytes.length, fileHash, keyHash);
    developer.log('File registered with ID: ${fileInfo.id}', name: 'FileService');
    
    // Then distribute chunks across devices
    await _distributeFileChunks(fileInfo.id, file, key, deviceIds);
    
    return fileInfo;
  } catch (e) {
    developer.log('Error during file upload: $e', name: 'FileService', error: e.toString());
    throw Exception('File upload failed: ${e.toString()}');
  }
}

  /// Generate a secure random encryption key
  static String _generateRandomKey() {
    final key = encrypt.Key.fromSecureRandom(32); // 256 bits for AES-256
    return base64.encode(key.bytes);
  }

// Add this method to your FileService class to check server and device connections
// Replace or update the checkConnections method
// Update the checkConnections method in FileService.dart

// Update the endpoint in checkConnections method
// In the checkConnections method
// In FileService.dart
static Future<bool> checkConnections(List<String> deviceIds) async {
  try {
    // Check main server connection with timeout
    final serverUrl = Uri.parse('$_baseUrl/api/storage/health');
    
    try {
      final serverResponse = await http.get(serverUrl)
        .timeout(const Duration(seconds: 5));
      
      if (serverResponse.statusCode != 200) {
        developer.log('Server health check failed', name: 'FileService');
        return false;
      }
      
      // Use the simpler availability endpoint
      final token = await DeviceService.getAuthToken();
      final availabilityUrl = Uri.parse('$_baseUrl/api/devices/simple-availability');
      
      final availabilityResponse = await http.get(
        availabilityUrl,
        headers: {
          'Authorization': 'Bearer $token'
        }
      ).timeout(const Duration(seconds: 5));
      
      if (availabilityResponse.statusCode == 200) {
        final data = jsonDecode(availabilityResponse.body);
        final availableCount = data['available'] ?? 0;
        
        return availableCount > 0;
      }
      
      return false;
    } catch (e) {
      developer.log('Connection check failed: $e', name: 'FileService');
      return false;
    }
  } catch (e) {
    developer.log('Connection check failed: $e', name: 'FileService');
    return false;
  }
}
  /// Register file metadata with the server before uploading chunks
  /// Register file metadata with the server before uploading chunks
static Future<FileInfo> _registerFile(String fileName, int fileSize, String fileHash, String keyHash) async {
  final token = await DeviceService.getAuthToken();
  if (token == null) {
    throw Exception('Not authenticated. Please login first.');
  }

  final url = Uri.parse('$_baseUrl/api/storage/register-file');
  
  try {
    // Ensure fileSize is correctly passed as an integer
    // Convert to String representation in JSON payload
    final payload = {
      'filename': fileName,
      'size': fileSize,  // Make sure this is an integer, not a string
      'file_hash': fileHash,
      'encryption_key_hash': keyHash
    };
    
    developer.log('Registering file with payload: $payload', name: 'FileService');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      
      // Debug the response from server
      developer.log('Server response for file registration: $data', name: 'FileService');
      
      return FileInfo.fromJson(data);
    } else {
      developer.log('Failed to register file: ${response.statusCode} - ${response.body}', name: 'FileService');
      throw Exception('Failed to register file: ${response.body}');
    }
  } catch (e) {
    developer.log('Error registering file: $e', name: 'FileService', error: e.toString());
    throw Exception('Error registering file: ${e.toString()}');
  }
}

  /// Set the chunk size for file splitting
  static void setChunkSize(int size) {
    // Limit to reasonable values between 64KB and 10MB
    if (size >= 64 * 1024 && size <= 10 * 1024 * 1024) {
      chunkSize = size;
      developer.log('Chunk size set to $size bytes', name: 'FileService');
    } else {
      developer.log('Invalid chunk size: $size. Keeping current value: $chunkSize bytes', name: 'FileService');
    }
  }
  
  /// Split file into chunks and distribute them to target devices
  static Future<void> _distributeFileChunks(
      int fileId, File file, String encryptionKey, List<String> targetDeviceIds) async {
    final token = await DeviceService.getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated. Please login first.');
    }

    final fileSize = await file.length();
    final numberOfChunks = (fileSize / chunkSize).ceil();

    developer.log('Splitting file into $numberOfChunks chunks of $chunkSize bytes max', name: 'FileService');
    
    try {
      // Open file as stream for efficient processing of large files
      final fileStream = file.openRead();
      int chunkIndex = 0;
      final List<int> chunkBuffer = [];
      
      // Process file in chunks
      await for (var data in fileStream) {
        chunkBuffer.addAll(data);
        
        // Process complete chunks
        while (chunkBuffer.length >= chunkSize) {
          final chunk = chunkBuffer.sublist(0, chunkSize);
          chunkBuffer.removeRange(0, chunkSize);
          
          // Select device using round-robin or another strategy
          final targetDeviceId = targetDeviceIds[chunkIndex % targetDeviceIds.length];
          
          await _processAndUploadChunk(
            fileId, 
            chunk, 
            chunkIndex,
            encryptionKey,
            [targetDeviceId] // Send to specific device for this chunk
          );
          
          chunkIndex++;
        }
      }
      
      // Process any remaining data as the final chunk
      if (chunkBuffer.isNotEmpty) {
        final targetDeviceId = targetDeviceIds[chunkIndex % targetDeviceIds.length];
        
        await _processAndUploadChunk(
          fileId,
          chunkBuffer,
          chunkIndex,
          encryptionKey,
          [targetDeviceId]
        );
      }

      developer.log('All chunks distributed successfully', name: 'FileService');
    } catch (e) {
      developer.log('Error distributing file chunks: $e', name: 'FileService', error: e.toString());
      throw Exception('Failed to distribute file chunks: ${e.toString()}');
    }
  }

  /// Process and upload a single chunk to a target device
  /// Process and upload a single chunk to a target device with retry logic
static Future<void> _processAndUploadChunk(
    int fileId, List<int> chunkData, int chunkOrder, String encryptionKey, List<String> targetDeviceIds) async {
  final token = await DeviceService.getAuthToken();
  if (token == null) throw Exception('Not authenticated');

  // Convert string device IDs to integers for backend
  final deviceIdsForBackend = targetDeviceIds
      .map((id) => int.tryParse(id) ?? 0)
      .where((id) => id > 0)
      .toList();
  
  if (deviceIdsForBackend.isEmpty) {
    throw Exception('No valid device IDs provided for chunk $chunkOrder');
  }

  // Encrypt the chunk data
  final encrypted = _encryptChunk(Uint8List.fromList(chunkData), encryptionKey);
  
  // Calculate hash of original (unencrypted) data for integrity verification
  final chunkHash = sha256.convert(chunkData).toString();
  
  // Prepare the request payload
  final payload = jsonEncode({
    'file_id': fileId,
    'chunk_data': base64.encode(encrypted.bytes),
    'chunk_order': chunkOrder,
    'target_device_ids': deviceIdsForBackend,
    'encryption_algorithm': encryptionAlgorithm,
    'encrypted_key': encrypted.encryptedKey,
    'iv': encrypted.iv,
    'chunk_hash': chunkHash
  });

  // Define retry parameters
  int retryCount = 0;
  const maxRetries = 3;
  const initialDelay = Duration(seconds: 1);
  
  while (true) {
    try {
      final url = Uri.parse('$_baseUrl/api/storage/send-chunk');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: payload,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Connection timed out when uploading chunk $chunkOrder'),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        developer.log('Successfully uploaded chunk $chunkOrder (${chunkData.length} bytes)',
            name: 'FileService');
        return; // Success, exit the retry loop
      } else if (response.statusCode == 502 || response.statusCode == 503 || response.statusCode == 504) {
        // Handle specific error codes that might benefit from retry
        final errorData = jsonDecode(response.body);
        developer.log(
            'Recoverable error uploading chunk $chunkOrder: ${response.statusCode} - ${errorData['error']}',
            name: 'FileService');
            
        // Check if we should retry
        if (retryCount >= maxRetries) {
          throw Exception('Server returned ${response.statusCode} after $maxRetries retries: ${response.body}');
        }
        
        // Try with a different device if available
        if (errorData['details']?.contains('ECONNREFUSED') == true && 
            deviceIdsForBackend.length > 1 && 
            retryCount < deviceIdsForBackend.length) {
          // Move the failed device to the end of the list to try a different one
          final failedDevice = deviceIdsForBackend.removeAt(0);
          deviceIdsForBackend.add(failedDevice);
          
          developer.log('Retrying with different device: ${deviceIdsForBackend[0]}', name: 'FileService');
        }
      } else {
        // Non-recoverable error
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      retryCount++;
      
      if (e is TimeoutException || retryCount >= maxRetries) {
        developer.log('Error uploading chunk $chunkOrder: $e', name: 'FileService', error: e.toString());
        throw Exception('Failed to upload chunk $chunkOrder: ${e.toString()}');
      }
      
      // Exponential backoff for retrying
      final delay = initialDelay * (2 << (retryCount - 1)); // 1s, 2s, 4s, etc.
      developer.log('Retrying upload of chunk $chunkOrder in ${delay.inSeconds}s (attempt ${retryCount + 1}/$maxRetries)',
          name: 'FileService');
      await Future.delayed(delay);
    }
  }
}

static Future<List<String>> filterAvailableDevices(List<String> deviceIds) async {
  final token = await DeviceService.getAuthToken();
  if (token == null) throw Exception('Not authenticated');

  final url = Uri.parse('$_baseUrl/api/devices/check-status');
  
  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({
        'device_ids': deviceIds,
      }),
    );

    if (response.statusCode == 200) {
      final List<dynamic> availableDevices = jsonDecode(response.body);
      developer.log('Available devices: ${availableDevices.length}/${deviceIds.length}', name: 'FileService');
      
      return availableDevices
          .where((device) => device['status'] == 'connected')
          .map((device) => device['id'].toString())
          .toList();
    } else {
      developer.log('Error checking device status: ${response.statusCode} - ${response.body}', name: 'FileService');
      
      // Fallback to using all provided devices if we can't check status
      return deviceIds;
    }
  } catch (e) {
    developer.log('Error checking device status: $e', name: 'FileService');
    // Fallback to using all provided devices
    return deviceIds;
  }
}
  /// Encrypt chunk data using the encryption key
  static _EncryptedData _encryptChunk(Uint8List data, String encryptionKey) {
    try {
      final keyBytes = base64.decode(encryptionKey);
      final key = encrypt.Key(Uint8List.fromList(keyBytes));
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      
      final encrypted = encrypter.encryptBytes(data, iv: iv);
      
      return _EncryptedData(
        bytes: encrypted.bytes,
        iv: base64.encode(iv.bytes),  
        encryptedKey: encryptionKey
      );
    } catch (e) {
      developer.log('Encryption error: $e', name: 'FileService', error: e.toString());
      throw Exception('Failed to encrypt data: ${e.toString()}');
    }
  }

  /// Retrieve file chunks from distributed storage
  static Future<List<ChunkInfo>> getFileChunks(int fileId) async {
    final token = await DeviceService.getAuthToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$_baseUrl/api/storage/file-chunks/$fileId');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token'
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((chunkData) => ChunkInfo.fromJson(chunkData)).toList();
    } else {
      developer.log('Failed to get file chunks: ${response.body}', name: 'FileService');
      throw Exception('Failed to get file chunks: ${response.body}');
    }
  }

  /// Open file picker dialog
  static Future<FilePickerResult?> pickFile() async {
    return await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
  }
}

/// Class to hold encrypted data and metadata
class _EncryptedData {
  final Uint8List bytes;
  final String iv;
  final String encryptedKey;

  _EncryptedData({required this.bytes, required this.iv, required this.encryptedKey});
}