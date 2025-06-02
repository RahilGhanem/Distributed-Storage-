import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../Models/user_model.dart';

class AuthService {
  // Base URL of your API server - update this to match your backend
  final String baseUrl = 'http://192.168.97.126:5000'; // Using port 5000 as specified in backend
  
  // User data storage keys
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';
  
  // Get device identifier (Android ID or iOS identifier)
  Future<String> _getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // Android ID
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown'; // iOS identifier
    }
    
    return 'unknown';
  }
  
  // Get current IP address
  Future<String?> _getCurrentIpAddress() async {
    try {
      // Try to get IP from a public service
      final response = await http.get(
        Uri.parse('https://api.ipify.org'),
        headers: {'Accept': 'text/plain'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return response.body.trim();
      }
    } catch (e) {
      print('Error getting IP address: $e');
    }
    
    // Fallback: try to get local network IP
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting local IP: $e');
    }
    
    return null;
  }
  
  // Update device IP address
  Future<void> _updateDeviceIpAddress() async {
    try {
      final token = await getAuthToken();
      if (token == null) return;
      
      final deviceId = await _getDeviceId();
      final currentIp = await _getCurrentIpAddress();
      
      if (currentIp == null) {
        print('Could not determine IP address');
        return;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/devices/reset-device-address'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'device_id': deviceId, // Using device_id instead of mac_address
          'new_ip_address': currentIp,
        }),
      );
      
      if (response.statusCode == 200) {
        print('Device IP address updated successfully');
      } else {
        print('Failed to update device IP: ${response.body}');
      }
    } catch (e) {
      print('Error updating device IP: $e');
    }
  }
  
  // Login method
  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        // Parse response
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Save user data to shared preferences
        await _storeUserData(
          data['user']['id'].toString(),
          data['user']['username'],
          data['token'],
          data['user']['email'] ?? '',
        );
        
        // Update device IP address after successful login
        await _updateDeviceIpAddress();
        
        return true;
      } else {
        print('Login failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Login error: $e');
      throw Exception('Failed to connect to server');
    }
  }
  
  // Check if user is logged in and update IP if needed
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    
    if (token != null) {
      // User is logged in, update IP address
      await _updateDeviceIpAddress();
      return true;
    }
    
    return false;
  }
  
  // Register method
  Future<bool> register(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 201) {
        print('Registration successful');
        return true;
      } else {
        print('Registration failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Registration error: $e');
      throw Exception('Failed to connect to server');
    }
  }
  
  // Logout method
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_emailKey);
  }
  
  // Get auth token
  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
  
  // Get current user
  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    final username = prefs.getString(_usernameKey);
    final token = prefs.getString(_tokenKey);
    final email = prefs.getString(_emailKey);
    
    if (userId != null && username != null && token != null) {
      return User(
        userId: userId,
        username: username,
        authToken: token,
        email: email ?? '',
      );
    }
    
    return null;
  }
  
  // Store user data in shared preferences
  Future<void> _storeUserData(String userId, String username, String token, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_emailKey, email);
  }
}