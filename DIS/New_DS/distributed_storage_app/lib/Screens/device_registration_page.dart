// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:lottie/lottie.dart';
import '../Services/device_service.dart';
import '../Models/device.dart';

class DeviceRegistrationPage extends StatefulWidget {
  final String userId;
  
  const DeviceRegistrationPage({super.key, required this.userId});

  @override
  State<DeviceRegistrationPage> createState() => _DeviceRegistrationPageState();
}

class _DeviceRegistrationPageState extends State<DeviceRegistrationPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _storageController = TextEditingController(text: '5.0');
  bool _isLoading = true;
  bool _isChecking = true;
  String? _ipAddress;
  String? _macAddress = 'Detecting...';
  String? _deviceType = 'other';
  String? _serverResponse;
  bool _registrationSuccess = false;
  final NetworkInfo _networkInfo = NetworkInfo();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  Device? _existingDevice;
  
  // Animation controller for success/error animations
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _checkExistingDevice();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  Future<void> _checkExistingDevice() async {
    setState(() => _isChecking = true);
    
    try {
      // First try to get existing device registration
      final device = await DeviceService.getRegisteredDevice();
      
      if (device != null) {
        setState(() {
          _existingDevice = device;
          _isChecking = false;
        });
        
        // Instead of navigating to device info page, update UI to show device is already registered
        setState(() {
          _nameController.text = device.name;
          _ipAddress = device.ipAddress;
          _macAddress = device.macAddress;
          _deviceType = device.deviceType;
          _storageController.text = device.storageCapacity.toString();
          _serverResponse = 'Device already registered with ID: ${device.id}';
          _registrationSuccess = true;
        });
      } else {
        // No existing device, get device info for new registration
        await _getDeviceInfo();
        setState(() => _isChecking = false);
      }
    } catch (e) {
      developer.log('Error checking for existing device: $e', name: 'DeviceRegistration');
      // If there's an error, we'll still let the user try to register
      await _getDeviceInfo();
      setState(() => _isChecking = false);
    }
  }

  Future<void> _getDeviceInfo() async {
    try {
      setState(() => _macAddress = 'Detecting...');
      
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final String? androidId = androidInfo.id;
        developer.log('Android ID detected: $androidId', name: 'DeviceInfo');
        
        String? wifiIP = await _networkInfo.getWifiIP();
        String? wifiName = await _networkInfo.getWifiName();
        String? wifiBSSID = await _networkInfo.getWifiBSSID();
        
        developer.log('WiFi Info - Name: $wifiName, BSSID: $wifiBSSID, IP: $wifiIP', name: 'NetworkInfo');
        
        setState(() {
          _macAddress = androidId != null 
              ? '${androidId.substring(0, 2)}:${androidId.substring(2, 4)}:${androidId.substring(4, 6)}:${androidId.substring(6, 8)}:${androidId.substring(8, 10)}:${androidId.substring(10, 12)}'
              : 'XX:XX:XX:XX:XX:XX';
          _ipAddress = wifiIP ?? '192.168.1.100';
          _deviceType = 'android';
          _isLoading = false;
        });
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        final String? idForVendor = iosInfo.identifierForVendor;
        
        String? wifiIP = await _networkInfo.getWifiIP();
        
        developer.log('iOS identifierForVendor: $idForVendor, IP: $wifiIP', name: 'DeviceInfo');
        
        setState(() {
          _macAddress = idForVendor != null
              ? idForVendor.replaceAllMapped(RegExp(r'(.{2})'), (match) => '${match.group(0)}:').substring(0, 17)
              : 'XX:XX:XX:XX:XX:XX';
          _ipAddress = wifiIP ?? '192.168.1.100';
          _deviceType = 'macos';  // Using "macos" as per schema CHECK constraint
          _isLoading = false;
        });
      } else {
        setState(() {
          _macAddress = 'XX:XX:XX:XX:XX:XX';
          _ipAddress = '192.168.1.100';
          _deviceType = 'other';
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error getting device info: $e', name: 'DeviceInfo', error: e.toString());
      setState(() {
        _macAddress = 'XX:XX:XX:XX:XX:XX';
        _ipAddress = Platform.isAndroid ? '10.0.2.2' : '192.168.1.100';
        _deviceType = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'macos' : 'other');
        _isLoading = false;
      });
    }
  }

  Future<void> _testServerConnection(String serverIp) async {
    try {
      final url = 'http://$serverIp:5000/api/health';  // Using port 5000 as specified in app.js
      developer.log('Testing connection to: $url', name: 'ServerTest');
      
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return; // Connection successful
      } else {
        throw Exception('Server responded with status code: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Server connection test failed: $e', name: 'ServerTest');
      throw e; // Re-throw to handle in calling function
    }
  }

  Future<void> _registerDevice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _serverResponse = null;
    });
    
    final deviceMac = _macAddress ?? 'XX:XX:XX:XX:XX:XX';
    String serverIp = '192.168.97.126'; // Default IP
    
    final String? confirmedIp = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Server Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please confirm or edit the server IP address:'),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: serverIp,
              decoration: const InputDecoration(
                labelText: 'Server IP',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
              onChanged: (value) {
                serverIp = value;
              },
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () async {
                // Show a testing indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Testing connection...'),
                    duration: Duration(seconds: 2),
                  ),
                );
                
                try {
                  await _testServerConnection(serverIp);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connection successful! ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connection failed! Check server IP and make sure the server is running.'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test Connection'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, serverIp),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    if (confirmedIp == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      // Update server URL in DeviceService
      DeviceService.updateServerUrl(confirmedIp);
      
      // Register device using our DeviceService
      final device = await DeviceService.registerDevice(
        name: _nameController.text,
        ipAddress: _ipAddress ?? '192.168.1.100',
        macAddress: deviceMac,
        deviceType: _deviceType ?? 'other',
        storageCapacity: double.parse(_storageController.text),
      );
      
      setState(() {
        _serverResponse = 'Success! Device ID: ${device.id}';
        _registrationSuccess = true;
        _existingDevice = device;
      });
      
      _animationController.forward();
      
      // Show success message and stay on this page
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device registered successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
    } on SocketException catch (e) {
      setState(() {
        _serverResponse = 'Network error: Check server connection\n${e.message}\nVerify your computer\'s IP is $confirmedIp and check your firewall settings.\n\nTry these steps:\n1. Make sure the server is running\n2. Make sure your phone and computer are on the same network\n3. Check if any firewall is blocking the connection';
      });
    } on TimeoutException {
      setState(() {
        _serverResponse = 'Timeout: Server not responding\nTry these troubleshooting steps:\n1. Ensure your server is running\n2. Check for firewall blocking port 5000\n3. Make sure your phone and computer are on the same network\n4. Try direct IP: $confirmedIp';
      });
    } on FormatException catch (e) {
      setState(() {
        _serverResponse = 'Error: Invalid response format from server';
      });
    } catch (e) {
      setState(() {
        _serverResponse = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Method to unregister device
  Future<void> _unregisterDevice() async {
    if (_existingDevice == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unregister Device'),
        content: const Text('Are you sure you want to unregister this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Unregister'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      await DeviceService.clearDeviceRegistration();
      setState(() {
        _existingDevice = null;
        _serverResponse = 'Device unregistered successfully.';
        _registrationSuccess = true;
        _isLoading = false;
      });
      
      // Clear form fields
      _nameController.clear();
      _storageController.text = '5.0';
      
      // Get new device info
      await _getDeviceInfo();
      
    } catch (e) {
      setState(() {
        _serverResponse = 'Error unregistering device: ${e.toString()}';
        _registrationSuccess = false;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _storageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isChecking) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Device Registration'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Register Device'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getDeviceInfo,
            tooltip: 'Refresh Device Info',
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surface.withOpacity(0.8),
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner Section
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.device_hub,
                          size: 50,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _existingDevice != null ? 'Manage Your Device' : 'Connect Your Device',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _existingDevice != null 
                            ? 'Your device is already registered'
                            : 'Register your device to the network',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Device Information Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Device Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoTile(
                            icon: Icons.device_hub,
                            title: 'MAC Address',
                            value: _macAddress ?? 'Detecting...',
                            theme: theme,
                          ),
                          const Divider(),
                          _buildInfoTile(
                            icon: Icons.network_wifi,
                            title: 'IP Address',
                            value: _ipAddress ?? 'Detecting...',
                            theme: theme,
                          ),
                          const Divider(),
                          _buildInfoTile(
                            icon: Icons.phone_android,
                            title: 'Device Type',
                            value: _deviceType == 'android' ? 'Android' : 
                                   _deviceType == 'macos' ? 'iOS/macOS' : 'Other',
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Device Details Form
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.edit, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Device Details',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Device Name',
                              prefixIcon: const Icon(Icons.devices_other),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              hintText: 'e.g. My Android Phone',
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a device name';
                              }
                              if (value.length < 3) {
                                return 'Name too short (min 3 chars)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _storageController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Storage Allocation (GB)',
                              prefixIcon: const Icon(Icons.storage),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixText: 'GB',
                              hintText: 'e.g. 5.0',
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter storage amount';
                              }
                              final num = double.tryParse(value);
                              if (num == null || num <= 0) {
                                return 'Enter a valid positive number';
                              }
                              if (num > 1000) {
                                return 'Maximum 1000 GB allowed';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Response Message
                  if (_serverResponse != null)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _registrationSuccess 
                            ? Colors.green.shade50 
                            : Colors.red.shade50,
                        border: Border.all(
                          color: _registrationSuccess 
                              ? Colors.green 
                              : Colors.red,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (_registrationSuccess ? Colors.green : Colors.red).withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _registrationSuccess ? Icons.check_circle : Icons.error,
                                color: _registrationSuccess ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _registrationSuccess ? 'Success' : 'Error',
                                style: TextStyle(
                                  color: _registrationSuccess ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _serverResponse!,
                            style: TextStyle(
                              color: _registrationSuccess ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                            if (_registrationSuccess)
                            Center(
                              child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 100,
                              ),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),

                  // Action Buttons
                  if (_existingDevice != null)
                    ElevatedButton(
                      onPressed: _isLoading ? null : _unregisterDevice,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_forever, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            'UNREGISTER DEVICE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: _isLoading ? null : _registerDevice,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'REGISTERING...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimary.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.app_registration,
                                  color: theme.colorScheme.onPrimary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'REGISTER DEVICE',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon, 
    required String title, 
    required String value, 
    required ThemeData theme
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.content_copy),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title copied to clipboard'),
              behavior: SnackBarBehavior.floating,
              width: 250,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        },
      ),
    );
  }
}