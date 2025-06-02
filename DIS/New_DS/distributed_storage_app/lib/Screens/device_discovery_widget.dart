import 'package:flutter/material.dart';
import '../Services/discovery_service.dart';
import '../Services/auth_service.dart';

class DeviceDiscoveryWidget extends StatefulWidget {
  final String serverUrl;
  final String? authToken;

  const DeviceDiscoveryWidget({
    Key? key, 
    required this.serverUrl, 
    this.authToken
  }) : super(key: key);

  @override
  _DeviceDiscoveryWidgetState createState() => _DeviceDiscoveryWidgetState();
}

class _DeviceDiscoveryWidgetState extends State<DeviceDiscoveryWidget> {
  late final DiscoveryService _discoveryService;
  List<DiscoveredDevice> _devices = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _discoveryService = DiscoveryService(
      baseUrl: widget.serverUrl,
      authToken: widget.authToken
    );
    _discoverDevices();
  }

  Future<void> _discoverDevices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final devices = await _discoveryService.discoverDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Network Devices', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _discoverDevices,
            ),
          ],
        ),
        if (_isLoading) 
          const LinearProgressIndicator(),
        if (_error != null) 
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              _error!, 
              style: const TextStyle(color: Colors.red)
            ),
          ),
        if (_devices.isEmpty && !_isLoading && _error == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'No devices found on network', 
              style: TextStyle(fontStyle: FontStyle.italic)
            ),
          ),
        ..._devices.map((device) => Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: Icon(
              device.deviceType.toLowerCase().contains('phone') || 
              device.deviceType.toLowerCase().contains('mobile')
                ? Icons.smartphone
                : Icons.devices,
              color: device.online ? Colors.green : Colors.grey,
            ),
            title: Text(device.macAddress),
            subtitle: Text('${device.ip} - ${device.storage.toStringAsFixed(2)}GB available'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: device.online ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                device.status,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        )),
      ],
    );
  }
}