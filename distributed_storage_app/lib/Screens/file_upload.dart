import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../Services/file_service.dart';
import '../Services/device_service.dart';
import '../Models/device.dart';
import 'dart:developer' as developer;

class FileUploadPage extends StatefulWidget {
  const FileUploadPage({Key? key}) : super(key: key);

  @override
  _FileUploadPageState createState() => _FileUploadPageState();
}

class _FileUploadPageState extends State<FileUploadPage> {
  File? _selectedFile;
  List<Device> _availableDevices = [];
  List<Device> _selectedDevices = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String _statusMessage = '';
  double _uploadProgress = 0.0;
  String _errorMessage = '';
  // Now we'll use a variable to track ideal devices, but accept any number
  int _idealDeviceCount = 3; 
  int _chunkSizeKB = 1024; // Default 1MB chunks
  
  @override
  void initState() {
    super.initState();
    _loadAvailableDevices();
  }

  Future<void> _loadAvailableDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final devices = await DeviceService.getConnectedDevices();
      setState(() {
        _availableDevices = devices;
        _isLoading = false;
        
        // Always auto-select all available devices
        _selectOptimalDevices();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load devices: ${e.toString()}';
      });
    }
  }

  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _statusMessage = '';
          _uploadProgress = 0.0;
          
          // Always optimize chunk size for the file
          _optimizeChunkSize();
          
          // Always auto-select optimal devices
          _selectOptimalDevices();
        });
      }
    } catch (e) {
      _showErrorDialog('Error', 'Failed to select file: ${e.toString()}');
    }
  }

  void _optimizeChunkSize() {
    if (_selectedFile == null) return;
    
    try {
      final fileSize = _selectedFile!.lengthSync();
      
      // Algorithm to determine optimal chunk size:
      // 1. Files under 1MB: Use 64KB chunks
      // 2. Files 1MB-10MB: Use 256KB chunks
      // 3. Files 10MB-100MB: Use 1MB chunks
      // 4. Files 100MB-1GB: Use 4MB chunks
      // 5. Files over 1GB: Use 8MB chunks
      
      // Additionally, ensure chunk count is between 5-100 for optimal distribution
      
      int optimalChunkSize;
      
      if (fileSize < 1024 * 1024) {
        // Less than 1MB
        optimalChunkSize = 64;
      } else if (fileSize < 10 * 1024 * 1024) {
        // 1MB to 10MB
        optimalChunkSize = 256;
      } else if (fileSize < 100 * 1024 * 1024) {
        // 10MB to 100MB
        optimalChunkSize = 1024;
      } else if (fileSize < 1024 * 1024 * 1024) {
        // 100MB to 1GB
        optimalChunkSize = 4 * 1024;
      } else {
        // Over 1GB
        optimalChunkSize = 8 * 1024;
      }
      
      // Final adjustment: ensure we have at least 5 chunks but not more than 100
      int chunkCount = fileSize ~/ (optimalChunkSize * 1024);
      if (chunkCount < 5) {
        optimalChunkSize = max(64, fileSize ~/ (5 * 1024));
      } else if (chunkCount > 100) {
        optimalChunkSize = max(64, fileSize ~/ (100 * 1024));
      }
      
      // MODIFIED: If we have very few devices, adjust chunk size 
      // to ensure we don't create too many chunks
      if (_availableDevices.length < 3 && fileSize > 5 * 1024 * 1024) {
        // For smaller device counts, use larger chunks to reduce total chunk count
        optimalChunkSize = max(optimalChunkSize, 512);
      }
      
      setState(() {
        _chunkSizeKB = optimalChunkSize;
      });
      
      developer.log('Optimized chunk size: $_chunkSizeKB KB for file size: ${fileSize / 1024 / 1024} MB');
    } catch (e) {
      developer.log('Error optimizing chunk size: $e', error: e);
      // Keep default chunk size on error
    }
  }

  void _selectOptimalDevices() {
    if (_availableDevices.isEmpty) return;
    
    // Clear previous selection
    _selectedDevices.clear();
    
    // Sort devices by available storage (descending)
    final List<Device> sortedDevices = List.from(_availableDevices);
    sortedDevices.sort((a, b) => b.freeStorage.compareTo(a.freeStorage));
    
    // Calculate required storage based on file size
    int requiredStoragePerDevice = 0;
    if (_selectedFile != null) {
      try {
        final fileSize = _selectedFile!.lengthSync();
        
        // MODIFIED: Calculate more intelligently based on device count
        // With fewer devices, each needs more storage for redundancy
        double redundancyFactor = 1.5; // Default redundancy
        
        if (sortedDevices.length == 1) {
          // Single device needs all chunks
          redundancyFactor = 1.2; // Lower overhead, no redundancy possible
        } else if (sortedDevices.length == 2) {
          // Each device needs at least 75% of all chunks for good redundancy
          redundancyFactor = 1.5;
        } else {
          // With 3+ devices, standard redundancy approach
          redundancyFactor = 1.3;
        }
        
        requiredStoragePerDevice = (fileSize * redundancyFactor / sortedDevices.length).ceil();
      } catch (e) {
        developer.log('Error calculating required storage: $e', error: e);
      }
    }
    
    // Calculate ideal number of devices based on redundancy needs
    int idealDeviceCount = _idealDeviceCount;
    
    if (_selectedFile != null) {
      final fileSize = _selectedFile!.lengthSync();
      if (fileSize > 100 * 1024 * 1024) { // Over 100MB
        idealDeviceCount = 5;
      } else if (fileSize > 10 * 1024 * 1024) { // Over 10MB
        idealDeviceCount = 4;
      } else {
        idealDeviceCount = 3;
      }
    }
    
    // MODIFIED: Select ALL available devices that meet storage requirements
    // We no longer cap at idealDeviceCount to ensure maximum availability
    for (var device in sortedDevices) {
      // Skip devices with insufficient storage
      if (requiredStoragePerDevice > 0 && device.freeStorage < requiredStoragePerDevice) {
        continue;
      }
      
      _selectedDevices.add(device);
    }
    
    setState(() {});
    
    developer.log('Auto-selected ${_selectedDevices.length} devices (ideal count: $idealDeviceCount)');
  }

