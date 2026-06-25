import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../Models/chunk.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'dart:async';
import 'package:web_socket_channel/io.dart';

class ChunkReceiverService {
  static const String _chunksStorageKey = 'stored_chunks_registry';
  static const String _chunkTransferPort = '5001';
  
  // Directory where chunks are stored
// In chunk_receiver_service.dart, modify the _chunksDirectory getter

static Future<Directory> get _chunksDirectory async {
  // For Android, prefer external storage for easier access
  if (Platform.isAndroid) {
    // Try external storage first (more accessible)
    final externalDir = await getExternalStorageDirectory();
    if (externalDir != null) {
      final chunksDir = Directory('${externalDir.path}/distributed_storage_chunks');
      if (!await chunksDir.exists()) {
        await chunksDir.create(recursive: true);
      }
      return chunksDir;
    }
  }
  
  // Fallback to app documents directory if external storage is not available
  final appDir = await getApplicationDocumentsDirectory();
  final chunksDir = Directory('${appDir.path}/chunks');
  if (!await chunksDir.exists()) {
    await chunksDir.create(recursive: true);
  }
  return chunksDir;
}
  
  // Store a chunk to the local disk
 static Future<void> storeChunk({
  required dynamic fileId, 
  required dynamic chunkOrder, 
  required List<int> chunkData,
  String? chunkHash,
  String? encryptionAlgorithm,
  String? encryptedKey,
  String? iv
}) async {
  try {
    // Create directory structure
    final appDocDir = await getApplicationDocumentsDirectory();
    final fileDir = Directory('${appDocDir.path}/chunks/$fileId');
    
    // Ensure directory exists
    if (!await fileDir.exists()) {
      await fileDir.create(recursive: true);
    }
    
    // Write chunk to file
    final file = File('${fileDir.path}/$chunkOrder');
    await file.writeAsBytes(chunkData);
    
    print('✅ Chunk saved to: ${file.path} (${chunkData.length} bytes)');
    
    // Store metadata if necessary
    if (chunkHash != null || encryptionAlgorithm != null) {
      final metadataFile = File('${fileDir.path}/$chunkOrder.meta');
      final metadata = {
        'hash': chunkHash,
        'encryption': encryptionAlgorithm,
        'key': encryptedKey,
        'iv': iv
      };
      await metadataFile.writeAsString(jsonEncode(metadata));
    }
  } catch (e) {
    print('❌ Error storing chunk: $e');
    rethrow;
  }
}
  
  // Register chunk metadata in shared preferences for tracking
  static Future<void> _registerChunkMetadata({
    required String fileId,
    required String chunkOrder,
    required String filePath,
    required String chunkHash,
    required String encryptionAlgorithm,
    required String encryptedKey,
    required String iv,
    required int size
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing chunks registry or create a new one
    final List<String> chunksJson = prefs.getStringList(_chunksStorageKey) ?? [];
    final List<Map<String, dynamic>> chunks = chunksJson
        .map((json) => jsonDecode(json) as Map<String, dynamic>)
        .toList();
    
    // Add the new chunk metadata
    chunks.add({
      'file_id': fileId,
      'chunk_order': chunkOrder,
      'file_path': filePath,
      'chunk_hash': chunkHash,
      'encryption_algorithm': encryptionAlgorithm,
      'encrypted_key': encryptedKey,
      'iv': iv,
      'size': size,
      'timestamp': DateTime.now().toIso8601String()
    });
    
    // Save the updated registry
    final updatedChunksJson = chunks.map((chunk) => jsonEncode(chunk)).toList();
    await prefs.setStringList(_chunksStorageKey, updatedChunksJson);
  }

  // Retrieve a stored chunk
  static Future<Uint8List?> retrieveChunk(dynamic fileId, dynamic chunkOrder) async {
    try {
      final fileIdStr = fileId.toString();
      final chunkOrderStr = chunkOrder.toString();
      final chunkFilename = 'chunk_${fileIdStr}_$chunkOrderStr';
      
      final dir = await _chunksDirectory;
      final chunkFile = File('${dir.path}/$chunkFilename');
      
      if (await chunkFile.exists()) {
        return await chunkFile.readAsBytes();
      }
      
      return null;
    } catch (e) {
      developer.log('Error retrieving chunk: $e', 
        name: 'ChunkReceiverService', 
        error: e.toString());
      return null;
    }
  }
  
  // Get list of all stored chunks
  static Future<List<Map<String, dynamic>>> getStoredChunks() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> chunksJson = prefs.getStringList(_chunksStorageKey) ?? [];
    return chunksJson
        .map((json) => jsonDecode(json) as Map<String, dynamic>)
        .toList();
  }
  
  // In Services/chunk_receiver_service.dart

static Future<List<Map<String, dynamic>>> listStoredChunks() async {
  final List<Map<String, dynamic>> chunks = [];
  
  try {
    // Check multiple possible storage locations
    final List<Directory> possibleDirectories = [];
    
    // Try app documents directory first
    final appDocDir = await getApplicationDocumentsDirectory();
    possibleDirectories.add(Directory('${appDocDir.path}/chunks'));
    
    // Also try app's temporary directory
    final tempDir = await getTemporaryDirectory();
    possibleDirectories.add(Directory('${tempDir.path}/chunks'));
    
    // Try the app's local storage directory
    final appDir = await getApplicationSupportDirectory();
    possibleDirectories.add(Directory('${appDir.path}/chunks'));
    
    // Try external storage on Android
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        possibleDirectories.add(Directory('${externalDir.path}/chunks'));
      }
    }
    
    // Log all possible paths for debugging
    print('⚠️ Checking these directories for chunks:');
    for (var dir in possibleDirectories) {
      print('   - ${dir.path}');
    }
    
