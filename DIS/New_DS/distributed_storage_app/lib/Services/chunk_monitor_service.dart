import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import 'device_service.dart';
import 'chunk_receiver_service.dart';
import 'package:path_provider/path_provider.dart';

class ChunkMonitorService {
  static const String _storageUsageKey = 'storage_usage';
  static Timer? _monitorTimer;
  static Timer? _reportTimer;
  
  // Start periodic monitoring and reporting
  static void startMonitoring() {
    // Cancel any existing timers
    stopMonitoring();
    
    // Check storage usage every hour
    _monitorTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkStorageUsage();
    });
    
    // Report status every 30 minutes
    _reportTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _reportStatus();
    });
    
    // Run initial checks immediately
    _checkStorageUsage();
    _reportStatus();
    
    developer.log('📊 Started chunk monitoring service', 
      name: 'ChunkMonitorService');
  }
  
  // Stop monitoring
  static void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    
    _reportTimer?.cancel();
    _reportTimer = null;
    
    developer.log('🛑 Stopped chunk monitoring service', 
      name: 'ChunkMonitorService');
  }
  
  // Check storage usage and clean up if needed
  static Future<void> _checkStorageUsage() async {
    try {
      // Get storage information
      final chunks = await ChunkReceiverService.getStoredChunks();
      final totalStorageUsed = chunks.fold<int>(
        0, (sum, chunk) => sum + (chunk['size'] as int? ?? 0));
      
      // Save current usage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_storageUsageKey, totalStorageUsed);
      
      // Get available storage
      final dir = await getApplicationDocumentsDirectory();
      final stats = await getStorageStats(dir);
      
      developer.log('📊 Storage stats - Used: ${_formatBytes(totalStorageUsed)}, ' +
        'Available: ${_formatBytes(stats.available)}, ' +
        'Total: ${_formatBytes(stats.total)}',
        name: 'ChunkMonitorService');
      
      // If storage is getting low (less than 20% free), clean up old chunks
      if (stats.available < stats.total * 0.2) {
        developer.log('⚠️ Storage space low, performing maintenance', 
          name: 'ChunkMonitorService');
        await ChunkReceiverService.performMaintenance();
      }
    } catch (e) {
      developer.log('❌ Error checking storage usage: $e', 
        name: 'ChunkMonitorService', 
        error: e.toString());
    }
  }
  
  // Report device status back to the server
  static Future<void> _reportStatus() async {
    try {
      final token = await DeviceService.getAuthToken();
      final device = await DeviceService.getRegisteredDevice();
      
      if (token == null || device == null) {
        developer.log('⚠️ Cannot report status: Not authenticated or device not registered',
          name: 'ChunkMonitorService');
        return;
      }
      
      // Get storage information
      final prefs = await SharedPreferences.getInstance();
      final storageUsed = prefs.getInt(_storageUsageKey) ?? 0;
      
      // Get available storage
      final dir = await getApplicationDocumentsDirectory();
      final stats = await getStorageStats(dir);
      
      // Calculate new free storage value
      final freeStorage = stats.available / 1024; // Convert to KB for server
      
      // Get the number of chunks we're storing
      final chunks = await ChunkReceiverService.getStoredChunks();
      
      // Report to server
      final url = Uri.parse('${DeviceService.getServerUrl()}/api/devices/update-status');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'device_id': device.id,
          'status': 'connected',
          'free_storage': freeStorage,
          'chunks_stored': chunks.length,
          'storage_used': storageUsed
        })
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        developer.log('✅ Reported device status to server',
          name: 'ChunkMonitorService');
      } else {
        developer.log('⚠️ Failed to report status: ${response.statusCode} - ${response.body}',
          name: 'ChunkMonitorService');
      }
    } catch (e) {
      developer.log('❌ Error reporting status: $e',
        name: 'ChunkMonitorService',
        error: e.toString());
    }
  }
  
  // Get storage stats for a directory
  static Future<StorageStats> getStorageStats(Directory directory) async {
    try {
      // This is a simplified approach - for Android/iOS you would use
      // platform-specific methods for more accurate information
      final fileStat = await directory.stat();
      
      // Default values - these would need to be replaced with actual platform-specific code
      // to get real storage information
      const totalStorage = 1024 * 1024 * 1024 * 10; // 10 GB assumed capacity
      
      // Get all files in the app directory recursively
      int usedStorage = 0;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          usedStorage += stat.size;
        }
      }
      
      // Calculate available storage (this is an approximation)
      final availableStorage = totalStorage - usedStorage;
      
      return StorageStats(
        total: totalStorage,
        used: usedStorage,
        available: availableStorage
      );
    } catch (e) {
      developer.log('❌ Error getting storage stats: $e',
        name: 'ChunkMonitorService',
        error: e.toString());
      
      // Return default values on error
      return StorageStats(
        total: 1024 * 1024 * 1024 * 10, // 10 GB
        used: 0,
        available: 1024 * 1024 * 1024 * 5  // 5 GB
      );
    }
  }
  
  // Format bytes into human-readable format
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// Helper class for storage information
class StorageStats {
  final int total;     // Total bytes
  final int used;      // Used bytes
  final int available; // Available bytes
  
  StorageStats({
    required this.total,
    required this.used,
    required this.available
  });
}