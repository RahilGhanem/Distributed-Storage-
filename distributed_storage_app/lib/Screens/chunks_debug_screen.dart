import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../Services/chunk_receiver_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ChunksDebugScreen extends StatefulWidget {
  const ChunksDebugScreen({Key? key}) : super(key: key);

  @override
  State<ChunksDebugScreen> createState() => _ChunksDebugScreenState();
}

class _ChunksDebugScreenState extends State<ChunksDebugScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _chunks = [];
  bool _isLoading = true;
  String _debugInfo = '';
  late TabController _tabController;
  bool _isDebugVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadChunks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChunks() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Searching for chunks...';
    });
    
    try {
      // Get storage directories for debugging
      final appDocDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final appSupportDir = await getApplicationSupportDirectory();
      
      String debug = 'Storage paths:\n';
      debug += '📁 Documents: ${appDocDir.path}\n';
      debug += '📁 Temporary: ${tempDir.path}\n';
      debug += '📁 App Support: ${appSupportDir.path}\n';
      
      if (Platform.isAndroid) {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          debug += '📁 External: ${externalDir.path}\n';
        } else {
          debug += '❌ External storage not available\n';
        }
      }
      
      // Update the debug info
      setState(() {
        _debugInfo = debug;
      });
      
      // Get chunks
      final chunks = await ChunkReceiverService.listStoredChunks();
      
      // Group chunks by fileId for better organization
      chunks.sort((a, b) => 
        a['fileId'].toString().compareTo(b['fileId'].toString()) != 0 
          ? a['fileId'].toString().compareTo(b['fileId'].toString()) 
          : int.parse(a['chunkOrder'].toString()).compareTo(int.parse(b['chunkOrder'].toString()))
      );
      
      setState(() {
        _chunks = chunks;
        _isLoading = false;
        _debugInfo += '\n🔎 Found ${chunks.length} chunks';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _debugInfo += '\n❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _openChunksDirectory,
            tooltip: 'Open chunks folder',
          ),
          IconButton(
            icon: Icon(_isDebugVisible ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _isDebugVisible = !_isDebugVisible;
              });
            },
            tooltip: _isDebugVisible ? 'Hide debug info' : 'Show debug info',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChunks,
            tooltip: 'Refresh chunks',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chunks List'),
            Tab(text: 'Storage Info'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Debug information panel - collapsible
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isDebugVisible ? 120 : 0,
            child: _isDebugVisible ? Container(
              padding: const EdgeInsets.all(10),
              color: Colors.grey.shade900,
              width: double.infinity,
              child: SingleChildScrollView(
                child: Text(
                  _debugInfo,
                  style: const TextStyle(
                    fontFamily: 'Courier', 
                    fontSize: 12,
                    color: Colors.lightGreenAccent,
                  ),
                ),
              ),
            ) : const SizedBox(),
          ),
          
          // Main content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Chunks list tab
                _buildChunksList(),
                
                // Storage info tab
                _buildStorageInfo(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Test Chunk'),
        onPressed: () {
          _createTestChunk();
        },
        tooltip: 'Create test chunk',
      ),
    );
  }
  
  Widget _buildChunksList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading chunks...'),
          ],
        ),
      );
    }
    
    if (_chunks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 70, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No chunks found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This device is not storing any file chunks yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createTestChunk,
              icon: const Icon(Icons.add),
              label: const Text('Create Test Chunk'),
            ),
          ],
        ),
      );
    }
    
    // Group chunks by fileId for better organization
    Map<String, List<Map<String, dynamic>>> fileChunks = {};
    for (var chunk in _chunks) {
      String fileId = chunk['fileId'].toString();
      if (!fileChunks.containsKey(fileId)) {
        fileChunks[fileId] = [];
      }
      fileChunks[fileId]!.add(chunk);
    }
    
    return ListView.builder(
      itemCount: fileChunks.length,
      itemBuilder: (context, index) {
        String fileId = fileChunks.keys.elementAt(index);
        List<Map<String, dynamic>> chunks = fileChunks[fileId]!;
        chunks.sort((a, b) => int.parse(a['chunkOrder'].toString())
            .compareTo(int.parse(b['chunkOrder'].toString())));
        
        // Calculate total size of all chunks for this file
        int totalSize = chunks.fold(0, (sum, chunk) => sum + (chunk['size'] as int? ?? 0));
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.storage, color: Colors.white),
            ),
            title: Text(
              'File ID: $fileId',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${chunks.length} chunks • ${_formatSize(totalSize)}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            children: [
              const Divider(),
              ...chunks.map((chunk) => _buildChunkListItem(chunk)).toList(),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildChunkListItem(Map<String, dynamic> chunk) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade100,
        child: Text(chunk['chunkOrder'].toString()),
      ),
      title: Text('Chunk ${chunk['chunkOrder']}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Size: ${_formatSize(chunk['size'] ?? 0)}'),
          Text(
            'Modified: ${_formatDate(chunk['modified'])}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.download, color: Colors.blue),
        tooltip: 'Test Retrieve',
        onPressed: () async {
          try {
            // Show a loading indicator
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Retrieving chunk...'),
                duration: Duration(seconds: 1),
              ),
            );
            
            final data = await ChunkReceiverService.retrieveChunk(
              chunk['fileId'],
              int.parse(chunk['chunkOrder'].toString()),
            );
            
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Retrieved ${data?.length ?? 0} bytes successfully'),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Error: $e')),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        },
      ),
      onTap: () {
        // Show detailed info in a modal
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chunk Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: 'File ID: ',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                        ),
                        TextSpan(text: '${chunk['fileId']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: 'Chunk Order: ',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                        ),
                        TextSpan(text: '${chunk['chunkOrder']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: 'Size: ',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                        ),
                        TextSpan(text: '${_formatSize(chunk['size'] ?? 0)}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Storage Information:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  SelectableText('Path: ${chunk['path']}'),
                  const SizedBox(height: 4),
                  Text('Last Modified: ${_formatDate(chunk['modified'])}'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Test Retrieve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            final data = await ChunkReceiverService.retrieveChunk(
                              chunk['fileId'],
                              int.parse(chunk['chunkOrder'].toString()),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text('Retrieved ${_formatSize(data?.length ?? 0)} successfully'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showDeleteConfirmation(chunk);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> chunk) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chunk?'),
        content: Text(
          'Are you sure you want to delete Chunk ${chunk['chunkOrder']} of File ID ${chunk['fileId']}?\n\nThis can cause data loss if the original file owner tries to retrieve this chunk.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              // Implementation for chunk deletion would go here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delete functionality not implemented'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildStorageInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storage, color: Colors.blue, size: 30),
                      const SizedBox(width: 12),
                      Text(
                        'Storage Statistics',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildStatItem(
                    'Total Chunks', 
                    '${_chunks.length}',
                    Icons.folder
                  ),
                  const SizedBox(height: 8),
                  _buildStatItem(
                    'Total Files', 
                    '${_chunks.map((c) => c['fileId']).toSet().length}',
                    Icons.insert_drive_file
                  ),
                  const SizedBox(height: 8),
                  _buildStatItem(
                    'Total Size', 
                    _formatSize(_chunks.fold(0, (sum, chunk) => sum + (chunk['size'] as int? ?? 0))),
                    Icons.data_usage
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Storage Paths',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _debugInfo
                    .split('\n')
                    .where((line) => line.contains('📁') || line.contains('❌ External'))
                    .map((line) => Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: line.contains('❌') 
                                ? const Icon(Icons.error_outline, color: Colors.orange) 
                                : const Icon(Icons.folder, color: Colors.blue),
                            title: Text(
                              line.replaceAll('📁 ', '').replaceAll('❌ ', ''),
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: line.contains('❌') 
                                ? null 
                                : const Icon(Icons.folder_open, color: Colors.grey),
                            onTap: line.contains('❌') ? null : () {
                              final path = line.split(': ')[1];
                              _openPath(path);
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Clear Storage Data'),
              onPressed: () {
                _showClearDataConfirmation();
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 16),
        const SizedBox(width: 8),
        Text('$title: '),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
  
  void _showClearDataConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Storage Data?'),
        content: const Text(
          'Are you sure you want to delete all stored chunks? This action cannot be undone and may cause data loss for files that depend on these chunks.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              // Implementation for clearing storage would go here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Clear functionality not implemented'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  void _openPath(String path) {
    // Implementation similar to _openChunksDirectory
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening: $path'),
      ),
    );
  }

  Future<void> _openChunksDirectory() async {
    try {
      Directory chunksDir;
      
      // Try to get the external directory first
      if (Platform.isAndroid) {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          chunksDir = Directory('${externalDir.path}/distributed_storage_chunks');
          if (!await chunksDir.exists()) {
            chunksDir = Directory('${externalDir.path}/chunks');
          }
        } else {
          final appDocDir = await getApplicationDocumentsDirectory();
          chunksDir = Directory('${appDocDir.path}/chunks');
        }
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        chunksDir = Directory('${appDocDir.path}/chunks');
      }
      
      if (await chunksDir.exists()) {
        // For Android, try to open the directory in a file manager
        if (Platform.isAndroid) {
          final uri = Uri.parse('content://com.android.externalstorage.documents/document/primary:Android/data/${chunksDir.path.split('/Android/data/')[1]}');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Path: ${chunksDir.path}\nCannot open file manager automatically.'),
                duration: const Duration(seconds: 8),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Path: ${chunksDir.path}'),
              duration: const Duration(seconds: 8),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chunks directory does not exist yet'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening directory: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createTestChunk() async {
    try {
      // Create a test chunk to see if storage permissions work
      final appDocDir = await getApplicationDocumentsDirectory();
      final testFileDir = Directory('${appDocDir.path}/chunks/test_file');
      
      // Create directories
      if (!await testFileDir.exists()) {
        await testFileDir.create(recursive: true);
      }
      
      // Create a simple test file
      final testFile = File('${testFileDir.path}/0');
      await testFile.writeAsString('This is a test chunk created on ${DateTime.now()}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Test chunk created successfully'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the list
      _loadChunks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Error creating test chunk: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Helper methods
  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
  
  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays == 0) {
        // Today, show time
        return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        // Yesterday
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        // Last 7 days
        return '${diff.inDays} days ago';
      } else {
        // Older
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return dateStr;
    }
  }
}