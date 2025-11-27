import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AdminNotificationService {
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  
  static Stream<List<AdminNotificationItem>> getNotifications() {
    return _databaseRef.child('admin_notifications')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final List<AdminNotificationItem> notifications = [];
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      
      if (data != null) {
        data.forEach((key, value) {
          notifications.add(AdminNotificationItem(
            id: key.toString(),
            title: value['title']?.toString() ?? 'Notifikasi Admin',
            message: value['message']?.toString() ?? '',
            timestamp: value['timestamp'] ?? 0,
            isRead: value['isRead'] == true,
            type: value['type']?.toString() ?? 'info',
          ));
        });
      }
      
      // Sort by timestamp descending (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return notifications;
    });
  }
  
  static Future<void> markAsRead(String notificationId) async {
    await _databaseRef.child('admin_notifications/$notificationId/isRead').set(true);
  }
  
  static Future<void> markAllAsRead() async {
    final notifications = await _databaseRef.child('admin_notifications').once();
    final data = notifications.snapshot.value as Map<dynamic, dynamic>?;
    
    if (data != null) {
      for (var key in data.keys) {
        await _databaseRef.child('admin_notifications/$key/isRead').set(true);
      }
    }
  }
  
  static Future<int> getUnreadCount() async {
    final notifications = await _databaseRef.child('admin_notifications').once();
    final data = notifications.snapshot.value as Map<dynamic, dynamic>?;
    int count = 0;
    
    if (data != null) {
      data.forEach((key, value) {
        if (value['isRead'] != true) {
          count++;
        }
      });
    }
    
    return count;
  }

  // Method untuk membuat notifikasi otomatis untuk admin
  static Future<void> createAutoNotification(String title, String message, String type) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _databaseRef.child('admin_notifications').push().set({
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'isRead': false,
      'type': type,
    });
  }

  // Method khusus untuk notifikasi sistem admin
  static Future<void> createSystemAlert(String nodeId, String alertType, String message) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _databaseRef.child('admin_notifications').push().set({
      'title': 'Alert Sistem - $alertType',
      'message': 'Node $nodeId: $message',
      'timestamp': timestamp,
      'isRead': false,
      'type': 'warning',
      'nodeId': nodeId,
      'alertType': alertType,
    });
  }

  // Method untuk notifikasi user management
  static Future<void> createUserNotification(String action, String userName) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _databaseRef.child('admin_notifications').push().set({
      'title': 'Manajemen User',
      'message': 'User $userName telah $action',
      'timestamp': timestamp,
      'isRead': false,
      'type': 'info',
    });
  }
}

class AdminNotificationItem {
  final String id;
  final String title;
  final String message;
  final int timestamp;
  final bool isRead;
  final String type;

  AdminNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
    required this.type,
  });
  
  String get formattedTime {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) return 'Baru saja';
    if (difference.inHours < 1) return '${difference.inMinutes}m yang lalu';
    if (difference.inDays < 1) return '${difference.inHours}j yang lalu';
    if (difference.inDays < 7) return '${difference.inDays}h yang lalu';
    
    return DateFormat('dd/MM/yyyy').format(date);
  }
  
  Color get typeColor {
    switch (type) {
      case 'warning': return Colors.orange;
      case 'error': return Colors.red;
      case 'success': return Colors.green;
      case 'info': 
      default: return Colors.blue;
    }
  }
  
  IconData get typeIcon {
    switch (type) {
      case 'warning': return Icons.warning;
      case 'error': return Icons.error;
      case 'success': return Icons.check_circle;
      case 'info': 
      default: return Icons.info;
    }
  }
}