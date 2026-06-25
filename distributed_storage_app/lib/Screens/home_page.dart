// ignore_for_file: unused_local_variable, unused_field

import 'package:flutter/material.dart';
import '../Services/discovery_service.dart';
import '../Services/auth_service.dart';
import '../Models/user_model.dart';
import '../Models/files.dart';
import '../Services/file_service.dart';
import '../Services/file_retrieval_service.dart';
import 'dart:async'; // Import this for Timer

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  DiscoveryService? _discoveryService;
  
  // Server configuration
  final String _serverUrl = 'http://192.168.97.126:5000'; // Match your backend port
  
  List<DiscoveredDevice> _allPeers = []; // Store all peers
  List<DiscoveredDevice> _onlinePeers = []; // Store only online peers
  List<FileInfo> _userFiles = []; // Store user's files
  bool _isLoading = true;
  bool _isLoadingFiles = true;
  bool _isError = false;
  bool _isFilesError = false;
  String _errorMessage = '';
  String _filesErrorMessage = '';
  Timer? _discoveryTimer; // Timer for periodic discovery
  DateTime _lastRefreshTime = DateTime.now();
  User? _currentUser;
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _loadUserData();
    // Initialize discovery service with auth token after user is loaded
    _setupDiscoveryService();
    
    // Load user files
    _loadUserFiles();
    
    // Set up periodic timer to refresh peers every 30 seconds
    _discoveryTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadPeers();
    });
  }

  void _setupDiscoveryService() {
    _discoveryService = DiscoveryService(
      baseUrl: _serverUrl, 
      authToken: _authToken
    );
    _loadPeers();
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed
    _discoveryTimer?.cancel();
    super.dispose();
  }

  // Load user data
  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        final token = await _authService.getAuthToken();
        
        setState(() {
          _currentUser = user;
          _authToken = token;
        });
        debugPrint('👤 Loaded user: ${user.username}');
      } else {
        // If no user data, redirect to login
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  // Method to load user's files
  Future<void> _loadUserFiles() async {
    setState(() {
      _isLoadingFiles = true;
      _isFilesError = false;
      _filesErrorMessage = '';
    });

    try {
      // Get files from FileService
      final files = await FileService.getUserFiles();
      
      // Check file availability if needed
      List<FileInfo> filesWithAvailability = [];
      for (var file in files) {
        try {
          final bool isAvailable = await FileRetrievalService.isFileAvailable(file);
          // Create a new FileInfo with availability information
          filesWithAvailability.add(file);
        } catch (e) {
          // If there's an error, assume the file is not available
          filesWithAvailability.add(file);
          debugPrint('Error checking file availability: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _userFiles = filesWithAvailability;
          _isLoadingFiles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFiles = false;
          _isFilesError = true;
          _filesErrorMessage = e.toString();
        });
      }
      debugPrint('❌ Error loading files: $e');
    }
  }

  // Method to force an immediate refresh of peers
  void _refreshPeers() {
    setState(() {
      _isLoading = true;
      _isError = false;
      _lastRefreshTime = DateTime.now();
    });
    _loadPeers();
    _loadUserFiles(); // Also refresh files
  }

  Future<void> _loadPeers() async {
    if (_discoveryService == null) {
      debugPrint('⚠️ Discovery service not initialized yet');
      return;
    }
    
    try {
      final allDevices = await _discoveryService!.discoverDevices();
      
      if (mounted) { // Check if widget is still mounted before setState
        setState(() {
          // Store all devices
          _allPeers = allDevices;
          
          // Filter to keep only online devices
          _onlinePeers = allDevices.where((device) => 
              device.status.toLowerCase() == 'connected').toList();
          
          _isLoading = false;
          _isError = false;
          _lastRefreshTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) { // Check if widget is still mounted before setState
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = e.toString();
        });
      }
      debugPrint('❌ Error discovering devices: $e');
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  String _formatLastRefreshTime() {
    final now = DateTime.now();
    final difference = now.difference(_lastRefreshTime);
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  // Format file size for display
  String _formatFileSize(int sizeInBytes) {
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Distributed Storage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPeers,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 30, color: Colors.blue),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _currentUser?.username ?? 'Guest',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    _currentUser?.email ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Upload File'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/file_upload')
                    .then((_) => _loadUserFiles()); // Refresh files when returning
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Retrieve File'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/file_retrieval')
                    .then((_) => _loadUserFiles()); // Refresh files when returning
              },
            ),
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('Peer Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/peer_management');
              },
            ),
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('View Stored Chunks'),
              onTap: () {
                Navigator.pushNamed(context, '/chunks-debug');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.wifi, size: 36, color: Colors.green),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Network: Home Network',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          'Connected Peers: ${_onlinePeers.length}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Files',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (_isLoadingFiles)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 3,
              child: _isLoadingFiles
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _isFilesError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load files',
                                style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _filesErrorMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red[300], fontSize: 12),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadUserFiles,
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        )
                      : _userFiles.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.folder_open,
                                    color: Colors.grey,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No files found',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Upload some files to get started',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/file_upload')
                                          .then((_) => _loadUserFiles());
                                    },
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text('Upload a File'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _userFiles.length,
                              itemBuilder: (context, index) {
                                final file = _userFiles[index];
                                final isAvailable = file.chunks?.every((c) => c.deviceStatus == 'connected') ?? false;
                                final chunkCount = file.chunks?.length ?? 0;
                                
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.insert_drive_file,
                                      size: 36,
                                      color: Colors.blue,
                                    ),
                                    title: Text(file.filename),
                                    subtitle: Text(
                                        'Size: ${_formatFileSize(file.size)} • Chunks: $chunkCount'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isAvailable ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            isAvailable ? 'Available' : 'Offline',
                                            style: TextStyle(
                                              color: isAvailable ? Colors.green.shade800 : Colors.red.shade800,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isAvailable ? Icons.cloud_done : Icons.cloud_off,
                                          color: isAvailable ? Colors.green : Colors.red,
                                        ),
                                      ],
                                    ),
                                    onTap: isAvailable ? () {
                                      Navigator.pushNamed(context, '/file_retrieval');
                                    } : null,
                                  ),
                                );
                              },
                            ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Connected Peers',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                // Add a refresh indicator with last refresh time
                _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        "Last updated: ${_formatLastRefreshTime()}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
              ],
            ),
            const SizedBox(height: 8),
            _isLoading && _onlinePeers.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _isError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load peers',
                              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red[300], fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refreshPeers,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : Expanded(
                        flex: 2,
                        child: _onlinePeers.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.devices_other, color: Colors.grey, size: 48),
                                    SizedBox(height: 16),
                                    Text(
                                      'No connected peers found',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _onlinePeers.length,
                                itemBuilder: (context, index) {
                                  final peer = _onlinePeers[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    child: ListTile(
                                      leading: Icon(
                                        peer.deviceType.toLowerCase().contains('phone') || 
                                        peer.deviceType.toLowerCase().contains('mobile')
                                            ? Icons.smartphone
                                            : Icons.computer,
                                        size: 36,
                                        color: Colors.green, // Always green since we're only showing online peers
                                      ),
                                      title: Text(peer.macAddress),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('IP: ${peer.ip}'),
                                          Text('Free Storage: ${peer.freeStorage.toStringAsFixed(2)} GB'),
                                        ],
                                      ),
                                      isThreeLine: true,
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Online',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'add_device',
            onPressed: () async {
              // Use Navigator.push instead of pushNamed to handle the result
              final result = await Navigator.pushNamed(
                context, 
                '/device_registration'
              );
              
              // Refresh the peers list when returning from registration page
              // regardless of the result
              _refreshPeers();
            },
            child: const Icon(Icons.device_hub),
            tooltip: 'Register Device',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'upload_file',
            onPressed: () async {
              await Navigator.pushNamed(context, '/file_upload');
              // Refresh files when returning
              _loadUserFiles();
            },
            child: const Icon(Icons.add),
            tooltip: 'Upload New File',
          ),
        ],
      ),
    );
  }
}