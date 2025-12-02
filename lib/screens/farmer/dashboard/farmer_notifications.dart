// ignore_for_file: undefined_class, unused_field
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class NotificationService {
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
        .child('notifications')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final List<NotificationItem> notifications = [];
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      print('📨 Received ${data?.length ?? 0} notifications from Firebase');

      if (data != null) {
        data.forEach((key, value) {
          try {
            final timestamp = _parseTimestamp(value['timestamp']);

            // Debug info
            print('🔍 Notification: ${value['title']} - Timestamp: $timestamp');

            notifications.add(NotificationItem(
              id: key.toString(),
              title: value['title']?.toString() ?? 'Notifikasi',
              message: value['message']?.toString() ?? '',
              timestamp: timestamp,
              isRead: value['isRead'] == true,
              type: value['type']?.toString() ?? 'info',
            ));
          } catch (e) {
            print('❌ Error parsing notification $key: $e');
          }
        });
      }

      // Sort by timestamp descending (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      print('✅ Processed ${notifications.length} notifications');
      return notifications;
    });
  }

  // Helper function untuk parse timestamp
  static int _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      print('⚠ Timestamp is null, using current time');
      return DateTime.now().millisecondsSinceEpoch;
    }

    if (timestamp is int) {
      // Validasi timestamp (harus dalam milidetik, bukan detik)
      if (timestamp < 1000000000000) {
        // Jika timestamp dalam detik, konversi ke milidetik
        timestamp = timestamp * 1000;
        print('🕒 Converted seconds to milliseconds: $timestamp');
      }
      return timestamp;
    } else if (timestamp is String) {
      final parsed = int.tryParse(timestamp);
      if (parsed != null) {
        if (parsed < 1000000000000) {
          final converted = parsed * 1000;
          print('🕒 Converted string seconds to milliseconds: $converted');
          return converted;
        }
        return parsed;
      }
      print('⚠ Failed to parse timestamp string: $timestamp');
      return DateTime.now().millisecondsSinceEpoch;
    } else {
      print('⚠ Unknown timestamp type: ${timestamp.runtimeType}');
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  static Future<void> markAsRead(String notificationId) async {
    await _databaseRef.child('notifications/$notificationId/isRead').set(true);
    print('✅ Marked as read: $notificationId');
  }

  static Future<void> markAllAsRead() async {
    final notifications = await _databaseRef.child('notifications').once();
    final data = notifications.snapshot.value as Map<dynamic, dynamic>?;

    if (data != null) {
      for (var key in data.keys) {
        await _databaseRef.child('notifications/$key/isRead').set(true);
      }
      print('✅ Marked all ${data.length} notifications as read');
    }
  }

  static Future<int> getUnreadCount() async {
    final notifications = await _databaseRef.child('notifications').once();
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

  // Method untuk membuat notifikasi otomatis
  static Future<void> createAutoNotification(
      String title, String message, String type) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newRef = _databaseRef.child('notifications').push();

    await newRef.set({
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'isRead': false,
      'type': type,
    });

    print('🔔 Created auto notification: $title (Key: ${newRef.key})');
  }

  // Method khusus untuk notifikasi data sensor dari Wokwi
  static Future<void> createSensorNotification(
      double temperature,
      double humidity,
      double soilMoisture,
      double brightness,
      String soilCategory,
      String airHumStatus,
      String tempStatus,
      String plantStage,
      int plantAgeDays,
      bool isPumpOn) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Tentukan jenis notifikasi berdasarkan kondisi
    String type = 'info';
    String title = '🌱 Data Sensor Tomat';

    // Deteksi kondisi yang perlu perhatian
    if (temperature > 32.0) {
      type = 'warning';
      title = '🔥 Suhu Terlalu Tinggi';
    } else if (temperature < 15.0) {
      type = 'warning';
      title = '❄ Suhu Terlalu Rendah';
    } else if (soilMoisture < 30.0) {
      type = 'warning';
      title = '🏜 Tanah Sangat Kering';
    } else if (soilMoisture > 80.0) {
      type = 'warning';
      title = '💦 Tanah Terlalu Basah';
    } else if (humidity > 85.0) {
      type = 'warning';
      title = '💨 Kelembaban Tinggi';
    } else if (isPumpOn) {
      type = 'success';
      title = '🚰 Pompa Menyala';
    }

    // Format pesan notifikasi yang informatif
    String message = '';
    message += '🌡 Suhu: ${temperature.toStringAsFixed(1)}°C\n';
    message += '💧 Udara: ${humidity.toStringAsFixed(1)}% ($airHumStatus)\n';
    message +=
        '🌱 Tanah: ${soilMoisture.toStringAsFixed(1)}% ($soilCategory)\n';
    message += '💡 Cahaya: ${brightness.toStringAsFixed(1)}%\n';
    message += '📅 Tahap: $plantStage (Hari $plantAgeDays)\n';
    message += '🚰 Pompa: ${isPumpOn ? 'ON' : 'OFF'}';

    final newRef = _databaseRef.child('notifications').push();
    await newRef.set({
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'isRead': false,
      'type': type,
    });

    print('🔔 Sensor notification created: $title (Key: ${newRef.key})');
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

    final newRef = _databaseRef.child('notifications').push();
    await newRef.set({
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'isRead': false,
      'type': type,
    });

    print('🔔 Watering notification created: $title');
  }

  // Test function untuk debugging
  static Future<void> sendTestNotification() async {
    await createAutoNotification(
        '🧪 Test Notification',
        'Ini adalah notifikasi test dari Flutter\nWaktu: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
        'info');
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final int timestamp;
  final bool isRead;
  final String type;

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

    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String get fullFormattedTime {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
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
    return 'NotificationItem{id: $id, title: $title, timestamp: $timestamp, isRead: $isRead}';
  }
}
