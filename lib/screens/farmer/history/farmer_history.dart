import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // PERBAIKAN: Gunakan FirebaseDatabase.instance.ref() saja tanpa instanceFor
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  
  List<LogEntry> _logs = [];
  String _selectedFilter = '24jam';
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    print('🔄 Loading logs from Firebase...');
    
    // PERBAIKAN: Gunakan once() untuk sekali baca data, bukan realtime listener
    _databaseRef.child('history_data').orderByChild('timestamp').once().then((DatabaseEvent event) {
      try {
        final data = event.snapshot.value;
        final List<LogEntry> logs = [];

        print('📊 Data received from Firebase: ${data != null ? "Data exists" : "null"}');

        if (data != null && data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              print('🔍 Processing log entry: $key');
              
              logs.add(LogEntry(
                id: key.toString(),
                timestamp: _parseTimestamp(value['timestamp']),
                action: _generateActionText(value),
                type: 'sensor',
                temperature: _toDouble(value['suhu']),
                humidity: _toDouble(value['kelembaban_udara']),
                soilMoisture: _toDouble(value['kelembaban_tanah']),
                value: _toDouble(value['kecerahan']),
                unit: '%',
                brightness: _toDouble(value['kecerahan']),
                soilCategory: value['kategori_tanah']?.toString(),
                lightCategory: value['kategori_cahaya']?.toString(),
                operationMode: value['mode_operasi']?.toString(),
                pumpStatus: value['status_pompa']?.toString(),
                temperatureStatus: value['status_suhu']?.toString(),
                humidityStatus: value['status_kelembaban']?.toString(),
                plantStage: value['tahapan_tanaman']?.toString(),
                plantAge: _toDouble(value['umur_tanaman']),
                timeOfDay: value['waktu']?.toString(),
              ));
            }
          });
        }

        // Sort by timestamp descending
        logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        print('✅ Successfully loaded ${logs.length} logs');

        setState(() {
          _logs = logs;
          _isLoading = false;
          _hasError = false;
        });
      } catch (e) {
        print('❌ Error loading logs: $e');
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }).catchError((error) {
      print('❌ Error fetching logs: $error');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    });
  }

  int _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now().millisecondsSinceEpoch;
    }
    
    if (timestamp is int) {
      // PERBAIKAN: Handle timestamp yang kecil (dalam detik)
      if (timestamp < 10000000000) {
        return timestamp * 1000;
      }
      return timestamp;
    }
    
    if (timestamp is String) {
      final parsed = int.tryParse(timestamp);
      if (parsed != null) {
        if (parsed < 10000000000) {
          return parsed * 1000;
        }
        return parsed;
      }
    }
    
    return DateTime.now().millisecondsSinceEpoch;
  }

  String _generateActionText(Map<dynamic, dynamic> data) {
    final plantStage = data['tahapan_tanaman']?.toString() ?? 'Tanaman';
    final soilCategory = data['kategori_tanah']?.toString() ?? '';
    
    return 'Monitoring $plantStage - Tanah: $soilCategory';
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  List<LogEntry> _getFilteredLogs() {
    final now = DateTime.now();
    final cutoff = _getCutoffTime(now);

    return _logs.where((log) {
      final logTime = DateTime.fromMillisecondsSinceEpoch(log.timestamp);
      return logTime.isAfter(cutoff);
    }).toList();
  }

  DateTime _getCutoffTime(DateTime now) {
    switch (_selectedFilter) {
      case '1jam':
        return now.subtract(const Duration(hours: 1));
      case '6jam':
        return now.subtract(const Duration(hours: 6));
      case '24jam':
        return now.subtract(const Duration(days: 1)); // 1 hari
      case '2hari':
        return now.subtract(const Duration(days: 2));
      case '3hari':
        return now.subtract(const Duration(days: 3));
      case '7hari':
        return now.subtract(const Duration(days: 7));
      case '1bulan':
        return now.subtract(const Duration(days: 30));
      case 'semua':
        return DateTime(1970); // Semua data
      default:
        return now.subtract(const Duration(days: 1));
    }
  }

  String _getFilterDisplayName(String filter) {
    switch (filter) {
      case '1jam':
        return '1 Jam';
      case '6jam':
        return '6 Jam';
      case '24jam':
        return '1 Hari';
      case '2hari':
        return '2 Hari';
      case '3hari':
        return '3 Hari';
      case '7hari':
        return '7 Hari';
      case '1bulan':
        return '1 Bulan';
      case 'semua':
        return 'Semua';
      default:
        return '1 Hari';
    }
  }

  IconData _getLogIcon(String type, String action) {
    return Icons.sensors; // Icon default untuk semua data sensor
  }

  Color _getLogColor(String type) {
    return Colors.green; // Warna hijau untuk data sensor
  }

  Color _getLogBackgroundColor(String type) {
    return Colors.green.shade50;
  }

  void _refreshData() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _selectedFilter == 'semua' ? _logs : _getFilteredLogs();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📊 Riwayat Monitoring',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE8F5E8), Color(0xFFC8E6C9)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.analytics, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Data History SmartFarm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${filteredLogs.length} data monitoring ditemukan',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Time Filter dengan lebih banyak pilihan
              _buildTimeFilter(),
              const SizedBox(height: 20),

              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _hasError
                        ? _buildErrorState()
                        : filteredLogs.isEmpty
                            ? _buildEmptyState()
                            : _buildLogList(filteredLogs),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFilter() {
    // PERBAIKAN: Tambahkan lebih banyak pilihan filter waktu
    final filters = ['1jam', '6jam', '24jam', '2hari', '3hari', '7hari', '1bulan', 'semua'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_alt, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text(
                'Filter Waktu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filters.map((filter) {
                final isActive = _selectedFilter == filter;
                return FilterChip(
                  label: Text(_getFilterDisplayName(filter)),
                  selected: isActive,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  backgroundColor: Colors.grey.shade100,
                  selectedColor: Colors.green,
                  labelStyle: TextStyle(
                    color: isActive ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  checkmarkColor: Colors.white,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(List<LogEntry> logs) {
    return Column(
      children: [
        // Summary Cards
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Total', logs.length.toString(), Icons.list, Colors.blue),
              _buildSummaryItem(
                'Tanah Kering', 
                logs.where((log) => log.soilCategory == 'SANGAT KERING' || log.soilCategory == 'KERING').length.toString(), 
                Icons.grass, 
                Colors.orange
              ),
              _buildSummaryItem(
                'Pompa ON', 
                logs.where((log) => log.pumpStatus == 'ON').length.toString(), 
                Icons.water_drop, 
                Colors.blue
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // List
        Expanded(
          child: ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final log = logs[index];
              return _buildLogItem(log);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(LogEntry log) {
    final date = DateTime.fromMillisecondsSinceEpoch(log.timestamp);
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isToday = DateFormat('yyyyMMdd').format(date) == DateFormat('yyyyMMdd').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getLogBackgroundColor(log.type),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _getLogColor(log.type).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getLogColor(log.type).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getLogIcon(log.type, log.action),
              color: _getLogColor(log.type),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.action,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                
                // Data sensor
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _buildDetailedSensorDataText(log),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // Status tambahan
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _buildStatusChips(log),
                ),
              ],
            ),
          ),

          // Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeFormat.format(date),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isToday ? 'Hari Ini' : dateFormat.format(date),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatusChips(LogEntry log) {
    final chips = <Widget>[];
    
    if (log.soilCategory != null) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getSoilColor(log.soilCategory!).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Tanah: ${log.soilCategory}',
            style: TextStyle(
              fontSize: 10,
              color: _getSoilColor(log.soilCategory!),
            ),
          ),
        ),
      );
    }
    
    if (log.pumpStatus != null) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: log.pumpStatus == 'ON' ? Colors.green.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Pompa: ${log.pumpStatus}',
            style: TextStyle(
              fontSize: 10,
              color: log.pumpStatus == 'ON' ? Colors.green.shade700 : Colors.grey.shade700,
            ),
          ),
        ),
      );
    }
    
    if (log.plantStage != null) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            log.plantStage!,
            style: TextStyle(
              fontSize: 10,
              color: Colors.purple.shade700,
            ),
          ),
        ),
      );
    }
    
    return chips;
  }

  Color _getSoilColor(String soilCategory) {
    switch (soilCategory) {
      case 'SANGAT KERING':
        return Colors.red;
      case 'KERING':
        return Colors.orange;
      case 'IDEAL':
        return Colors.green;
      case 'BASAH':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _buildDetailedSensorDataText(LogEntry log) {
    final parts = <String>[];
    
    if (log.temperature != null) parts.add('🌡 ${log.temperature!.toStringAsFixed(1)}°C');
    if (log.humidity != null) parts.add('💧 ${log.humidity!.toStringAsFixed(1)}%');
    if (log.soilMoisture != null) parts.add('🌱 ${log.soilMoisture!.toStringAsFixed(1)}%');
    if (log.brightness != null) parts.add('💡 ${log.brightness!.toStringAsFixed(1)}%');
    
    return parts.isNotEmpty ? parts.join(' • ') : 'Data sensor';
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Colors.green,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Memuat data monitoring...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              size: 50,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Gagal memuat data',
            style: TextStyle(
              fontSize: 16,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.data_array,
              size: 50,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada data monitoring',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class LogEntry {
  final String id;
  final int timestamp;
  final String action;
  final String type;
  final double? temperature;
  final double? humidity;
  final double? soilMoisture;
  final double? value;
  final String? unit;
  
  final double? brightness;
  final String? soilCategory;
  final String? lightCategory;
  final String? operationMode;
  final String? pumpStatus;
  final String? temperatureStatus;
  final String? humidityStatus;
  final String? plantStage;
  final double? plantAge;
  final String? timeOfDay;

  LogEntry({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.type,
    this.temperature,
    this.humidity,
    this.soilMoisture,
    this.value,
    this.unit,
    this.brightness,
    this.soilCategory,
    this.lightCategory,
    this.operationMode,
    this.pumpStatus,
    this.temperatureStatus,
    this.humidityStatus,
    this.plantStage,
    this.plantAge,
    this.timeOfDay,
  });
}