// Replace the uploadFile method with this improved version
Future<void> _uploadFile() async {
  if (_selectedFile == null) {
    _showErrorDialog('Error', 'Please select a file first.');
    return;
  }

  if (_selectedDevices.isEmpty) {
    _showErrorDialog('Error', 'No devices available for distribution.');
    return;
  }

  // MODIFIED: Show warning if we have fewer than ideal devices
  final int chunkCount = (_selectedFile!.lengthSync() / (_chunkSizeKB * 1024)).ceil();
  if (_selectedDevices.length < _idealDeviceCount && _selectedDevices.length > 0) {
    final shouldProceed = await _showRedundancyWarningDialog(
      availableCount: _selectedDevices.length, 
      idealCount: _idealDeviceCount,
      chunkCount: chunkCount
    );
    
    if (!shouldProceed) {
      return;
    }
  }
  
  setState(() {
    _isUploading = true;
    _statusMessage = 'Verifying connections...';
    _uploadProgress = 0.05;
    _errorMessage = '';
  });

  try {
    final List<String> targetDeviceIds = 
        _selectedDevices.map((device) => device.id.toString()).toList();
    
    setState(() {
      _statusMessage = 'Preparing file upload...';
      _uploadProgress = 0.1;
    });
    
    final fileSize = await _selectedFile!.length();
    _simulateUploadProgress(fileSize);
    
    // MODIFIED: Add retry and fault tolerance options
    await FileService.uploadFile(
      _selectedFile!, 
      targetDeviceIds,
      retries: 2,                      // Try each device up to 3 times (initial + 2 retries)
      timeoutSeconds: 30,              // Wait maximum 30 seconds per device
      continueOnPartialFailure: true,  // Continue even if some devices fail
      adaptiveRedundancy: true,        // Adjust redundancy based on available devices
    );
    
    setState(() {
      _uploadProgress = 1.0;
      _statusMessage = 'Upload complete!';
      _isUploading = false;
    });
    
    _showSuccessDialog(
      'Success',
      'File "${path.basename(_selectedFile!.path)}" has been encrypted and distributed across ${targetDeviceIds.length} devices.'
    );
    
    setState(() {
      _selectedFile = null;
      _selectedDevices = [];
    });
  } catch (e) {
    setState(() {
      _isUploading = false;
      String errorMessage = e.toString();
      if (errorMessage.contains('Could not connect to server') || 
          errorMessage.contains('ETIMEDOUT') ||
          errorMessage.contains('connection failed')) {
        _errorMessage = 'Connection error: Some devices are unreachable. Please check: \n\n1. Your server is running\n2. Your device has network access\n3. Selected devices are online\n4. No firewalls blocking the connection';
      } else {
        _errorMessage = 'Upload failed: ${errorMessage.replaceAll('Exception: ', '')}';
      }
    });
    _showErrorDialog('Error', _errorMessage);
  }
}

  Future<bool> _showRedundancyWarningDialog({
    required int availableCount,
    required int idealCount,
    required int chunkCount,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limited Device Availability'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have $availableCount devices available, but $idealCount devices are recommended for optimal redundancy.',
            ),
            const SizedBox(height: 12),
            Text(
              'Your file will be split into $chunkCount chunks, with:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (availableCount == 1)
              const Text('• All chunks on a single device (no redundancy)'),
            if (availableCount == 2)
              const Text('• Chunks duplicated across both devices for redundancy'),
            if (availableCount >= 3)
              const Text('• Chunks distributed with partial redundancy'),
            const SizedBox(height: 12),
            const Text(
              'Do you want to continue with the upload?',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _simulateUploadProgress(int fileSize) {
    final chunkSize = _chunkSizeKB * 1024; // Convert KB to bytes
    final totalChunks = (fileSize / chunkSize).ceil();
    var chunksUploaded = 0;
    
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isUploading || chunksUploaded >= totalChunks) {
        timer.cancel();
        return;
      }
      
      chunksUploaded++;
      final progress = chunksUploaded / totalChunks;
      
      setState(() {
        _uploadProgress = progress;
        if (progress > 0.7) {
          _statusMessage = 'Finalizing file distribution...';
        } else if (progress > 0.5) {
          _statusMessage = 'Encrypting and sending chunks...';
        } else {
          _statusMessage = 'Uploading ${(progress * 100).toStringAsFixed(1)}%';
        }
      });
      
      if (chunksUploaded >= totalChunks) {
        timer.cancel();
      }
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload & Distribute File'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAvailableDevices,
            tooltip: 'Refresh devices',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // File Selection Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select File',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: _isUploading ? null : _selectFile,
                                child: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: _selectedFile != null
                                      ? Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.insert_drive_file, size: 32),
                                              const SizedBox(height: 4),
                                              Flexible(
                                                child: Text(
                                                  path.basename(_selectedFile!.path),
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                ),
                                              ),
                                              Text(
                                                '${(File(_selectedFile!.path).lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
                                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        )
                                      : const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.cloud_upload, size: 32),
                                            SizedBox(height: 8),
                                            Text('Click to select file'),
                                          ],
                                        ),
                                  ),
                                ),
                              ),
                              if (_errorMessage.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Container(
                                    width: double.infinity,
                                    child: Text(
                                      _errorMessage,
                                      style: const TextStyle(color: Colors.red),
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ),
                              if (_isUploading)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        child: Text(
                                          _statusMessage,
                                          overflow: TextOverflow.visible,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(value: _uploadProgress),
                                      const SizedBox(height: 4),
                                      Text('${(_uploadProgress * 100).toStringAsFixed(1)}%'),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Smart Distribution System Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Smart Distribution System',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'This system automatically:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoItem(Icons.precision_manufacturing, 'Optimizes chunk size based on file size'),
                              _buildInfoItem(Icons.scatter_plot, 'Adapts to any number of available devices'),
                              _buildInfoItem(Icons.storage, 'Selects devices with the most available storage'),
                              _buildInfoItem(Icons.security, 'Encrypts all data before distribution'),
                              
                              if (_selectedFile != null) ...[
                                const Divider(height: 24),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Optimized Chunk Size: $_chunkSizeKB KB', 
                                          style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(
                                        'File will be split into ${(_selectedFile!.lengthSync() / (_chunkSizeKB * 1024)).ceil()} chunks',
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.visible,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text('Selected ${_selectedDevices.length} device${_selectedDevices.length != 1 ? "s" : ""}', 
                                                style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                          if (_selectedDevices.length < _idealDeviceCount && _selectedDevices.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Limited redundancy',
                                                style: TextStyle(
                                                  color: Colors.orange.shade800, 
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          if (_selectedDevices.length >= _idealDeviceCount)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Optimal redundancy',
                                                style: TextStyle(
                                                  color: Colors.green.shade800, 
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        _selectedDevices.isEmpty 
                                          ? 'No devices available' 
                                          : 'Total available storage: ${(_selectedDevices.fold(0.0, (sum, device) => sum + device.freeStorage) / (1024 * 1024)).toStringAsFixed(1)} MB',
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.visible,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Devices List Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Automatically Selected Devices',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _selectedDevices.isEmpty
                                        ? Colors.red.withOpacity(0.2)
                                        : (_selectedDevices.length < _idealDeviceCount
                                          ? Colors.orange.withOpacity(0.2)
                                          : Colors.green.withOpacity(0.2)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_selectedDevices.length} selected',
                                      style: TextStyle(
                                        color: _selectedDevices.isEmpty
                                          ? Colors.red.shade800
                                          : (_selectedDevices.length < _idealDeviceCount
                                            ? Colors.orange.shade800
                                            : Colors.green.shade800),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // Make device list a fixed height instead of Expanded
                              SizedBox(
                                height: 200, // Fixed height for device list
                                child: _isLoading 
                                  ? const Center(child: CircularProgressIndicator())
                                  : _availableDevices.isEmpty 
                                    ? const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.device_unknown, size: 48, color: Colors.grey),
                                            SizedBox(height: 16),
                                            Text('No devices available', style: TextStyle(color: Colors.grey)),
                                            Text('Please ensure your devices are connected', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: _availableDevices.length,
                                        itemBuilder: (context, index) {
                                          final device = _availableDevices[index];
                                          final isSelected = _selectedDevices.any((d) => d.id == device.id);
                                          
                                          return ListTile(
                                            dense: true,
                                            visualDensity: VisualDensity.compact,
                                            leading: Icon(
                                              Icons.devices, 
                                              color: isSelected ? Colors.blue : Colors.grey,
                                            ),
                                            title: Text(
                                              device.name,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              '${(device.freeStorage / (1024 * 1024)).toStringAsFixed(1)} MB free',
                                              style: const TextStyle(fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            trailing: isSelected 
                                              ? const Icon(Icons.check_circle, color: Colors.green) 
                                              : null,
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom button - outside scrollable area
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedFile != null && 
                    _selectedDevices.isNotEmpty && 
                    !_isUploading)
                    ? _uploadFile
                    : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    backgroundColor: Colors.blue,
                  ),
                  child: Text(
                    _isUploading 
                      ? 'Uploading...' 
                      : 'Upload & Distribute File',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}