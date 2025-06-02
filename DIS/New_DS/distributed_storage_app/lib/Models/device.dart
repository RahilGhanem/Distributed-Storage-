import 'package:flutter/foundation.dart';

class Device {
  final String id;
  final String name;
  final String ipAddress;
  final String macAddress;
  final String deviceType;
  final double storageCapacity;
  final double freeStorage;
  final String status;
  final DateTime lastSeen;
  final int? userId;

  Device({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.macAddress,
    required this.deviceType,
    required this.storageCapacity,
    required this.freeStorage,
    required this.status,
    required this.lastSeen,
    this.userId,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
  return Device(
    id: json['id']?.toString() ?? '',
    name: json['name'] ?? 'Device',
    ipAddress: json['ip_address'] ?? json['ipAddress'] ?? '',
    macAddress: json['mac_address'] ?? json['macAddress'] ?? '',
    deviceType: json['device_type'] ?? json['deviceType'] ?? 'other',
    storageCapacity: _parseToDouble(json['storage_capacity'] ?? json['storageCapacity'] ?? 0.0),
    freeStorage: _parseToDouble(json['free_storage'] ?? json['freeStorage'] ?? 0.0),
    status: json['status'] ?? 'disconnected',
    lastSeen: json['last_seen'] != null
        ? DateTime.parse(json['last_seen'])
        : json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'])
            : DateTime.now(),
    userId: json['user_id'] != null ? int.parse(json['user_id'].toString()) : null,
  );
}

// Helper method to safely convert various types to double
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip_address': ipAddress,
      'mac_address': macAddress,
      'device_type': deviceType,
      'storage_capacity': storageCapacity,
      'free_storage': freeStorage,
      'status': status,
      'last_seen': lastSeen.toIso8601String(),
      'user_id': userId,
    };
  }
  
  // Get a percentage of storage used
  double get storageUsedPercentage {
    if (storageCapacity <= 0) return 0.0;
    return ((storageCapacity - freeStorage) / storageCapacity * 100).clamp(0.0, 100.0);
  }
  
  // Get human-readable storage capacity
  String get readableStorageCapacity {
    if (storageCapacity >= 1000000000) {
      return '${(storageCapacity / 1000000000).toStringAsFixed(2)} TB';
    } else if (storageCapacity >= 1000000) {
      return '${(storageCapacity / 1000000).toStringAsFixed(2)} GB';
    } else if (storageCapacity >= 1000) {
      return '${(storageCapacity / 1000).toStringAsFixed(2)} MB';
    } else {
      return '${storageCapacity.toStringAsFixed(2)} KB';
    }
  }
  
  // Get human-readable free storage
  String get readableFreeStorage {
    if (freeStorage >= 1000000000) {
      return '${(freeStorage / 1000000000).toStringAsFixed(2)} TB';
    } else if (freeStorage >= 1000000) {
      return '${(freeStorage / 1000000).toStringAsFixed(2)} GB';
    } else if (freeStorage >= 1000) {
      return '${(freeStorage / 1000).toStringAsFixed(2)} MB';
    } else {
      return '${freeStorage.toStringAsFixed(2)} KB';
    }
  }
  
  // Get if device is currently connected
  bool get isConnected => status == 'connected';
}