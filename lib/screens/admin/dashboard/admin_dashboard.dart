import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'admin_notifications.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  
  // Data statistik
  int _totalFarmers = 0;
  int _totalLands = 0;
  int _activeNodes = 0;
  int _criticalAlerts = 0;
  int _totalHarvests = 0;
  double _averageYield = 0.0;
  
  // Data sensor dari semua lahan
  Map<String, dynamic> _overallSensorData = {
    'temperature': 0.0,
    'humidity': 0.0,
    'soilMoisture': 0.0,
    'lightIntensity': 0.0,
  };

  // Status sistem
  Map<String, dynamic> _systemStatus = {
    'pump': false,
    'light': false,
    'autoMode': true,
  };

  // Notifikasi
  int _unreadNotifications = 0;
  bool _notificationsEnabled = true;
  
  // Data terbaru
  List<Map<String, dynamic>> _recentActivities = [];
  List<Map<String, dynamic>> _systemAlerts = [];
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
    _loadNotificationSettings();
    _setupNotificationListener();
  }

  void _initializeDashboard() {
    _loadStatistics();
    _loadOverallSensorData();
    _loadSystemStatus();
    _loadRecentActivities();
    _loadSystemAlerts();
  }

  void _loadNotificationSettings() async {
    setState(() {
      _notificationsEnabled = true;
    });
  }

  void _setupNotificationListener() {
    if (_notificationsEnabled) {
      AdminNotificationService.getNotifications().listen((notifications) {
        final unread = notifications.where((n) => !n.isRead).length;
        setState(() {
          _unreadNotifications = unread;
        });
      });
    }
  }

  void _loadStatistics() {
    // Total petani
    _databaseRef.child('users').orderByChild('role').equalTo('farmer').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _totalFarmers = data.length;
        });
      }
    });

    // Total lahan/nodes
    _databaseRef.child('nodes').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _totalLands = data.length;
          _activeNodes = data.values.where((node) => 
            node['status'] == 'online').length;
        });
      }
    });

    // Alert kritis
    _databaseRef.child('alerts')
      .orderByChild('severity')
      .equalTo('high')
      .onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _criticalAlerts = data.length;
        });
      }
    });

    // Data panen
    _databaseRef.child('harvests').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        double totalYield = 0;
        int harvestCount = 0;
        
        data.forEach((key, value) {
          totalYield += (value['yield'] ?? 0).toDouble();
          harvestCount++;
        });
        
        setState(() {
          _totalHarvests = harvestCount;
          _averageYield = harvestCount > 0 ? totalYield / harvestCount : 0.0;
        });
      }
    });
  }

  void _loadOverallSensorData() {
    _databaseRef.child('sensorData').onValue.listen((event) {
      try {
        final data = event.snapshot.value;
        if (data != null && data is Map) {
          setState(() {
            _overallSensorData = {
              'temperature': _toDouble(data['temperature']),
              'humidity': _toDouble(data['humidity']),
              'soilMoisture': _toDouble(data['soilMoisture']),
              'lightIntensity': _toDouble(data['lightIntensity']),
            };
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error reading sensor data: $e');
      }
    });
  }

  void _loadSystemStatus() {
    _databaseRef.child('control').onValue.listen((event) {
      try {
        final data = event.snapshot.value;
        if (data != null && data is Map) {
          setState(() {
            _systemStatus = {
              'pump': data['pump'] == true,
              'light': data['light'] == true,
              'autoMode': data['autoMode'] == true,
            };
          });
        }
      } catch (e) {
        print('Error reading control data: $e');
      }
    });
  }

  void _loadRecentActivities() {
    // Aktivitas terbaru dari semua petani
    setState(() {
      _recentActivities = [
        {
          'user': 'Budi Santoso',
          'action': 'Menanam tomat',
          'time': '2 jam lalu',
          'icon': Icons.agriculture,
          'color': Colors.green,
        },
        {
          'user': 'Siti Rahayu',
          'action': 'Mengaktifkan irigasi',
          'time': '4 jam lalu',
          'icon': Icons.water_drop,
          'color': Colors.blue,
        },
        {
          'user': 'Ahmad Wijaya',
          'action': 'Panen tomat',
          'time': '6 jam lalu',
          'icon': Icons.emoji_events,
          'color': Colors.orange,
        },
        {
          'user': 'Maria Dewi',
          'action': 'Update pengaturan',
          'time': '8 jam lalu',
          'icon': Icons.settings,
          'color': Colors.purple,
        },
      ];
    });
  }

  void _loadSystemAlerts() {
    _databaseRef.child('alerts')
      .orderByChild('timestamp')
      .limitToLast(5)
      .onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      final List<Map<String, dynamic>> alerts = [];
      
      if (data != null) {
        data.forEach((key, value) {
          alerts.add({
            'id': key,
            'title': value['title'] ?? 'Alert',
            'message': value['message'] ?? '',
            'severity': value['severity'] ?? 'medium',
            'nodeId': value['nodeId'],
            'timestamp': value['timestamp'],
          });
        });
        
        setState(() {
          _systemAlerts = alerts.reversed.toList();
          _isLoading = false;
        });
      }
    });

    // Timeout loading
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _getStatusMessage(String type, double value) {
    switch (type) {
      case 'temperature':
        return value > 30 ? 'Panas' : value < 20 ? 'Dingin' : 'Optimal';
      case 'humidity':
        return value > 80 ? 'Lembab' : value < 40 ? 'Kering' : 'Normal';
      case 'soilMoisture':
        return value < 30 ? 'Kering' : value > 70 ? 'Basah' : 'Optimal';
      case 'lightIntensity':
        return value > 800 ? 'Terang' : value < 300 ? 'Redup' : 'Cukup';
      default:
        return 'Normal';
    }
  }

  Color _getStatusColor(String type, double value) {
    switch (type) {
      case 'temperature':
        return value > 30 ? Colors.orange : value < 20 ? Colors.blue : Colors.green;
      case 'humidity':
        return value > 80 ? Colors.orange : value < 40 ? Colors.red : Colors.green;
      case 'soilMoisture':
        return value < 30 ? Colors.red : value > 70 ? Colors.blue : Colors.green;
      case 'lightIntensity':
        return value < 300 ? Colors.orange : Colors.green;
      default:
        return Colors.green;
    }
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNotificationsSheet(),
    );
  }

  Widget _buildNotificationsSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  '🔔 Notifikasi Sistem',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_unreadNotifications > 0)
                  TextButton(
                    onPressed: () {
                      AdminNotificationService.markAllAsRead();
                      setState(() {
                        _unreadNotifications = 0;
                      });
                    },
                    child: const Text('Tandai Semua Dibaca'),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AdminNotificationItem>>(
              stream: _notificationsEnabled 
                  ? AdminNotificationService.getNotifications()
                  : Stream.value([]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Tidak ada notifikasi',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                final notifications = snapshot.data!;
                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationItem(notification);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(AdminNotificationItem notification) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.grey[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? Colors.grey[200]! : Colors.blue[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: notification.typeColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              notification.typeIcon,
              color: notification.typeColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.formattedTime,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (!notification.isRead)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.blue),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  size: 50,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'TomaFarm Admin',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Memuat dashboard...',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _isLoading = true;
            });
            await Future.delayed(const Duration(seconds: 1));
            _initializeDashboard();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStatsGrid(),
                const SizedBox(height: 24),
                _buildSensorGrid(),
                const SizedBox(height: 24),
                _buildSystemStatus(),
                const SizedBox(height: 24),
                _buildRecentActivities(),
                const SizedBox(height: 24),
                _buildSystemAlerts(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard Administrator',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Smart Farming Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            Stack(
              children: [
                IconButton(
                  onPressed: _showNotifications,
                  icon: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications, color: Colors.blue),
                  ),
                ),
                if (_unreadNotifications > 0 && _notificationsEnabled)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadNotifications > 9 ? '9+' : _unreadNotifications.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Overview sistem dan monitoring semua lahan tomat',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 Statistik Sistem',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildStatCard(
              icon: Icons.people,
              title: 'Total Petani',
              value: '$_totalFarmers',
              unit: 'Orang',
              status: _totalFarmers > 0 ? 'Aktif' : 'Tidak Ada',
              color: Colors.blue,
              statusColor: _totalFarmers > 0 ? Colors.green : Colors.grey,
              backgroundColor: Colors.blue[50]!,
            ),
            _buildStatCard(
              icon: Icons.agriculture,
              title: 'Total Lahan',
              value: '$_totalLands',
              unit: 'Lahan',
              status: 'Terdaftar',
              color: Colors.green,
              statusColor: Colors.green,
              backgroundColor: Colors.green[50]!,
            ),
            _buildStatCard(
              icon: Icons.wifi,
              title: 'Node Aktif',
              value: '$_activeNodes',
              unit: 'Node',
              status: _activeNodes == _totalLands ? 'Optimal' : 'Perhatian',
              color: Colors.purple,
              statusColor: _activeNodes == _totalLands ? Colors.green : Colors.orange,
              backgroundColor: Colors.purple[50]!,
            ),
            _buildStatCard(
              icon: Icons.warning,
              title: 'Alert Kritis',
              value: '$_criticalAlerts',
              unit: 'Alert',
              status: _criticalAlerts > 0 ? 'Perhatian' : 'Aman',
              color: Colors.red,
              statusColor: _criticalAlerts > 0 ? Colors.red : Colors.green,
              backgroundColor: Colors.red[50]!,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required String status,
    required Color color,
    required Color statusColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.2,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🌡️ Data Sensor Rata-rata',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildSensorCard(
              icon: Icons.thermostat,
              title: 'Suhu',
              value: '${_overallSensorData['temperature']?.toStringAsFixed(1)}°C',
              unit: 'Celcius',
              status: _getStatusMessage('temperature', _overallSensorData['temperature']),
              color: Colors.red,
              statusColor: _getStatusColor('temperature', _overallSensorData['temperature']),
              backgroundColor: Colors.red[50]!,
            ),
            _buildSensorCard(
              icon: Icons.water_drop,
              title: 'Kelembapan Udara',
              value: '${_overallSensorData['humidity']?.toStringAsFixed(1)}%',
              unit: 'Persen',
              status: _getStatusMessage('humidity', _overallSensorData['humidity']),
              color: Colors.blue,
              statusColor: _getStatusColor('humidity', _overallSensorData['humidity']),
              backgroundColor: Colors.blue[50]!,
            ),
            _buildSensorCard(
              icon: Icons.grass,
              title: 'Kelembapan Tanah',
              value: '${_overallSensorData['soilMoisture']?.toStringAsFixed(1)}%',
              unit: 'Persen',
              status: _getStatusMessage('soilMoisture', _overallSensorData['soilMoisture']),
              color: Colors.brown,
              statusColor: _getStatusColor('soilMoisture', _overallSensorData['soilMoisture']),
              backgroundColor: Colors.brown[50]!,
            ),
            _buildSensorCard(
              icon: Icons.light_mode,
              title: 'Intensitas Cahaya',
              value: '${_overallSensorData['lightIntensity']?.toStringAsFixed(0)}',
              unit: 'Lux',
              status: _getStatusMessage('lightIntensity', _overallSensorData['lightIntensity']),
              color: Colors.amber,
              statusColor: _getStatusColor('lightIntensity', _overallSensorData['lightIntensity']),
              backgroundColor: Colors.amber[50]!,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required String status,
    required Color color,
    required Color statusColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.2,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.engineering, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Status Sistem',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSystemItem(
                icon: Icons.water_drop,
                title: 'Pompa Air',
                status: _systemStatus['pump'] ? 'ON' : 'OFF',
                statusColor: _systemStatus['pump'] ? Colors.green : Colors.red,
                mode: _systemStatus['autoMode'] ? 'Auto' : 'Manual',
                backgroundColor: Colors.blue[50]!,
              ),
              const SizedBox(width: 12),
              _buildSystemItem(
                icon: Icons.lightbulb,
                title: 'Lampu Tumbuh',
                status: _systemStatus['light'] ? 'ON' : 'OFF',
                statusColor: _systemStatus['light'] ? Colors.green : Colors.red,
                mode: _systemStatus['autoMode'] ? 'Auto' : 'Manual',
                backgroundColor: Colors.amber[50]!,
              ),
              const SizedBox(width: 12),
              _buildSystemItem(
                icon: _systemStatus['autoMode'] ? Icons.auto_mode : Icons.engineering,
                title: 'Mode Sistem',
                status: _systemStatus['autoMode'] ? 'Auto' : 'Manual',
                statusColor: _systemStatus['autoMode'] ? Colors.blue : Colors.orange,
                mode: 'Aktif',
                backgroundColor: Colors.purple[50]!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemItem({
    required IconData icon,
    required String title,
    required String status,
    required Color statusColor,
    required String mode,
    required Color backgroundColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: statusColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Text(
                mode,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Aktivitas Terbaru',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._recentActivities.map((activity) => _buildActivityItem(activity)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activity['color'].withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(activity['icon'], color: activity['color'], size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['user'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  activity['action'],
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            activity['time'],
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemAlerts() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Alert Sistem',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _systemAlerts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, size: 40, color: Colors.green),
                      SizedBox(height: 8),
                      Text(
                        'Tidak ada alert sistem',
                        style: TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: _systemAlerts.take(3).map((alert) => 
                    _buildAlertItem(alert)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert) {
    final severity = alert['severity'];
    final color = _getSeverityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  alert['message'],
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.blue;
      default: return Colors.grey;
    }
  }
}