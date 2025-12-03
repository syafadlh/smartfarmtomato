// ignore_for_file: undefined_class
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AdminNotificationService {
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  static Stream<List<AdminNotificationItem>> getNotifications() {
    return _databaseRef
        .child('admin_notifications')
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
            nodeId: value['nodeId']?.toString(),
            alertType: value['alertType']?.toString(),
            source: value['source']?.toString() ?? 'system',
          ));
        });
      }

      // Sort by timestamp descending (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return notifications;
    });
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

    return count;
  }

  // Method untuk membuat notifikasi otomatis untuk admin
  static Future<void> createAutoNotification(
      String title, String message, String type,
      {String? source, String? nodeId, String? alertType}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _databaseRef.child('admin_notifications').push().set({
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'isRead': false,
      'type': type,
      'source': source ?? 'system',
      'nodeId': nodeId,
      'alertType': alertType,
    });
  }

  // ========== ALERT HANYA DARI CURRENT_DATA DAN HISTORY_DATA ==========

  // Method khusus untuk alert dari current_data (realtime)
  static Future<void> createRealtimeAlert(
      Map<String, dynamic> sensorData) async {
    final suhu = sensorData['suhu'];
    final statusSuhu = sensorData['status_suhu']?.toString() ?? 'Normal';
    final kelembabanUdara = sensorData['kelembaban_udara'];
    final statusKelembaban = sensorData['status_kelembaban']?.toString() ?? 'Normal';
    final kelembabanTanah = sensorData['kelembaban_tanah'];
    final kategoriTanah = sensorData['kategori_tanah']?.toString() ?? 'Normal';
    final kecerahan = sensorData['kecerahan'];
    final kategoriCahaya = sensorData['kategori_cahaya']?.toString() ?? 'Normal';

    // Hanya buat notifikasi jika ada kondisi KRITIS
    if (statusSuhu.contains('panas') || statusSuhu.contains('bahaya')) {
      await createAutoNotification(
        '🔥 Alert Suhu - Real-time',
        'Suhu mencapai ${suhu?.toStringAsFixed(1)}°C - Status: $statusSuhu',
        'error',
        source: 'current_data',
        alertType: 'temperature',
      );
    }

    if (statusKelembaban.contains('tinggi') && kelembabanUdara >= 80) {
      await createAutoNotification(
        '💨 Alert Kelembaban Udara - Real-time',
        'Kelembaban Udara: ${kelembabanUdara?.toStringAsFixed(1)}% - Status: $statusKelembaban',
        'warning',
        source: 'current_data',
        alertType: 'humidity',
      );
    }

    // Hanya untuk tanah SANGAT KERING atau SANGAT BASAH
    if (kategoriTanah.contains('SANGAT KERING') || 
        kategoriTanah.contains('SANGAT BASAH')) {
      await createAutoNotification(
        '💧 Alert Kelembaban Tanah - Real-time',
        'Kelembaban Tanah: ${kelembabanTanah?.toStringAsFixed(1)}% - Kategori: $kategoriTanah',
        'error',
        source: 'current_data',
        alertType: 'soil_moisture',
      );
    }

    // Hanya untuk cahaya GELAP atau SANGAT TERANG
    if (kategoriCahaya.contains('GELAP') || 
        kategoriCahaya.contains('SANGAT TERANG')) {
      await createAutoNotification(
        '💡 Alert Intensitas Cahaya - Real-time',
        'Kecerahan: ${kecerahan?.toStringAsFixed(0)} - Kategori: $kategoriCahaya',
        'warning',
        source: 'current_data',
        alertType: 'light',
      );
    }
  }

  // Method untuk alert dari history_data (hanya kondisi kritis)
  static Future<void> createHistoryAlert(
      Map<String, dynamic> historyData, String key) async {
    final kategoriTanah = historyData['kategori_tanah']?.toString();
    
    // Hanya buat notifikasi untuk kondisi tanah KRITIS dari history
    if (kategoriTanah != null && 
        (kategoriTanah.contains('SANGAT KERING') || 
         kategoriTanah.contains('SANGAT BASAH'))) {
      
      final kelembabanTanah = historyData['kelembaban_tanah'];
      final datetime = historyData['datetime']?.toString() ?? key;
      
      // Cek apakah sudah ada notifikasi serupa dalam 10 menit terakhir
      final tenMinutesAgo = DateTime.now().subtract(Duration(minutes: 10)).millisecondsSinceEpoch;
      final recentNotifications = await _getRecentAlerts('soil_moisture_history', tenMinutesAgo);
      
      if (recentNotifications.isEmpty) {
        await createAutoNotification(
          '📊 Alert History - Kelembaban Tanah',
          'Data history: Tanah $kategoriTanah (${kelembabanTanah?.toStringAsFixed(1)}%) pada $datetime',
          'error',
          source: 'history_data',
          alertType: 'soil_moisture_history',
        );
      }
    }
  }

  // Helper untuk mendapatkan alert terbaru
  static Future<List<Map<String, dynamic>>> _getRecentAlerts(String alertType, int sinceTimestamp) async {
    final snapshot = await _databaseRef
        .child('admin_notifications')
        .orderByChild('timestamp')
        .startAt(sinceTimestamp)
        .once();
    
    final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;
    final List<Map<String, dynamic>> alerts = [];
    
    if (data != null) {
      data.forEach((key, value) {
        if (value['alertType'] == alertType && value['isRead'] != true) {
          alerts.add({
            'id': key.toString(),
            'timestamp': value['timestamp'],
            'message': value['message'],
          });
        }
      });
    }
    
    return alerts;
  }

  // ========== NOTIFIKASI PENDAFTARAN USER ==========

  // Method untuk notifikasi pendaftaran petani baru
  static Future<void> notifyNewFarmerRegistration(
      String farmerName, String farmerEmail, String farmerId) async {
    await createAutoNotification(
      '👤 Pendaftaran Petani Baru',
      '$farmerName ($farmerEmail) telah mendaftar sebagai petani di TomaFarm',
      'success',
      source: 'registration',
      alertType: 'new_farmer',
    );
  }

  // Method untuk notifikasi aktivitas user lainnya
  static Future<void> createUserActivityNotification(
      String userName, String action, String details) async {
    String title = '';
    String type = 'info';
    
    switch (action) {
      case 'login':
        title = '🔑 User Login';
        type = 'info';
        break;
      case 'logout':
        title = '🚪 User Logout';
        type = 'info';
        break;
      case 'profile_update':
        title = '✏️ Update Profil';
        type = 'info';
        break;
      case 'password_change':
        title = '🔐 Ganti Password';
        type = 'warning';
        break;
    }
    
    await createAutoNotification(
      title,
      '$userName telah $action. $details',
      type,
      source: 'user_activity',
      alertType: action,
    );
  }

  // ========== NOTIFIKASI SISTEM LAINNYA ==========

  // Notifikasi maintenance sistem
  static Future<void> createSystemMaintenanceNotification(
      String component, String status) async {
    await createAutoNotification(
      '🔧 Maintenance Sistem',
      'Komponen $component dalam status: $status',
      'info',
      source: 'system',
      alertType: 'maintenance',
    );
  }

  // Notifikasi backup data
  static Future<void> createDataBackupNotification(
      String backupType, bool success) async {
    await createAutoNotification(
      '💾 Backup Data',
      'Backup $backupType ${success ? 'berhasil' : 'gagal'}',
      success ? 'success' : 'error',
      source: 'system',
      alertType: 'backup',
    );
  }

  // ========== SETUP LISTENERS ==========

  // Setup listener untuk current_data (realtime alerts)
  static void setupRealtimeDataListener() {
    final DatabaseReference databaseRef = FirebaseDatabase.instance.ref();
    
    databaseRef.child('current_data').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final Map<String, dynamic> sensorData = {
          'suhu': _parseDouble(data['suhu']),
          'status_suhu': data['status_suhu']?.toString() ?? 'Normal',
          'kelembaban_udara': _parseDouble(data['kelembaban_udara']),
          'status_kelembaban': data['status_kelembaban']?.toString() ?? 'Normal',
          'kelembaban_tanah': _parseDouble(data['kelembaban_tanah']),
          'kategori_tanah': data['kategori_tanah']?.toString() ?? 'Normal',
          'kecerahan': _parseDouble(data['kecerahan']),
          'kategori_cahaya': data['kategori_cahaya']?.toString() ?? 'Normal',
        };
        
        createRealtimeAlert(sensorData);
      }
    });
  }

  // Setup listener untuk history_data
  static void setupHistoryDataListener() {
    final DatabaseReference databaseRef = FirebaseDatabase.instance.ref();
    
    databaseRef.child('history_data')
      .limitToLast(20) // Hanya data terakhir
      .onChildAdded
      .listen((DatabaseEvent event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          final Map<String, dynamic> historyData = data.cast<String, dynamic>();
          createHistoryAlert(historyData, event.snapshot.key ?? '');
        }
      });
  }

  // Setup listener untuk pendaftaran user baru
  static void setupUserRegistrationListener() {
    final DatabaseReference databaseRef = FirebaseDatabase.instance.ref();
    
    databaseRef.child('users')
      .orderByChild('createdAt')
      .limitToLast(10)
      .onChildAdded
      .listen((DatabaseEvent event) {
        final newUser = event.snapshot.value as Map<dynamic, dynamic>?;
        if (newUser != null) {
          final role = newUser['role']?.toString() ?? '';
          final name = newUser['name']?.toString() ?? 'User Baru';
          final email = newUser['email']?.toString() ?? '';
          final userId = event.snapshot.key ?? '';
          
          // Hanya kirim notifikasi untuk petani baru
          if (role == 'farmer') {
            notifyNewFarmerRegistration(name, email, userId);
          }
        }
      });
  }

  // Helper function untuk parse double
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class AdminNotificationItem {
  final String id;
  final String title;
  final String message;
  final int timestamp;
  final bool isRead;
  final String type;
  final String? nodeId;
  final String? alertType;
  final String? source;

  AdminNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
    required this.type,
    this.nodeId,
    this.alertType,
    this.source,
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
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      case 'success':
        return Colors.green;
      case 'info':
      default:
        return Colors.blue;
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
}