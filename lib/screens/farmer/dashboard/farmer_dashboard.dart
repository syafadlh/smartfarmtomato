import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'farmer_notifications.dart';
import 'simple_chart.dart';
import '../control/farmer_control.dart';  
import '../history/farmer_history.dart';  
import '../settings/farmer_settings.dart'; 

class FarmerDashboardScreen extends StatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> {
  late DatabaseReference _databaseRef;
  bool _isLoading = true;
  int _unreadNotifications = 0;
  bool _notificationsEnabled = true;

  Map<String, dynamic> sensorData = {
    'suhu': 0.0,
    'status_suhu': 'Normal',
    'kelembaban_udara': 0.0,
    'status_kelembaban': 'Normal',
    'kelembaban_tanah': 0.0,
    'kategori_tanah': 'Normal',
    'kecerahan': 0.0,
    'kategori_cahaya': 'Normal',
  };

  Map<String, dynamic> actuatorData = {
    'pump': false,
    'light': false,
    'autoMode': true,
  };

  List<ChartData> temperatureData = [];
  List<ChartData> humidityData = [];
  List<ChartData> soilMoistureData = [];

  @override
  void initState() {
    super.initState();
    _databaseRef = FirebaseDatabase.instance.ref();
    _setupRealtimeListener();
    _loadNotificationSettings();
    _setupNotificationListener();
  }

  void _loadNotificationSettings() async {
    setState(() {
      _notificationsEnabled = true;
    });
  }

  void _setupNotificationListener() {
    if (_notificationsEnabled) {
      NotificationService.getNotifications().listen((notifications) {
        final unread = notifications.where((n) => !n.isRead).length;
        setState(() {
          _unreadNotifications = unread;
        });
      });
    }
  }

