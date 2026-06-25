import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import '../Services/device_service.dart';
import 'package:http/http.dart' as http;
import '../Models/files.dart';
import '../Models/chunk.dart';
import 'dart:developer' as developer;
import 'dart:async';

class FileRetrievalService {
  static String get _baseUrl => DeviceService.getServerUrl();
  
  // Check if a file can be reassembled (all chunks available)
  static Future<bool> isFileAvailable(FileInfo fileInfo) async {
    try {
      final chunks = await _getFileChunks(fileInfo.id);
      developer.log('File ${fileInfo.filename} has ${chunks.length} chunks', name: 'FileRetrievalService');
      
      if (chunks.isEmpty) {
        developer.log('No chunks found for file ${fileInfo.filename}', name: 'FileRetrievalService');
        return false;
      }
      
      // Check if we have all chunks in sequence and they're all on connected devices
      bool allAvailable = true;
      for (int i = 0; i < chunks.length; i++) {
        // Try to find chunk with this order number
        final chunk = chunks.firstWhere(
          (c) => c.chunkOrder == i,
          orElse: () => throw Exception('Missing chunk $i for file ${fileInfo.filename}')
        );
        
        if (chunk == null) {
          developer.log('Missing chunk $i for file ${fileInfo.filename}', name: 'FileRetrievalService');
          allAvailable = false;
          break;
        }
        
        if (chunk.deviceStatus != 'connected') {
          developer.log('Chunk $i is on disconnected device', name: 'FileRetrievalService');
          allAvailable = false;
          break;
        }
      }
      
      return allAvailable;
    } catch (e) {
      developer.log('Error checking file availability: $e',
        name: 'FileRetrievalService',
        error: e.toString());
      return false;
    }
  }
  
