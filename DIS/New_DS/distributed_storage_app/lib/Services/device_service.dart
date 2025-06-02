// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../Models/device.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:developer' as developer;

// class DeviceService {
//   static String _baseUrl = 'http://192.168.87.10:5000'; // Default server IP and port
//   static const String _deviceStorageKey = 'user_device_info';
//   static const String _tokenStorageKey = 'auth_token';
//   static const String _serverUrlKey = 'server_url';
 
//   // Initialize service and try to load saved server URL
//   static Future<void> init() async {
//     final prefs = await SharedPreferences.getInstance();
//     final savedUrl = prefs.getString(_serverUrlKey);
//     if (savedUrl != null && savedUrl.isNotEmpty) {
//       _baseUrl = savedUrl;
//     }
//   }

//   // Helper method to safely parse various types to double - moved to DeviceService
//   static double _parseToDouble(dynamic value) {
//     if (value == null) return 0.0;
//     if (value is double) return value;
//     if (value is int) return value.toDouble();
//     if (value is String) {
//       try {
//         return double.parse(value);
//       } catch (_) {
//         return 0.0;
//       }
//     }
//     return 0.0;
//   }

//   // Register a new device
//   static Future<Device> registerDevice({
//     required String name,
//     required String ipAddress,
//     required String macAddress,
//     required String deviceType,
//     required double storageCapacity,
//   }) async {
//     final token = await getAuthToken();
//     if (token == null) {
//       throw Exception('Not authenticated. Please login first.');
//     }

//     // Convert GB to bytes for backend
//     final storageCapacityBytes = (storageCapacity * 1000 * 1000 * 1000).toInt();

//     developer.log('Registering device with: $ipAddress, $macAddress, $deviceType, $storageCapacityBytes bytes', 
//       name: 'DeviceService');
      
//     final url = Uri.parse('$_baseUrl/api/devices/register-device');
//     final response = await http.post(
//       url,
//       headers: {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $token'
//       },
//       body: jsonEncode({
//         'ip_address': ipAddress,
//         'mac_address': macAddress,
//         'device_type': deviceType,
//         'storage_capacity': storageCapacityBytes
//       }),
//     );

//     if (response.statusCode == 201) {
//       final data = jsonDecode(response.body);
      
//       developer.log('Device registered successfully: ${response.body}', name: 'DeviceService');
      
//       // Fix: Properly handle numeric values coming from the server
//       final device = Device(
//         id: data['id'].toString(),
//         name: name,
//         ipAddress: data['ip_address'],
//         macAddress: data['mac_address'],
//         deviceType: data['device_type'],
//         // Use our internal helper method to safely parse numeric values
//         storageCapacity: _parseToDouble(data['storage_capacity']),
//         freeStorage: _parseToDouble(data['free_storage']),
//         status: data['status'],
//         lastSeen: DateTime.parse(data['last_seen']),
//         userId: data['user_id'] != null ? int.parse(data['user_id'].toString()) : null,
//       );
      
//       // Save the device info to shared preferences
//       await saveDeviceLocally(device);
      
//       return device;
//     } else {
//       developer.log('Failed to register device: ${response.statusCode} - ${response.body}', 
//         name: 'DeviceService', error: response.body);
//       throw Exception('Failed to register device: ${response.body}');
//     }
//   }

//   // Reset device's IP address when it connects from a new location
//   static Future<Device> resetDeviceAddress({
//     required String macAddress,
//     required String newIpAddress,
//   }) async {
//     final token = await getAuthToken();
//     if (token == null) {
//       throw Exception('Not authenticated. Please login first.');
//     }

//     developer.log('Resetting device address: $macAddress to $newIpAddress', name: 'DeviceService');
    
//     final url = Uri.parse('$_baseUrl/api/devices/reset-device-address');
//     final response = await http.post(
//       url,
//       headers: {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $token'
//       },
//       body: jsonEncode({
//         'mac_address': macAddress,
//         'new_ip_address': newIpAddress
//       }),
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
      
//       developer.log('Device address reset successfully: ${response.body}', name: 'DeviceService');
      
//       // Get saved device to retrieve name
//       final savedDevice = await getRegisteredDevice();
      
