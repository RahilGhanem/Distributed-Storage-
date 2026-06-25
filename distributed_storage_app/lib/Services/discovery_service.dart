//services/discovery_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../Services/auth_service.dart';

class DiscoveryService {
  final String baseUrl;
  final String? authToken;
  final Duration timeout;

  DiscoveryService({
    required this.baseUrl, 
    this.authToken,
    this.timeout = const Duration(seconds: 10),  // Default timeout of 10 seconds
  });

  Future<List<DiscoveredDevice>> discoverDevices() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

      // Constructing the proper URL with the API path
      final url = 'http://192.168.97.126:5000/api/devices/discover-devices';
      
      // Add logging
      debugPrint('🔍 Attempting to discover devices at: $url');
      debugPrint('🔑 Using headers: $headers');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> devices = jsonDecode(response.body);
        debugPrint('✅ Successfully discovered ${devices.length} devices');
        
        return devices.map((device) => DiscoveredDevice.fromJson(device)).toList();
      } else {
        final errorMsg = response.body;
        debugPrint('❌ Error response: ${response.statusCode} - $errorMsg');
        throw Exception('Server returned error: ${response.statusCode}, message: $errorMsg');
      }
    } on SocketException catch (e) {
      debugPrint('🌐 Network error: $e');
      throw Exception('Cannot connect to server. Please check your network connection and server status.');
    } on TimeoutException catch (e) {
      debugPrint('⏱️ Connection timeout: $e');
      throw Exception('Connection to server timed out. Server might be down or overloaded.');
    } on FormatException catch (e) {
      debugPrint('📄 Data format error: $e');
      throw Exception('Received invalid data from server. Server might be misconfigured.');
    } catch (e) {
      debugPrint('❓ Discovery error: $e');
      throw Exception('Failed to discover devices: $e');
    }
  }
  
  // Utility method to create a discovery service with auth from the AuthService
  static Future<DiscoveryService> fromAuthService(AuthService authService, String baseUrl) async {
    final token = await authService.getAuthToken();
    return DiscoveryService(
      baseUrl: baseUrl,
      authToken: token,
    );
  }
}

class DiscoveredDevice {
  final String deviceId;
  final String ip;
  final String macAddress;
  final String deviceType;
  final double freeStorage;
  final String status;

  DiscoveredDevice({
    required this.deviceId,
    required this.ip,
    required this.macAddress,
    required this.deviceType,
    required this.freeStorage,
    required this.status,
  });

  // Add getter for storage that returns freeStorage
  // This maintains compatibility with code expecting a 'storage' property
  double get storage => freeStorage;
  
  // Add getter for online status
  bool get online => status == 'connected';

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    // Convert the free_storage to double regardless of its original type
    var storageValue = json['free_storage'];
    double freeStorageValue;

    if (storageValue is int) {
      freeStorageValue = storageValue.toDouble();
    } else if (storageValue is String) {
      freeStorageValue = double.tryParse(storageValue) ?? 0.0;
    } else if (storageValue is double) {
      freeStorageValue = storageValue;
    } else {
      freeStorageValue = 0.0; // Default value if parsing fails
    }

    return DiscoveredDevice(
      deviceId: json['id'].toString(),
      ip: json['ip_address'].toString(),
      macAddress: json['mac_address'].toString(),
      deviceType: json['device_type'].toString(),
      freeStorage: freeStorageValue,
      status: json['status'].toString(),
    );
  }
}