    // Look through all possible directories
    for (var chunksDirectory in possibleDirectories) {
      if (await chunksDirectory.exists()) {
        print('✅ Found directory: ${chunksDirectory.path}');
        
        // List file directories (file IDs)
        await for (var fileDir in chunksDirectory.list()) {
          if (fileDir is Directory) {
            final fileId = fileDir.path.split('/').last;
            print('📂 Found fileId: $fileId');
            
            // List chunk files within each file directory
            await for (var chunkFile in fileDir.list()) {
              if (chunkFile is File) {
                final chunkOrder = chunkFile.path.split('/').last;
                final stat = await chunkFile.stat();
                print('📄 Found chunk: $chunkOrder (${stat.size} bytes)');
                
                chunks.add({
                  'fileId': fileId,
                  'chunkOrder': chunkOrder,
                  'size': stat.size,
                  'modified': stat.modified.toString(),
                  'path': chunkFile.path,
                });
              }
            }
          }
        }
      }
    }
  } catch (e) {
    print('❌ Error listing chunks: $e');
  }
  
  return chunks;
}

  // Set up TCP listener for retrieving chunks
  static Future<void> startChunkTransferServer() async {
    try {
      // Create a new server socket
      final serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4, 
        int.parse(_chunkTransferPort)
      );
      
      developer.log('🚀 Chunk transfer server listening on port $_chunkTransferPort',
        name: 'ChunkReceiverService');
      
      // Listen for connections
      serverSocket.listen((socket) async {
        developer.log('📡 New connection from ${socket.remoteAddress.address}:${socket.remotePort}',
          name: 'ChunkReceiverService');
        
        String data = '';
        
        // Listen for data from the client
        socket.listen((List<int> bytes) async {
          // Convert bytes to string
          data += String.fromCharCodes(bytes);
          
          try {
            // Try to parse the data as JSON
            final requestData = jsonDecode(data);
            final fileId = requestData['file_id'];
            final chunkOrder = requestData['chunk_order'];
            
            // Retrieve the requested chunk
            final chunk = await retrieveChunk(fileId, chunkOrder);
            
            if (chunk != null) {
              // Send the chunk data back
              socket.add(chunk);
              developer.log('✅ Sent chunk fileId=$fileId, order=$chunkOrder to ${socket.remoteAddress.address}',
                name: 'ChunkReceiverService');
            } else {
              socket.write(jsonEncode({
                'error': 'Chunk not found',
                'file_id': fileId,
                'chunk_order': chunkOrder
              }));
              developer.log('❌ Requested chunk not found: fileId=$fileId, order=$chunkOrder',
                name: 'ChunkReceiverService');
            }
          } catch (e) {
            // If data isn't complete JSON yet, wait for more data
            if (e is! FormatException) {
              socket.write(jsonEncode({
                'error': 'Failed to process request: $e'
              }));
              developer.log('❌ Error processing chunk request: $e',
                name: 'ChunkReceiverService',
                error: e.toString());
            }
          }
        }, 
        onError: (e) {
          developer.log('❌ Socket error: $e',
            name: 'ChunkReceiverService',
            error: e.toString());
        },
        onDone: () {
          developer.log('📤 Connection closed with ${socket.remoteAddress.address}',
            name: 'ChunkReceiverService');
          socket.destroy();
        });
      });
    } catch (e) {
      developer.log('❌ Failed to start chunk transfer server: $e',
        name: 'ChunkReceiverService',
        error: e.toString());
    }
  }
  
  // Notify system about chunk storage (reporting back to the server)
  static Future<void> _notifyChunkStored(dynamic fileId, dynamic chunkOrder) async {
    // This would typically notify the central server that you have the chunk
    // For now, we'll just log it
    developer.log('🔔 Notifying system about stored chunk: fileId=$fileId, order=$chunkOrder',
      name: 'ChunkReceiverService');
      
    // In a production app, you might want to notify the server:
    // try {
    //   final url = Uri.parse('http://server-url/api/storage/notify-chunk');
    //   final response = await http.post(
    //     url,
    //     headers: {'Content-Type': 'application/json'},
    //     body: jsonEncode({
    //       'file_id': fileId,
    //       'chunk_order': chunkOrder,
    //       'status': 'stored'
    //     })
    //   );
    //   if (response.statusCode == 200) {
    //     developer.log('✅ Server notified about stored chunk',
    //       name: 'ChunkReceiverService');
    //   }
    // } catch (e) {
    //   developer.log('❌ Failed to notify server about stored chunk: $e',
    //     name: 'ChunkReceiverService',
    //     error: e.toString());
    // }
  }
  
  // Clean up old chunks that are no longer needed
  static Future<void> performMaintenance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> chunksJson = prefs.getStringList(_chunksStorageKey) ?? [];
      final List<Map<String, dynamic>> chunks = chunksJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
      
      // Identify chunks older than 30 days
      final now = DateTime.now();
      final oldChunks = chunks.where((chunk) {
        final timestamp = DateTime.parse(chunk['timestamp']);
        final age = now.difference(timestamp);
        return age.inDays > 30;
      }).toList();
      
      // Delete old chunks
      for (final chunk in oldChunks) {
        final filePath = chunk['file_path'];
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          developer.log('🗑️ Deleted old chunk: ${file.path}',
            name: 'ChunkReceiverService');
        }
        chunks.remove(chunk);
      }
      
      // Update the registry
      final updatedChunksJson = chunks.map((chunk) => jsonEncode(chunk)).toList();
      await prefs.setStringList(_chunksStorageKey, updatedChunksJson);
    } catch (e) {
      developer.log('❌ Error during maintenance: $e',
        name: 'ChunkReceiverService',
        error: e.toString());
    }
  }
}