//       // Fix: Properly handle numeric values coming from the server
//       final updatedDevice = Device(
//         id: data['id'].toString(),
//         name: savedDevice?.name ?? "Device", 
//         ipAddress: data['ip_address'],
//         macAddress: data['mac_address'],
//         deviceType: data['device_type'],
//         // Use our internal helper method to safely parse numeric values
//         storageCapacity: _parseToDouble(data['storage_capacity']),
//         freeStorage: _parseToDouble(data['free_storage']),
//         status: data['status'],
//         lastSeen: DateTime.parse(data['last_seen']),
//         userId: data['user_id'] != null ? int.parse(data['user_id'].toString()) : null,
//       );
      
//       // Update the device info in shared preferences
//       await saveDeviceLocally(updatedDevice);
      
//       return updatedDevice;
//     } else {
//       developer.log('Failed to reset device address: ${response.statusCode} - ${response.body}', 
//         name: 'DeviceService', error: response.body);
//       throw Exception('Failed to reset device address: ${response.body}');
//     }
//   }
  
//   // Discover connected devices
//   static Future<List<Device>> getConnectedDevices() async {
//     final token = await getAuthToken();
//     if (token == null) {
//       throw Exception('Not authenticated. Please login first.');
//     }

//     final url = Uri.parse('$_baseUrl/api/devices/discover');
//     final response = await http.get(
//       url,
//       headers: {
//         'Authorization': 'Bearer $token'
//       },
//     );

//     if (response.statusCode == 200) {
//       final List<dynamic> data = jsonDecode(response.body);
//       return data.map((deviceData) => Device(
//         id: deviceData['id'].toString(),
//         name: deviceData['name'] ?? "Device ${deviceData['id']}", 
//         ipAddress: deviceData['ip_address'],
//         macAddress: deviceData['mac_address'],
//         deviceType: deviceData['device_type'],
//         // Use the static helper method to safely parse numeric values
//         storageCapacity: DeviceService._parseToDouble(deviceData['storage_capacity']),
//         freeStorage: DeviceService._parseToDouble(deviceData['free_storage']),
//         status: deviceData['status'],
//         lastSeen: DateTime.parse(deviceData['last_seen']),
//         userId: deviceData['user_id'] != null ? int.parse(deviceData['user_id'].toString()) : null,
//       )).toList();
//     } else {
//       throw Exception('Failed to get connected devices: ${response.body}');
//     }
//   }
  
//   // Update server URL
//   static Future<void> updateServerUrl(String serverIp, [String? port]) async {
//     final updatedUrl = 'http://$serverIp:${port ?? '5000'}';
//     _baseUrl = updatedUrl;
    
//     // Save to preferences
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_serverUrlKey, updatedUrl);
    
//     developer.log('Server URL updated to: $_baseUrl', name: 'DeviceService');
//   }
  
//   // Get current server URL
//   static String getServerUrl() {
//     return _baseUrl;
//   }
  
//   // Save device info to shared preferences
//   static Future<void> saveDeviceLocally(Device device) async {
//     final prefs = await SharedPreferences.getInstance();
//     final deviceJson = jsonEncode(device.toJson());
//     await prefs.setString(_deviceStorageKey, deviceJson);
//     developer.log('Device saved locally: $deviceJson', name: 'DeviceService');
//   }

//   // Save authentication token
//   static Future<void> saveAuthToken(String token) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_tokenStorageKey, token);
//     developer.log('Auth token saved', name: 'DeviceService');
//   }

//   // Get saved authentication token
//   static Future<String?> getAuthToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString(_tokenStorageKey);
//   }

//   // Check if user has already registered a device
//   static Future<Device?> getRegisteredDevice() async {
//     final prefs = await SharedPreferences.getInstance();
//     final deviceJson = prefs.getString(_deviceStorageKey);
    
//     if (deviceJson != null) {
//       try {
//         return Device.fromJson(jsonDecode(deviceJson));
//       } catch (e) {
//         developer.log('Error parsing device data: $e', name: 'DeviceService', error: e.toString());
//         return null;
//       }
//     }
//     return null;
//   }

//   // Clear device registration (for testing or logout)
//   static Future<void> clearDeviceRegistration() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_deviceStorageKey);
//     developer.log('Device registration cleared', name: 'DeviceService');
//   }

//   // Clear auth token (for logout)
//   static Future<void> clearAuthToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_tokenStorageKey);
//     developer.log('Auth token cleared', name: 'DeviceService');
//   }
  
//   // Test server connection
//   static Future<bool> testServerConnection(String serverIp, [String? port]) async {
//     try {
//       final url = Uri.parse('http://$serverIp:${port ?? '5000'}/api/health');
//       developer.log('Testing connection to: $url', name: 'DeviceService');
      