  void _setupRealtimeListener() {
    _databaseRef.child('current_data').onValue.listen((event) {
      try {
        final data = event.snapshot.value;

        if (data != null && data is Map) {
          print('📡 Received sensor data: $data');
          
          setState(() {
            sensorData = {
              'suhu': _toDouble(data['suhu']),
              'status_suhu': data['status_suhu']?.toString() ?? 'Normal',
              'kelembaban_udara': _toDouble(data['kelembaban_udara']),
              'status_kelembaban': data['status_kelembaban']?.toString() ?? 'Normal',
              'kelembaban_tanah': _toDouble(data['kelembaban_tanah']),
              'kategori_tanah': data['kategori_tanah']?.toString() ?? 'Normal',
              'kecerahan': _toDouble(data['kecerahan']),
              'kategori_cahaya': data['kategori_cahaya']?.toString() ?? 'Normal',
            };
            _isLoading = false;
          });

          _updateChartData();
        }
      } catch (e) {
        print('❌ Error reading sensor data: $e');
        final data = event.snapshot.value;
        if (data != null && data is Map) {
          print('🔍 Available keys: ${data.keys}');
        }
      }
    });

    _databaseRef.child('control').onValue.listen((event) {
      try {
        final data = event.snapshot.value;

        if (data != null && data is Map) {
          setState(() {
            actuatorData = {
              'pump': data['pump'] == true,
              'light': data['light'] == true,
              'autoMode': data['autoMode'] == true,
            };
          });
        }
      } catch (e) {
        print('❌ Error reading control data: $e');
      }
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        print('⚠️ No data received, using default values');
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _updateChartData() {
    final now = DateTime.now();
    final timeLabel = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    setState(() {
      temperatureData.add(ChartData(timeLabel, sensorData['suhu']));
      humidityData.add(ChartData(timeLabel, sensorData['kelembaban_udara']));
      soilMoistureData.add(ChartData(timeLabel, sensorData['kelembaban_tanah']));
      
      if (temperatureData.length > 10) {
        temperatureData.removeAt(0);
        humidityData.removeAt(0);
        soilMoistureData.removeAt(0);
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'panas':
      case 'tinggi':
      case 'kering':
      case 'bahaya':
      case 'suhu > max toleransi (panas)':
      case 'rh tinggi':
      case 'risiko jamur':
        return Colors.orange;
      case 'dingin':
      case 'rendah':
      case 'sangat kering':
      case 'suhu < min toleransi (dingin)':
      case 'rh rendah':
        return Colors.blue;
      case 'lembab':
      case 'basah':
      case 'sangat basah':
        return Colors.blue;
      case 'optimal':
      case 'normal':
      case 'baik':
      case 'cukup':
      case 'ideal':
      case 'suhu siang ideal':
      case 'suhu malam ideal':
      case 'rh ideal':
        return Colors.green;
      case 'terang':
        return Colors.amber;
      case 'redup':
      case 'remang':
        return Colors.orange;
      case 'gelap':
        return Colors.grey;
      default:
        return Colors.green;
    }
  }

  String _getStatusDescription(String type, String status) {
    switch (type) {
      case 'suhu':
        switch (status.toLowerCase()) {
          case 'panas':
          case 'suhu > max toleransi (panas)':
            return 'Suhu terlalu tinggi untuk tanaman tomat';
          case 'dingin':
          case 'suhu < min toleransi (dingin)':
            return 'Suhu terlalu rendah untuk tanaman tomat';
          case 'suhu siang ideal':
            return 'Suhu optimal untuk siang hari';
          case 'suhu malam ideal':
            return 'Suhu optimal untuk malam hari';
          default:
            return 'Suhu optimal untuk pertumbuhan tomat';
        }
      case 'kelembaban_udara':
        switch (status.toLowerCase()) {
          case 'tinggi':
          case 'rh tinggi':
            return 'Kelembapan udara terlalu tinggi';
          case 'rendah':
          case 'rh rendah':
            return 'Kelembapan udara terlalu rendah';
          case 'risiko jamur':
            return 'Kelembapan sangat tinggi, risiko jamur';
          case 'rh ideal':
            return 'Kelembapan udara optimal';
          default:
            return 'Kelembapan udara optimal';
        }
      case 'kelembaban_tanah':
        switch (status.toLowerCase()) {
          case 'sangat kering':
          case 'kering':
            return 'Tanah terlalu kering, butuh penyiraman';
          case 'basah':
          case 'sangat basah':
            return 'Tanah terlalu basah, kurangi penyiraman';
          case 'ideal':
            return 'Kelembapan tanah optimal untuk tomat';
          default:
            return 'Kelembapan tanah optimal';
        }
      case 'kecerahan':
        switch (status.toLowerCase()) {
          case 'terang':
            return 'Cahaya sangat terang untuk tanaman';
          case 'redup':
          case 'remang':
            return 'Cahaya cukup untuk pertumbuhan';
          case 'gelap':
            return 'Cahaya terlalu redup untuk tanaman';
          default:
            return 'Intensitas cahaya optimal';
        }
      default:
        return 'Kondisi normal';
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
                  '🔔 Notifikasi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_unreadNotifications > 0)
                  TextButton(
                    onPressed: () {
                      NotificationService.markAllAsRead();
                      setState(() {
                        _unreadNotifications = 0;
                      });
                    },
                    child: const Text('Tandai Sudah Dibaca'),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<NotificationItem>>(
              stream: _notificationsEnabled 
                  ? NotificationService.getNotifications()
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

  Widget _buildNotificationItem(NotificationItem notification) {
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
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.agriculture,
                  size: 50,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'TomaFarm',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Memuat data sensor...',
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
            setState(() {
              _isLoading = false;
            });
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildSensorGrid(),
                const SizedBox(height: 24),
                _buildActuatorStatus(),
                const SizedBox(height: 24),
                _buildChartSection(),
                const SizedBox(height: 24),
                _buildQuickActions(),
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
                    'Monitoring Real-time',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Smart Farming Tomat',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
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
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications, color: Colors.green),
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
          'Data terkini dari sensor kebun tomat',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_sync, color: Colors.green[700], size: 16),
              const SizedBox(width: 6),
              Text(
                'Terhubung ke Database',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensorGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 Data Sensor Real-time',
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
              value: '${sensorData['suhu']?.toStringAsFixed(1)}°C',
              unit: 'Celcius',
              status: sensorData['status_suhu']?.toString() ?? 'Normal',
              color: Colors.red,
              statusColor: _getStatusColor(sensorData['status_suhu']?.toString() ?? 'Normal'),
              backgroundColor: Colors.red[50]!,
              description: _getStatusDescription('suhu', sensorData['status_suhu']?.toString() ?? 'Normal'),
            ),
            _buildSensorCard(
              icon: Icons.water_drop,
              title: 'Kelembaban Udara',
              value: '${sensorData['kelembaban_udara']?.toStringAsFixed(1)}%',
              unit: 'Persen',
              status: sensorData['status_kelembaban']?.toString() ?? 'Normal',
              color: Colors.blue,
              statusColor: _getStatusColor(sensorData['status_kelembaban']?.toString() ?? 'Normal'),
              backgroundColor: Colors.blue[50]!,
              description: _getStatusDescription('kelembaban_udara', sensorData['status_kelembaban']?.toString() ?? 'Normal'),
            ),
            _buildSensorCard(
              icon: Icons.grass,
              title: 'Kelembaban Tanah',
              value: '${sensorData['kelembaban_tanah']?.toStringAsFixed(1)}%',
              unit: 'Persen',
              status: sensorData['kategori_tanah']?.toString() ?? 'Normal',
              color: Colors.brown,
              statusColor: _getStatusColor(sensorData['kategori_tanah']?.toString() ?? 'Normal'),
              backgroundColor: Colors.brown[50]!,
              description: _getStatusDescription('kelembaban_tanah', sensorData['kategori_tanah']?.toString() ?? 'Normal'),
            ),
            _buildSensorCard(
              icon: Icons.light_mode,
              title: 'Intensitas Cahaya',
              value: '${sensorData['kecerahan']?.toStringAsFixed(0)}',
              unit: 'Lux',
              status: sensorData['kategori_cahaya']?.toString() ?? 'Normal',
              color: Colors.amber,
              statusColor: _getStatusColor(sensorData['kategori_cahaya']?.toString() ?? 'Normal'),
              backgroundColor: Colors.amber[50]!,
              description: _getStatusDescription('kecerahan', sensorData['kategori_cahaya']?.toString() ?? 'Normal'),
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
    required String description,
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
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActuatorStatus() {
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
              Icon(Icons.engineering, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Status Aktuator',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildActuatorItem(
                icon: Icons.water_drop,
                title: 'Pompa Air',
                status: actuatorData['pump'] ? 'ON' : 'OFF',
                statusColor: actuatorData['pump'] ? Colors.green : Colors.red,
                mode: actuatorData['autoMode'] ? 'Auto' : 'Manual',
                backgroundColor: Colors.blue[50]!,
              ),
              const SizedBox(width: 12),
              _buildActuatorItem(
                icon: Icons.lightbulb,
                title: 'Lampu Tumbuh',
                status: actuatorData['light'] ? 'ON' : 'OFF',
                statusColor: actuatorData['light'] ? Colors.green : Colors.red,
                mode: actuatorData['autoMode'] ? 'Auto' : 'Manual',
                backgroundColor: Colors.amber[50]!,
              ),
              const SizedBox(width: 12),
              _buildActuatorItem(
                icon: actuatorData['autoMode'] ? Icons.auto_mode : Icons.engineering,
                title: 'Mode Sistem',
                status: actuatorData['autoMode'] ? 'Auto' : 'Manual',
                statusColor: actuatorData['autoMode'] ? Colors.blue : Colors.orange,
                mode: 'Aktif',
                backgroundColor: Colors.purple[50]!,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info,
                  color: Colors.green[700],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    actuatorData['autoMode'] 
                      ? 'Sistem berjalan otomatis berdasarkan kondisi sensor'
                      : 'Kontrol manual aktif - Anda dapat mengontrol di halaman Kontrol',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActuatorItem({
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

  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
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
              Icon(Icons.trending_up, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                '📈 Trend Data Sensor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (temperatureData.isNotEmpty)
            SimpleChart(
              data: temperatureData,
              title: 'Suhu (°C)',
              color: Colors.red,
              dataType: 'temperature', 
            ),
          if (temperatureData.isNotEmpty) const SizedBox(height: 16),
          if (humidityData.isNotEmpty)
            SimpleChart(
              data: humidityData,
              title: 'Kelembaban Udara (%)',
              color: Colors.blue,
              dataType: 'humidity', 
            ),
          if (humidityData.isNotEmpty) const SizedBox(height: 16),
          if (soilMoistureData.isNotEmpty)
            SimpleChart(
              data: soilMoistureData,
              title: 'Kelembaban Tanah (%)',
              color: Colors.brown,
              dataType: 'soilMoisture', 
            ),
          if (temperatureData.isEmpty && humidityData.isEmpty && soilMoistureData.isEmpty)
            Container(
              height: 100,
              alignment: Alignment.center,
              child: const Text(
                'Menunggu data sensor...',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
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
              Icon(Icons.flash_on, color: Colors.purple),
              SizedBox(width: 8),
              Text(
                'Akses Cepat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickActionItem(
                icon: Icons.control_camera,
                title: 'Kontrol',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ControlScreen()),
                  );
                },
              ),
              _buildQuickActionItem(
                icon: Icons.history,
                title: 'Riwayat',
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HistoryScreen()),
                  );
                },
              ),
              _buildQuickActionItem(
                icon: Icons.settings,
                title: 'Pengaturan',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}