  // Get all chunks for a specific file
  static Future<List<ChunkInfo>> _getFileChunks(int fileId) async {
    final token = await DeviceService.getAuthToken();
    if (token == null) throw Exception('Not authenticated');
    
    final url = Uri.parse('$_baseUrl/api/storage/file-chunks/$fileId');
    
    developer.log('Requesting chunks for file $fileId', name: 'FileRetrievalService');
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token'
      },
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      developer.log('Received ${data.length} chunks for file $fileId', name: 'FileRetrievalService');
      return data.map((chunkData) => ChunkInfo.fromJson(chunkData)).toList();
    } else if (response.statusCode == 404) {
      developer.log('No chunks found for file $fileId: ${response.body}', 
        name: 'FileRetrievalService');
      return [];
    } else {
      developer.log('Failed to get file chunks: ${response.statusCode} - ${response.body}', 
        name: 'FileRetrievalService');
      throw Exception('Failed to get file chunks: ${response.body}');
    }
  }
  
  // Retrieve and reassemble a file from distributed chunks
  static Future<File> retrieveFile(FileInfo fileInfo) async {
    developer.log('🔄 Starting file retrieval: ${fileInfo.filename}', 
      name: 'FileRetrievalService');
    
    // Authentication check
    final token = await DeviceService.getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated. Please login first.');
    }
    
    try {
      // Step 1: Get all chunk information for this file
      final chunks = await _getFileChunks(fileInfo.id);
      
      if (chunks.isEmpty) {
        throw Exception('No chunks found for file ${fileInfo.filename}');
      }
      
      // Check if we have all chunks in sequence
      final int expectedChunks = chunks.map((c) => c.chunkOrder).fold(0, (a, b) => a > b ? a : b) + 1;
      if (chunks.length != expectedChunks) {
        developer.log('Missing chunks for file ${fileInfo.filename}. Expected $expectedChunks, got ${chunks.length}',
          name: 'FileRetrievalService');
        throw Exception('Some chunks are missing for this file');
      }
      
      // Step 2: Create a temporary file to store the reassembled data
      final tempDir = await getTemporaryDirectory();
      final outputFile = File('${tempDir.path}/${fileInfo.filename}');
      final outputSink = outputFile.openWrite();
      
      // Step 3: Retrieve and decrypt each chunk in order
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks.firstWhere(
          (c) => c.chunkOrder == i, 
          orElse: () => throw Exception('Missing chunk $i for file ${fileInfo.filename}')
        );
        
        // Check if the device is online
        if (chunk.deviceStatus != 'connected') {
          throw Exception('Device storing chunk ${chunk.chunkOrder} is offline');
        }
        
        try {
          // Retrieve the encrypted chunk data from storage
          final encryptedData = await _retrieveChunk(chunk);
          
          // Decrypt the chunk
          final decryptedData = _decryptChunk(
            encryptedData,
            chunk.encryptedKey,
            chunk.iv
          );
          
          // Validate the chunk hash
          final chunkHash = sha256.convert(decryptedData).toString();
          if (chunkHash != chunk.chunkHash) {
            throw Exception('Chunk integrity check failed for chunk ${chunk.chunkOrder}');
          }
          
          // Write the decrypted chunk to the output file
          outputSink.add(decryptedData);
          
          // Log progress
          developer.log('✅ Retrieved and decrypted chunk ${i+1}/${chunks.length}',
            name: 'FileRetrievalService');
        } catch (e) {
          developer.log('Error processing chunk ${chunk.chunkOrder}: $e',
            name: 'FileRetrievalService',
            error: e.toString());
          throw Exception('Failed to retrieve chunk ${chunk.chunkOrder}: $e');
        }
      }
      
      // Close the file
      await outputSink.close();
      
      // Validate the final file hash
      final fileBytes = await outputFile.readAsBytes();
      final fileHash = sha256.convert(fileBytes).toString();
      
      if (fileHash != fileInfo.fileHash) {
        throw Exception('File integrity check failed. File may be corrupted.');
      }
      
      // Copy to downloads directory for user access
      final downloadsDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final finalFile = File('${downloadsDir.path}/${fileInfo.filename}');
      await outputFile.copy(finalFile.path);
      
      // Clean up temp file
      await outputFile.delete();
      
      developer.log('✅ File retrieval completed: ${finalFile.path}', 
        name: 'FileRetrievalService');
      
      return finalFile;
    } catch (e) {
      developer.log('❌ File retrieval failed: $e', 
        name: 'FileRetrievalService', 
        error: e.toString());
      rethrow;
    }
  }
  
  // Retrieve a single chunk from a device
  static Future<Uint8List> _retrieveChunk(ChunkInfo chunk) async {
    final token = await DeviceService.getAuthToken();
    if (token == null) throw Exception('Not authenticated');
    
    try {
      // Request chunk retrieval from server
      final url = Uri.parse('$_baseUrl/api/storage/retrieve-chunk/${chunk.fileId}/${chunk.chunkOrder}');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        // Server should provide the raw chunk data in the response body
        return Uint8List.fromList(response.bodyBytes);
      } else {
        developer.log('Failed to retrieve chunk: ${response.statusCode} - ${response.body}',
          name: 'FileRetrievalService');
        throw Exception('Failed to retrieve chunk ${chunk.chunkOrder}: Server error (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Chunk retrieval timed out. The device may be slow or unresponsive.');
    } catch (e) {
      developer.log('Error retrieving chunk: $e',
        name: 'FileRetrievalService',
        error: e.toString());
      rethrow;
    }
  }
  
  // Decrypt a chunk using its key and IV
  static Uint8List _decryptChunk(Uint8List encryptedData, String encryptedKey, String iv) {
    try {
      final keyBytes = base64.decode(encryptedKey);
      final key = encrypt.Key(Uint8List.fromList(keyBytes));
      final ivData = encrypt.IV(base64.decode(iv));
      
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypt.Encrypted(encryptedData);
      final decrypted = encrypter.decryptBytes(encrypted, iv: ivData);
      
      return Uint8List.fromList(decrypted);
    } catch (e) {
      developer.log('Error decrypting chunk: $e',
        name: 'FileRetrievalService',
        error: e.toString());
      throw Exception('Failed to decrypt chunk: $e');
    }
  }
}