//       final response = await http.get(url)
//           .timeout(const Duration(seconds: 5));
      
//       return response.statusCode == 200;
//     } catch (e) {
//       developer.log('Server connection test failed: $e', name: 'DeviceService', error: e.toString());
//       return false;
//     }
//   }
// }

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/device.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class DeviceService {
  static String _baseUrl = 'http://192.168.97.126:5000'; // Default server IP and port
  static const String _deviceStorageKey = 'user_device_info';
  static const String _tokenStorageKey = 'auth_token';
  static const String _serverUrlKey = 'server_url';
 
  // Initialize service and try to load saved server URL
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_serverUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    }
  }

  // Helper method to safely parse various types to double - moved to DeviceService
  static double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }

  // Register a new device
  static Future<Device> registerDevice({
    required String name,
    required String ipAddress,
    required String macAddress,
    required String deviceType,
    required double storageCapacity,
  }) async {
    final token = await getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated. Please login first.');
    }

    // Convert GB to bytes for backend
    final storageCapacityBytes = (storageCapacity * 1000 * 1000 * 1000).toInt();

    developer.log('Registering device with: $ipAddress, $macAddress, $deviceType, $storageCapacityBytes bytes', 
      name: 'DeviceService');
      
    final url = Uri.parse('$_baseUrl/api/devices/register-device');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({
        'ip_address': ipAddress,
        'mac_address': macAddress,
        'device_type': deviceType,
        'storage_capacity': storageCapacityBytes
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      
      developer.log('Device registered successfully: ${response.body}', name: 'DeviceService');
      
      // Fix: Properly handle numeric values coming from the server
      final device = Device(
        id: data['id'].toString(),
        name: name,
        ipAddress: data['ip_address'],
        macAddress: data['mac_address'],
        deviceType: data['device_type'],
        // Use our internal helper method to safely parse numeric values
        storageCapacity: _parseToDouble(data['storage_capacity']),
        freeStorage: _parseToDouble(data['free_storage']),
        status: data['status'],
        lastSeen: DateTime.parse(data['last_seen']),
        userId: data['user_id'] != null ? int.parse(data['user_id'].toString()) : null,
      );
      
      // Save the device info to shared preferences
      await saveDeviceLocally(device);
      
      return device;
    } else {
      developer.log('Failed to register device: ${response.statusCode} - ${response.body}', 
        name: 'DeviceService', error: response.body);
      throw Exception('Failed to register device: ${response.body}');
    }
  }

  // Reset device's IP address when it connects from a new location
  static Future<Device> resetDeviceAddress({
    required String macAddress,
    required String newIpAddress,
  }) async {
    final token = await getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated. Please login first.');
    }

    developer.log('Resetting device address: $macAddress to $newIpAddress', name: 'DeviceService');
    
    final url = Uri.parse('$_baseUrl/api/devices/reset-device-address');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({
        'mac_address': macAddress,
        'new_ip_address': newIpAddress
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      developer.log('Device address reset successfully: ${response.body}', name: 'DeviceService');
      
      // Get saved device to retrieve name
      final savedDevice = await getRegisteredDevice();
      
      // Fix: Properly handle numeric values coming from the server
      final updatedDevice = Device(
        id: data['id'].toString(),
        name: savedDevice?.name ?? "Device", 
        ipAddress: data['ip_address'],
        macAddress: data['mac_address'],
        deviceType: data['device_type'],
        // Use our internal helper method to safely parse numeric values
        storageCapacity: _parseToDouble(data['storage_capacity']),
        freeStorage: _parseToDouble(data['free_storage']),
        status: data['status'],
        lastSeen: DateTime.parse(data['last_seen']),
        userId: data['user_id'] != null ? int.parse(data['user_id'].toString()) : null,
      );
      
      // Update the device info in shared preferences
      await saveDeviceLocally(updatedDevice);
      
      return updatedDevice;
    } else {
      developer.log('Failed to reset device address: ${response.statusCode} - ${response.body}', 
        name: 'DeviceService', error: response.body);
      throw Exception('Failed to reset device address: ${response.body}');
    }
  }
  
  // Discover connected devices
  // static Future<List<Device>> getConnectedDevices() async {
  //   final token = await getAuthToken();
  //   if (token == null) {
  //     throw Exception('Not authenticated. Please login first.');
  //   }

  //   // Fixed the typo in the endpoint URL
  //   final url = Uri.parse('$_baseUrl/api/devices/discover-devices');
    
  //   // Add debug logging
  //   developer.log('Making API request to: ${url.toString()}', name: 'DeviceService');
    
  //   try {
  //     final response = await http.get(
  //       url,
  //       headers: {
  //         'Authorization': 'Bearer $token'
  //       },
  //     );

  //     // Add debug logging
  //     developer.log('Response status code: ${response.statusCode}', name: 'DeviceService');
  //     developer.log('Response body: ${response.body}', name: 'DeviceService');

  //     if (response.statusCode == 200) {
  //       final List<dynamic> data = jsonDecode(response.body);
  //       return data.map((deviceData) => Device(
  //         id: deviceData['id'].toString(),
  //         name: deviceData['name'] ?? "Device ${deviceData['id']}", 
  //         ipAddress: deviceData['ip_address'],
  //         macAddress: deviceData['mac_address'],
  //         deviceType: deviceData['device_type'],
  //         // Use the static helper method to safely parse numeric values
  //         storageCapacity: DeviceService._parseToDouble(deviceData['storage_capacity']),
  //         freeStorage: DeviceService._parseToDouble(deviceData['free_storage']),
  //         status: deviceData['status'],
  //         lastSeen: DateTime.parse(deviceData['last_seen']),
  //         userId: deviceData['user_id'] != null ? int.parse(deviceData['user_id'].toString()) : null,
  //       )).toList();
  //     } else {
  //       throw Exception('Failed to get connected devices: ${response.body}');
  //     }
  //   } catch (error) {
  //     developer.log('Error fetching connected devices: $error', name: 'DeviceService', error: error.toString());
  //     rethrow; // Re-throw the error to be handled by the caller
  //   }
  // }
  static Future<List<Device>> getConnectedDevices() async {
  final token = await getAuthToken();
  if (token == null) {
    throw Exception('Not authenticated');
  }

  final url = Uri.parse('$_baseUrl/api/devices/discover-devices');
  final response = await http.get(
    url,
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    try {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((deviceData) => Device.fromJson(deviceData))
          .where((device) => device.status.toLowerCase() == 'connected')
          .toList();
    } catch (e) {
      throw Exception('Failed to parse devices: $e');
    }
  } else {
    throw Exception('Failed to get devices: ${response.statusCode}');
  }
}
  
  // Update server URL
  static Future<void> updateServerUrl(String serverIp, [String? port]) async {
    final updatedUrl = 'http://$serverIp:${port ?? '5000'}';
    _baseUrl = updatedUrl;
    
    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, updatedUrl);
    
    developer.log('Server URL updated to: $_baseUrl', name: 'DeviceService');
  }
  
  // Get current server URL
  static String getServerUrl() {
    return _baseUrl;
  }
  
  // Save device info to shared preferences
  static Future<void> saveDeviceLocally(Device device) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceJson = jsonEncode(device.toJson());
    await prefs.setString(_deviceStorageKey, deviceJson);
    developer.log('Device saved locally: $deviceJson', name: 'DeviceService');
  }

  // Save authentication token
  static Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, token);
    developer.log('Auth token saved', name: 'DeviceService');
  }

  // Get saved authentication token
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenStorageKey);
  }

  // Check if user has already registered a device
  static Future<Device?> getRegisteredDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceJson = prefs.getString(_deviceStorageKey);
    
    if (deviceJson != null) {
      try {
        return Device.fromJson(jsonDecode(deviceJson));
      } catch (e) {
        developer.log('Error parsing device data: $e', name: 'DeviceService', error: e.toString());
        return null;
      }
    }
    return null;
  }

  // Clear device registration (for testing or logout)
  static Future<void> clearDeviceRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceStorageKey);
    developer.log('Device registration cleared', name: 'DeviceService');
  }

  // Clear auth token (for logout)
  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenStorageKey);
    developer.log('Auth token cleared', name: 'DeviceService');
  }
  
  // Test server connection
  static Future<bool> testServerConnection(String serverIp, [String? port]) async {
    try {
      final url = Uri.parse('http://$serverIp:${port ?? '5000'}/api/health');
      developer.log('Testing connection to: $url', name: 'DeviceService');
      
      final response = await http.get(url)
          .timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      developer.log('Server connection test failed: $e', name: 'DeviceService', error: e.toString());
      return false;
    }
  }
}