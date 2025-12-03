// ignore_for_file: undefined_class
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AdminNotificationService {
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  // Warna konsisten
  static const Color _primaryColor = Color(0xFF006B5D);
  static const Color _secondaryColor = Color(0xFFB8860B);
  static const Color _tertiaryColor = Color(0xFF558B2F);
  static const Color _blueColor = Color(0xFF1A237E);
  static const Color _greenColor = Color(0xFF2E7D32);
  static const Color _accentColor = Color(0xFFB71C1C);

  // Debug monitoring
  static void startMonitoring() {
    _databaseRef.child('notifications').onValue.listen((event) {
      print('🎯 REAL-TIME UPDATE DETECTED');
      final data = event.snapshot.value;
      if (data != null) {
        print('📊 Total notifications: ${(data as Map).length}');
      }
    });
  }

  static Stream<List<NotificationItem>> getNotifications() {
    print('🔔 Starting notifications stream...');

    return _databaseRef
        .child('admin_notifications')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final List<NotificationItem> notifications = [];
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      print('📨 Received ${data?.length ?? 0} notifications from Firebase');

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

      print('✅ Processed ${notifications.length} notifications');
      return notifications;
    });
  }

  static int _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now().millisecondsSinceEpoch;
    }

    int ts = 0;

    if (timestamp is int) {
      ts = timestamp;
    } else if (timestamp is String) {
      ts = int.tryParse(timestamp) ?? 0;
    }

    // ---- BLOKIR VALUE INVALID ----
    if (ts <= 0) {
      print('⚠ TIMESTAMP INVALID DETECTED → forced current time');
      return DateTime.now().millisecondsSinceEpoch;
    }

    // ---- convert seconds → milliseconds ----
    if (ts < 100000000000) {
      ts *= 1000;
    }

    return ts;
  }

  static Future<void> markAsRead(String notificationId) async {
    await _databaseRef
        .child('admin_notifications/$notificationId/isRead')
        .set(true);
  }

  static Future<void> markAllAsRead() async {
    final notifications =
        await _databaseRef.child('admin_notifications').once();
    final data = notifications.snapshot.value as Map<dynamic, dynamic>?;

    if (data != null) {
      for (var key in data.keys) {
        await _databaseRef.child('admin_notifications/$key/isRead').set(true);
      }
      print('✅ Marked all ${data.length} notifications as read');
    }
  }

  static Future<int> getUnreadCount() async {
    final notifications =
        await _databaseRef.child('admin_notifications').once();
    final data = notifications.snapshot.value as Map<dynamic, dynamic>?;
    int count = 0;

    if (data != null) {
      data.forEach((key, value) {
        if (value['isRead'] != true) {
          count++;
        }
      });
    }

    print('📊 Unread count: $count');
    return count;
  }

  // Method untuk membuat notifikasi otomatis untuk admin
  static Future<void> createAutoNotification(
      String title, String message, String type,
      {String? source, String? nodeId, String? alertType}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newRef = _databaseRef.child('admin_notifications').push();

    await newRef.set({
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'createdAt': DateTime.now().toIso8601String(), // Tambahkan createdAt
      'isRead': false,
      'type': type,
    });
  }

  // Method khusus untuk notifikasi sistem admin
  static Future<void> createSystemAlert(
      String nodeId, String alertType, String message) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _databaseRef.child('admin_notifications').push().set({
      'title': 'Alert Sistem - $alertType',
      'message': 'Node $nodeId: $message',
      'timestamp': timestamp,
      'isRead': false,
      'type': 'warning',
      'nodeId': nodeId,
    });

    print('🔔 System alert created: $title (Key: ${newRef.key})');
  }

  // Method untuk notifikasi penyiraman
  static Future<void> createWateringNotification(
      bool isWatering, double soilMoisture, String plantStage) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    String title =
        isWatering ? '🚰 Penyiraman Dimulai' : '✅ Penyiraman Selesai';
    String type = isWatering ? 'info' : 'success';

    String message = isWatering
        ? 'Pompa menyala untuk menyiram tanaman tomat\nKelembaban tanah: ${soilMoisture.toStringAsFixed(1)}%\nTahapan: $plantStage'
        : 'Penyiraman selesai\nKelembaban tanah: ${soilMoisture.toStringAsFixed(1)}%\nTahapan: $plantStage';

    final newRef = _databaseRef.child('admin_notifications').push();
    await newRef.set({
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'createdAt': DateTime.now().toIso8601String(),
      'isRead': false,
      'type': type,
    });

    print('🔔 Watering notification created: $title');
  }

  // Method untuk notifikasi user management
  static Future<void> createUserNotification(
      String action, String userName) async {
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

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final int timestamp;
  final String? createdAt; // Tambahkan field untuk createdAt
  final bool isRead;
  final String type;
  final String? nodeId;
  final String? alertType;
  final String? source;

  // Warna konsisten dengan aplikasi
  static const Color _primaryColor = Color(0xFF006B5D);
  static const Color _secondaryColor = Color(0xFFB8860B);
  static const Color _tertiaryColor = Color(0xFF558B2F);
  static const Color _blueColor = Color(0xFF1A237E);
  static const Color _greenColor = Color(0xFF2E7D32);
  static const Color _accentColor = Color(0xFFB71C1C);

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.createdAt,
    required this.isRead,
    required this.type,
    this.nodeId,
    this.alertType,
    this.source,
  });

  // PERBAIKAN: Gunakan createdAt jika ada, jika tidak gunakan timestamp
  DateTime get dateTime {
    if (createdAt != null) {
      try {
        return DateTime.parse(createdAt!);
      } catch (e) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Baru saja';
    if (difference.inHours < 1) return '${difference.inMinutes}m yang lalu';
    if (difference.inDays < 1) return '${difference.inHours}j yang lalu';
    if (difference.inDays < 7) return '${difference.inDays}h yang lalu';

    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  String get fullFormattedTime {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  // Tambahkan getter untuk tanggal yang diformat seperti contoh
  String get systemFormattedDate {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  Color get typeColor {
    switch (type) {
      case 'warning':
        return _secondaryColor;
      case 'error':
        return _accentColor;
      case 'success':
        return _tertiaryColor;
      case 'info':
      default:
        return _primaryColor;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'success':
        return Icons.check_circle;
      case 'info':
      default:
        return Icons.info;
    }
  }

  @override
  String toString() {
    return 'NotificationItem{id: $id, title: $title, date: ${dateTime.toString()}, isRead: $isRead}';
  }
}