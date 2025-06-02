import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../Services/file_service.dart';
import '../Services/file_retrieval_service.dart';
import '../Models/files.dart';
import 'dart:developer' as developer;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

class FileRetrievalPage extends StatefulWidget {
  const FileRetrievalPage({Key? key}) : super(key: key);
  @override
  State<FileRetrievalPage> createState() => _FileRetrievalPageState();
}

class _FileRetrievalPageState extends State<FileRetrievalPage> {
  bool _isLoading = true;
  bool _isRetrieving = false;
  List<FileInfo> _files = [];
  FileInfo? _selectedFile;
  String _errorMessage = '';
  String _statusMessage = '';
  double _retrievalProgress = 0.0;
  File? _retrievedFile;

  @override
  void initState() {
    super.initState();
    _loadUserFiles();
  }

  Future<void> _loadUserFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get all files from the server
      final files = await FileService.getUserFiles();
      developer.log('Loaded ${files.length} files from server', name: 'FileRetrievalPage');
      
      // Check which files are fully available for retrieval
      List<FileInfo> filesWithAvailability = [];
      for (var file in files) {
        try {
          final bool isAvailable = await FileRetrievalService.isFileAvailable(file);
          developer.log('File ${file.filename} availability: $isAvailable', name: 'FileRetrievalPage');
          filesWithAvailability.add(file);
        } catch (e) {
          developer.log('Error checking availability for file ${file.filename}: $e', name: 'FileRetrievalPage');
          // Still add the file, it will be shown as unavailable
          filesWithAvailability.add(file);
        }
      }
      
      setState(() {
        _files = filesWithAvailability;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load files: ${e.toString()}';
        _isLoading = false;
      });
      developer.log('Error loading files: $e', name: 'FileRetrievalPage', error: e);
    }
  }

  Future<void> _retrieveFile(FileInfo file) async {
    setState(() {
      _isRetrieving = true;
      _retrievalProgress = 0.0;
      _statusMessage = 'Starting retrieval...';
      _retrievedFile = null;
    });

    try {
      // Simulate progress updates while actually retrieving the file
      _simulateRetrievalProgress();
      
      // Retrieve the file
      final retrievedFile = await FileRetrievalService.retrieveFile(file);
      
      // Update UI with success
      setState(() {
        _isRetrieving = false;
        _retrievalProgress = 1.0;
        _statusMessage = 'File retrieved successfully';
        _retrievedFile = retrievedFile;
      });
      
      _showSuccessDialog(retrievedFile);
    } catch (e) {
      setState(() {
        _isRetrieving = false;
        _errorMessage = 'Failed to retrieve file: ${e.toString().replaceAll('Exception:', '')}';
        _statusMessage = '';
      });
      
      _showErrorDialog('Error', _errorMessage);
    }
  }

  void _simulateRetrievalProgress() {
    // Estimate time for retrieval based on file size
    const updateInterval = Duration(milliseconds: 200);
    const totalSteps = 25; // 5 seconds / 200ms for moderate sized files
    int currentStep = 0;
    
    // Update progress at regular intervals
    Timer.periodic(updateInterval, (timer) {
      if (!_isRetrieving || currentStep >= totalSteps) {
        timer.cancel();
        return;
      }
      
      currentStep++;
      final progress = currentStep / totalSteps;
      
      setState(() {
        _retrievalProgress = progress;
        
        if (progress < 0.2) {
          _statusMessage = 'Locating file chunks...';
        } else if (progress < 0.5) {
          _statusMessage = 'Downloading chunks from distributed storage...';
        } else if (progress < 0.8) {
          _statusMessage = 'Decrypting and verifying chunks...';
        } else {
          _statusMessage = 'Reassembling file...';
        }
      });
      
      if (currentStep >= totalSteps) {
        timer.cancel();
      }
    });
  }

  void _showSuccessDialog(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Retrieved'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File saved to:'),
            const SizedBox(height: 8),
            Text(
              file.path,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              _openFile(file);
              Navigator.of(context).pop();
            },
            child: const Text('Open File'),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(File file) async {
    try {
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('Could not open file');
      }
    } catch (e) {
      _showErrorDialog('Error', 'Could not open the file: ${e.toString()}');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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
        title: const Text('Retrieve Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadUserFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserFiles,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_open,
              color: Colors.grey,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'No files found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload some files first',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/file_upload');
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload a File'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select a file to retrieve:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                final isAvailable = file.chunks?.every((c) => c.deviceStatus == 'connected') ?? false;
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: _selectedFile?.id == file.id
                      ? Colors.blue.withOpacity(0.1)
                      : null,
                  child: ListTile(
                    leading: const Icon(
                      Icons.insert_drive_file,
                      size: 36,
                      color: Colors.blue,
                    ),
                    title: Text(file.filename),
                    subtitle: Text(
                      'Size: ${_formatFileSize(file.size)} • Created: ${_formatDate(file.createdAt)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
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
                    enabled: isAvailable && !_isRetrieving,
                    onTap: isAvailable && !_isRetrieving
                        ? () {
                            setState(() {
                              _selectedFile = file;
                            });
                          }
                        : null,
                  ),
                );
              },
            ),
          ),
          if (_isRetrieving) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: _retrievalProgress,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _statusMessage,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: _retrievalProgress),
                    const SizedBox(height: 8),
                    Text(
                      '${(_retrievalProgress * 100).toStringAsFixed(1)}% complete',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download),
              onPressed: _selectedFile != null && !_isRetrieving
                  ? () => _retrieveFile(_selectedFile!)
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              label: Text(
                _isRetrieving ? 'Retrieving...' : 'Retrieve Selected File',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      
      // If same day, show time
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      
      // If same year, show month and day
      if (date.year == now.year) {
        return '${date.month}/${date.day}';
      }
      
      // Otherwise show year-month-day
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString.substring(0, min(10, dateString.length));
    }
  }

  int min(int a, int b) => a < b ? a : b;
}