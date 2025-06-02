// File: screens/settings_page.dart
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Default settings
  bool _autoConnect = true;
  bool _backgroundSync = true;
  bool _wifiOnly = true;
  bool _encryptData = true;
  double _maxStorage = 5.0; // GB
  int _redundancyLevel = 2;
  String _networkType = 'home';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Network Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Auto-connect to known networks'),
                  subtitle:
                      const Text('Automatically join networks you\'ve connected to before'),
                  value: _autoConnect,
                  onChanged: (value) {
                    setState(() {
                      _autoConnect = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Background sync'),
                  subtitle: const Text('Continue syncing while app is in background'),
                  value: _backgroundSync,
                  onChanged: (value) {
                    setState(() {
                      _backgroundSync = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('WiFi only'),
                  subtitle: const Text('Disable syncing when on cellular data'),
                  value: _wifiOnly,
                  onChanged: (value) {
                    setState(() {
                      _wifiOnly = value;
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Network type preference'),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'home',
                            label: Text('Home'),
                            icon: Icon(Icons.home),
                          ),
                          ButtonSegment<String>(
                            value: 'work',
                            label: Text('Work'),
                            icon: Icon(Icons.work),
                          ),
                          ButtonSegment<String>(
                            value: 'public',
                            label: Text('Public'),
                            icon: Icon(Icons.public),
                          ),
                        ],
                        selected: {_networkType},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _networkType = newSelection.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Storage Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Maximum storage allocation'),
                      Text('${_maxStorage.toStringAsFixed(1)} GB'),
                    ],
                  ),
                ),
                Slider(
                  value: _maxStorage,
                  min: 1.0,
                  max: 20.0,
                  divisions: 19,
                  label: '${_maxStorage.toStringAsFixed(1)} GB',
                  onChanged: (value) {
                    setState(() {
                      _maxStorage = value;
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Redundancy level'),
                      Text('$_redundancyLevel copies'),
                    ],
                  ),
                ),
                Slider(
                  value: _redundancyLevel.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$_redundancyLevel copies',
                  onChanged: (value) {
                    setState(() {
                      _redundancyLevel = value.toInt();
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Encrypt all data'),
                  subtitle: const Text('Secure your data with end-to-end encryption'),
                  value: _encryptData,
                  onChanged: (value) {
                    setState(() {
                      _encryptData = value;
                    });
                  },
                ),
                ListTile(
                  title: const Text('Clear local cache'),
                  subtitle: const Text('Remove temporary files'),
                  trailing: const Icon(Icons.delete_outline),
                  onTap: () {
                    // Show confirmation dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear Cache'),
                        content: const Text(
                            'Are you sure you want to clear the local cache? This won\'t affect your stored files on the network.'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              // TODO: Implement cache clearing
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cache cleared'),
                                ),
                              );
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Account Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Profile Information'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Implement profile page navigation
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.password),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Implement password change
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Show confirmation dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text(
                            'Are you sure you want to logout? Your data will remain stored and accessible when you log back in.'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              // Navigate to login page
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/login', (route) => false);
                            },
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'About',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const ListTile(
                  title: Text('Application Version'),
                  trailing: Text('1.0.0'),
                ),
                ListTile(
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Show terms of service
                  },
                ),
                ListTile(
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Show privacy policy
                  },
                ),
                const Divider(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}