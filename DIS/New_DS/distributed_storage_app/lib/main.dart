 import 'package:distributed_storage_app/Screens/chunks_debug_screen.dart';
import 'package:flutter/material.dart';
 import 'package:shelf/shelf.dart';
 import 'package:shelf/shelf_io.dart' as shelf_io;
 import 'Screens/splash_screen.dart';
 import 'Screens/login_page.dart';
 import 'Screens/home_page.dart';
 import 'Screens/file_upload.dart';
 import 'Screens/file_retrieval.dart';
 import 'Screens/peer_management_page.dart';
 import 'Screens/setting_page.dart';
 import 'Screens/device_registration_page.dart';
 import 'Screens/register_page.dart';
// import 'dart:io';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
  
//   // Start the HTTP server to receive chunks
//   await _startChunkReceiverServer();
//   runApp(const DistributedStorageApp());
// }

// Future<void> _startChunkReceiverServer() async {
//   final handler = const Pipeline().addMiddleware(logRequests()).addHandler(_handleRequest);
  
//   try {
//     final server = await shelf_io.serve(
//       handler, 
//       InternetAddress.anyIPv4, 
//       8080, // Port for chunk receiving
//     );
    
//     print('Chunk receiver server running on ${server.address}:${server.port}');
//   } catch (e) {
//     print('Failed to start chunk receiver server: $e');
//     // Don't terminate the app - just log the error
//   }
// }

// Future<Response> _handleRequest(Request request) async {
//   if (request.method == 'POST' && request.url.path == 'store-chunk') {
//     // Handle chunk storage
//     final chunkId = request.headers['chunkId'];
//     final bytes = await request.read().expand((x) => x).toList();
    
//     print('Received chunk $chunkId (${bytes.length} bytes)');
    
//     // Here you would actually store the chunk to disk
//     // For now we'll just acknowledge receipt
//     return Response.ok('Chunk $chunkId stored successfully');
//   }
  
//   return Response.notFound('Not found');
// }

// class DistributedStorageApp extends StatelessWidget {
//   const DistributedStorageApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Distributed Storage',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         brightness: Brightness.light,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       darkTheme: ThemeData(
//         primarySwatch: Colors.blue,
//         brightness: Brightness.dark,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       themeMode: ThemeMode.system,
//       initialRoute: '/',
//       routes: {
//         '/': (context) => const SplashScreen(),
//         '/login': (context) => const LoginPage(),
//         '/home': (context) => const HomePage(),
//         '/file_upload': (context) => const FileUploadPage(),
//         '/file_retrieval': (context) => const FileRetrievalPage(),
//         '/register': (context) => const RegisterPage(),
//         '/peer_management': (context) => const PeerManagementPage(),
//         '/settings': (context) => const SettingsPage(),
//         '/device_registration': (context) => DeviceRegistrationPage(
//           userId: '', // This will be populated dynamically from auth service
//         ),
//       },
//     );
//   }
// }




import 'Services/chunk_receiver_service.dart'; // New import
import 'dart:io';
import 'dart:convert';
import 'Services/chunk_monitor_service.dart';

void main() async {
   WidgetsFlutterBinding.ensureInitialized();
   await printNetworkInfo();
  
  // Start the HTTP server to receive chunks
  await _startChunkReceiverServer();
  
  // Start the TCP server for retrieving chunks
  await ChunkReceiverService.startChunkTransferServer();
  
  // Start the chunk monitoring service
  ChunkMonitorService.startMonitoring();
  
  runApp(const DistributedStorageApp());
}

Future<void> _startChunkReceiverServer() async {
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(_handleRequest);
  try {
    final server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      8080, // Port for chunk receiving
    );
    print('Chunk receiver server running on ${server.address}:${server.port}');
  } catch (e) {
    print('Failed to start chunk receiver server: $e');
    // Don't terminate the app - just log the error
  }
}

Future<void> printNetworkInfo() async {
  try {
    final interfaces = await NetworkInterface.list();
    for (var interface in interfaces) {
      print('Interface: ${interface.name}');
      for (var addr in interface.addresses) {
        print('  ${addr.address} (${addr.type.name})');
      }
    }
  } catch (e) {
    print('Cannot get network interfaces: $e');
  }
}
Future<Response> _handleRequest(Request request) async {
  print('⚠️ DEBUG - Received request: ${request.method} ${request.url}');
  print('Path: "${request.url.path}"');
  print('Path segments: ${request.url.pathSegments}');
  print('Received request: ${request.method} ${request.url.path}');
  
  // Use exact path comparison with leading slash
  if (request.method == 'POST' && 
    (request.url.path == 'receive-chunk' || 
     request.url.path == '/receive-chunk' ||
     request.url.pathSegments.contains('receive-chunk'))) {
    try {
      // Read the request body
      final bytes = await request.read().expand((x) => x).toList();
      final bodyString = utf8.decode(bytes);
      final Map<String, dynamic> data = jsonDecode(bodyString);
      
      // Extract chunk data and metadata
      final String chunkData = data['chunk_data'];
      final Map<String, dynamic> metadata = data['metadata'] ?? {};
      
      final fileId = metadata['file_id'];
      final chunkOrder = metadata['chunk_order'];
      final chunkHash = metadata['chunk_hash'];
      final encryptionAlgorithm = metadata['encryption_algorithm'];
      final encryptedKey = metadata['encrypted_key'];
      final iv = metadata['iv'];
      
      print('📦 Received chunk: fileId=$fileId, order=$chunkOrder, size=${chunkData.length}');
      
      // Store the chunk
      await ChunkReceiverService.storeChunk(
        fileId: fileId, 
        chunkOrder: chunkOrder, 
        chunkData: base64.decode(chunkData),
        chunkHash: chunkHash,
        encryptionAlgorithm: encryptionAlgorithm,
        encryptedKey: encryptedKey,
        iv: iv
      );
      
      return Response.ok(jsonEncode({
        'status': 'success',
        'message': 'Chunk received and stored',
        'fileId': fileId,
        'chunkOrder': chunkOrder
      }));
    } catch (e) {
      print('Error processing chunk: $e');
      return Response.internalServerError(body: jsonEncode({
        'error': 'Failed to process chunk',
        'details': e.toString()
      }));
    }
  } else if (request.method == 'GET' && request.url.path == 'retrieve-chunk') {
    // Handle chunk retrieval requests from the coordinator
    try {
      final fileId = request.url.queryParameters['fileId'];
      final chunkOrder = int.parse(request.url.queryParameters['chunkOrder'] ?? '0');
      
      final chunk = await ChunkReceiverService.retrieveChunk(fileId, chunkOrder);
      if (chunk == null) {
        return Response.notFound('Chunk not found');
      }
      
      return Response.ok(chunk, headers: {'content-type': 'application/octet-stream'});
    } catch (e) {
      print('Error retrieving chunk: $e');
      return Response.internalServerError(body: 'Error retrieving chunk: $e');
    }
  }
  print('No handler matched for: ${request.method} ${request.url.path}');
  return Response.notFound('Not found');
}

class DistributedStorageApp extends StatelessWidget {
  const DistributedStorageApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Distributed Storage',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/file_upload': (context) => const FileUploadPage(),
        '/file_retrieval': (context) => const FileRetrievalPage(),
        '/peer_management': (context) => const PeerManagementPage(),
        '/settings': (context) => const SettingsPage(),
        '/device_registration': (context) => const DeviceRegistrationPage( userId: '',),
        '/chunks-debug': (context) => const ChunksDebugScreen(),
      },
      initialRoute: '/',
    );
  }
}