import 'package:flutter/material.dart';
import 'dart:async';
import '../Services/discovery_service.dart';
import '../Services/auth_service.dart';

class PeerManagementPage extends StatefulWidget {
  const PeerManagementPage({super.key});

  @override
  _PeerManagementPageState createState() => _PeerManagementPageState();
}

class _PeerManagementPageState extends State<PeerManagementPage> with SingleTickerProviderStateMixin {
  DiscoveryService? _discoveryService;
  AuthService _authService = AuthService();
  
  List<DiscoveredDevice> _onlinePeers = [];
  List<DiscoveredDevice> _offlinePeers = [];
  bool _isScanning = false;
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _autoRefreshTimer;
  DateTime _lastRefreshTime = DateTime.now();
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize the discovery service asynchronously
    _initializeDiscoveryService();
  }
  
  Future<void> _initializeDiscoveryService() async {
    try {
      // Get the auth token asynchronously
      final token = await _authService.getAuthToken();
      
      // Create the discovery service
      _discoveryService = DiscoveryService(
        baseUrl: 'http://192.168.97.126:5000',
        authToken: token,
      );
      
      // After initialization, fetch peers
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _fetchPeers();
        
        // Auto-refresh peers every 30 seconds
        _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
          _fetchPeers();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPeers() async {
    if (_discoveryService == null) {
      setState(() {
        _errorMessage = 'Discovery service not initialized';
      });
      return;
    }
    
    setState(() {
      _isScanning = true;
      _errorMessage = '';
    });

    try {
      final devices = await _discoveryService!.discoverDevices();
      
      if (mounted) {
        setState(() {
          // Filter devices by online status based on 'connected' status
          _onlinePeers = devices.where((device) => 
              device.status.toLowerCase() == 'connected').toList();
          _offlinePeers = devices.where((device) => 
              device.status.toLowerCase() == 'disconnected').toList();
          _isScanning = false;
          _lastRefreshTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error fetching peers: ${e.toString()}';
          _isScanning = false;
        });
        print('Error fetching peers: $e');
      }
    }
  }

  void _scanForPeers() {
    _fetchPeers();
  }

  String _formatLastRefresh() {
    final difference = DateTime.now().difference(_lastRefreshTime);
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return '${difference.inHours} hours ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Show loading indicator while initializing
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Peer Management'),
          centerTitle: true, 
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing...'),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peer Management'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.pending : Icons.refresh),
            onPressed: _isScanning ? null : _scanForPeers,
            tooltip: 'Refresh Network',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPeers,
        child: Column(
          children: [
            // Status bar with refresh info and counts
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.device_hub,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Network Status',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Updated ${_formatLastRefresh()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard(
                        context,
                        Icons.cloud_done,
                        _onlinePeers.length.toString(),
                        'Online',
                        Colors.green,
                      ),
                      _buildStatCard(
                        context,
                        Icons.cloud_off,
                        _offlinePeers.length.toString(),
                        'Offline',
                        Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Error message if any
            if (_errorMessage.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        setState(() {
                          _errorMessage = '';
                        });
                      },
                      color: Colors.red.shade700,
                    ),
                  ],
                ),
              ),
            
            // Loading indicator
            if (_isScanning)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Scanning for peers...',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Tab bar
            Container(
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_done, size: 16),
                        const SizedBox(width: 8),
                        Text('Online (${_onlinePeers.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off, size: 16),
                        const SizedBox(width: 8),
                        Text('Offline (${_offlinePeers.length})'),
                      ],
                    ),
                  ),
                ],
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3,
              ),
            ),
            
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Online Devices Tab
                  _onlinePeers.isEmpty
                      ? _buildEmptyState(
                          context,
                          'No online devices found',
                          'Pull down to refresh or tap the refresh button',
                          Icons.devices_other,
                        )
                      : _buildDeviceList(_onlinePeers, true),
                  
                  // Offline Devices Tab
                  _offlinePeers.isEmpty
                      ? _buildEmptyState(
                          context,
                          'No offline devices found',
                          'They may be out of range or powered off',
                          Icons.device_unknown,
                        )
                      : _buildDeviceList(_offlinePeers, false),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isScanning
          ? null 
          : FloatingActionButton(
              onPressed: _scanForPeers,
              child: const Icon(Icons.radar),
              tooltip: 'Scan for new devices',
            ),
    );
  }
  
  Widget _buildEmptyState(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String count,
    String label,
    Color color,
  ) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.42,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDeviceList(List<DiscoveredDevice> devices, bool isOnline) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return _buildDeviceCard(context, device, isOnline);
      },
    );
  }
  
  Widget _buildDeviceCard(BuildContext context, DiscoveredDevice device, bool isOnline) {
    final theme = Theme.of(context);
    final Color statusColor = isOnline ? Colors.green : Colors.grey;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOnline 
              ? theme.colorScheme.primary.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      elevation: 2,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getDeviceIcon(device.deviceType), color: statusColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.macAddress,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IP: ${device.ip}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              device.status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Storage section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Storage Capacity',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${device.freeStorage.toStringAsFixed(1)} GB available',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: device.freeStorage > 100 ? 0.1 : device.freeStorage / 10,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        device.freeStorage < 2
                            ? Colors.red
                            : device.freeStorage < 5
                                ? Colors.orange
                                : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Device info section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          context,
                          Icons.perm_device_information,
                          'MAC Address',
                          device.macAddress,
                        ),
                        const Divider(height: 16),
                        _buildInfoRow(
                          context,
                          Icons.devices,
                          'Device Type',
                          device.deviceType,
                        ),
                        const Divider(height: 16),
                        _buildInfoRow(
                          context,
                          Icons.language,
                          'IP Address',
                          device.ip,
                        ),
                        const Divider(height: 16),
                        _buildInfoRow(
                          context,
                          Icons.access_time,
                          'Status',
                          device.status,
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified_user,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Trusted Device',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Switch(
                              value: true, // Default to trusted
                              onChanged: (value) {
                                // TODO: Implement trust toggle functionality
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isOnline
                              ? () {
                                  // TODO: Implement ping
                                }
                              : null,
                          icon: const Icon(Icons.network_ping, size: 18),
                          label: const Text('Ping'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement view chunks
                          },
                          icon: const Icon(Icons.storage, size: 18),
                          label: const Text('View Chunks'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: theme.colorScheme.secondaryContainer,
                            foregroundColor: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isOnline ? () {
                        // TODO: Implement disconnect logic
                      } : null,
                      icon: const Icon(Icons.link_off, size: 18),
                      label: const Text('Disconnect'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getDeviceIcon(String deviceType) {
    final type = deviceType.toLowerCase();
    if (type.contains('phone') || type.contains('mobile')) {
      return Icons.smartphone;
    } else if (type.contains('laptop')) {
      return Icons.laptop;
    } else if (type.contains('tablet')) {
      return Icons.tablet;
    } else if (type.contains('desktop')) {
      return Icons.desktop_windows;
    } else {
      return Icons.devices;
    }
  }
  
  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}