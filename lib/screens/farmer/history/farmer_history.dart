import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  
  List<LogEntry> _logs = [];
  List<LogEntry> _currentData = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isListening = false;

  // Warna konsisten dengan dashboard
  final Color _primaryColor = const Color(0xFF006B5D); // Warna utama dashboard (suhu)
  final Color _secondaryColor = const Color(0xFFB8860B); // Warna kelembaban udara
  final Color _tertiaryColor = const Color(0xFF558B2F); // Warna kelembaban tanah
  final Color _accentColor = const Color(0xFFB71C1C); // Warna cahaya
  final Color _blueColor = const Color(0xFF1A237E); // Warna status aktuator
  final Color _greenColor = const Color(0xFF2E7D32); // Warna hijau tombol
  
  @override
  void initState() {
    super.initState();
    _initializeRealtimeListener();
  }

  @override
  void dispose() {
    _stopRealtimeListener();
    super.dispose();
  }

  void _initializeRealtimeListener() {
    print('🔄 Memulai realtime listener...');
    
    // Listen untuk data realtime (current_data)
    _databaseRef.child('current_data').onValue.listen((DatabaseEvent event) {
      print('📡 Data realtime diterima');
      _handleRealtimeData(event.snapshot.value);
    }, onError: (error) {
      print('❌ Error realtime listener: $error');
      setState(() {
        _hasError = true;
      });
    });

    // Load data history
    _loadHistoryData();
  }

  void _stopRealtimeListener() {
    if (_isListening) {
      _databaseRef.child('current_data').onValue.drain();
      _isListening = false;
      print('🔴 Realtime listener dihentikan');
    }
  }

  void _handleRealtimeData(dynamic data) {
    try {
      if (data != null && data is Map) {
        print('🔍 Memproses data realtime...');
        
        final LogEntry currentLog = LogEntry(
          id: 'realtime_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          action: _generateActionText(data),
          type: 'realtime',
          temperature: _toDouble(data['suhu']),
          humidity: _toDouble(data['kelembaban_udara']),
          soilMoisture: _toDouble(data['kelembaban_tanah']),
          value: _toDouble(data['kecerahan']),
          unit: '%',
          brightness: _toDouble(data['kecerahan']),
          soilCategory: data['kategori_tanah']?.toString(),
          lightCategory: data['kategori_cahaya']?.toString(),
          operationMode: data['mode_operasi']?.toString(),
          pumpStatus: data['status_pompa']?.toString(),
          temperatureStatus: data['status_suhu']?.toString(),
          humidityStatus: data['status_kelembaban']?.toString(),
          plantStage: data['tahapan_tanaman']?.toString(),
          plantAge: _toDouble(data['umur_tanaman']),
          timeOfDay: data['waktu']?.toString(),
          datetime: data['datetime']?.toString(),
          isRealtime: true,
        );

        setState(() {
          // Update current data (hanya simpan 1 data realtime terbaru)
          _currentData = [currentLog];
        });

        print('✅ Data realtime diperbarui: ${currentLog.datetime}');
      }
    } catch (e) {
      print('❌ Error memproses data realtime: $e');
    }
  }

  void _loadHistoryData() {
    print('🔄 Memuat data history dari Firebase...');
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    _databaseRef.child('history_data')
      .orderByKey()
      .limitToLast(100) // Batasi untuk performa
      .once()
      .then((DatabaseEvent event) {
      try {
        final data = event.snapshot.value;
        final List<LogEntry> logs = [];

        print('📊 Data history diterima: ${data != null ? "Data ada" : "null"}');

        if (data != null && data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              try {
                final int timestamp = _parseTimestampFromData(value, key.toString());
                
                logs.add(LogEntry(
                  id: key.toString(),
                  timestamp: timestamp,
                  action: _generateActionText(value),
                  type: 'history',
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
                  datetime: value['datetime']?.toString(),
                  isRealtime: false,
                ));
              } catch (e) {
                print('❌ Error memproses entry $key: $e');
              }
            }
          });
        }

        // Urutkan berdasarkan timestamp (terbaru di atas)
        logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        print('✅ Berhasil memuat ${logs.length} data history');

        setState(() {
          _logs = logs;
          _isLoading = false;
          _hasError = false;
          _isListening = true;
        });
      } catch (e) {
        print('❌ Error memuat history: $e');
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }).catchError((error) {
      print('❌ Error fetching history: $error');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    });
  }

  int _parseTimestampFromData(Map<dynamic, dynamic> data, String key) {
    try {
      // Prioritaskan timestamp dari data
      if (data['timestamp'] != null) {
        final ts = data['timestamp'];
        if (ts is int) {
          return ts;
        }
        if (ts is String) {
          final parsed = int.tryParse(ts);
          if (parsed != null) return parsed;
        }
      }

      // Coba dari datetime string
      if (data['datetime'] != null) {
        final dateTime = DateTime.tryParse(data['datetime'].toString());
        if (dateTime != null) {
          return dateTime.millisecondsSinceEpoch;
        }
      }

      // Fallback: parse dari key
      return _parseKeyToTimestamp(key);
    } catch (e) {
      print('❌ Error parsing timestamp: $e');
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  int _parseKeyToTimestamp(String key) {
    try {
      // Coba extract timestamp dari key
      final regex = RegExp(r'(\d{10,})');
      final match = regex.firstMatch(key);
      if (match != null) {
        final millis = int.tryParse(match.group(1)!);
        if (millis != null) {
          // Jika timestamp dalam seconds, convert ke milliseconds
          if (millis < 100000000000) {
            return millis * 1000;
          }
          return millis;
        }
      }
    } catch (e) {
      print('❌ Error parsing key $key: $e');
    }
    
    return DateTime.now().millisecondsSinceEpoch;
  }

  String _generateActionText(Map<dynamic, dynamic> data) {
    final plantStage = data['tahapan_tanaman']?.toString() ?? 'Tanaman';
    final soilCategory = data['kategori_tanah']?.toString() ?? '';
    final mode = data['mode_operasi']?.toString() ?? 'AUTO';
    
    return '$plantStage - $soilCategory ($mode)';
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

  void _refreshData() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _loadHistoryData();
  }

  List<LogEntry> get _allLogs {
    // Gabungkan current data dengan history, pastikan tidak ada duplikat
    final allLogs = [..._currentData, ..._logs];
    
    // Hapus duplikat berdasarkan timestamp
    final uniqueLogs = <String, LogEntry>{};
    for (final log in allLogs) {
      final key = '${log.timestamp}_${log.id}';
      if (!uniqueLogs.containsKey(key)) {
        uniqueLogs[key] = log;
      }
    }
    
    return uniqueLogs.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 20),

              // Status Real-time
              if (_currentData.isNotEmpty) ...[
                _buildRealtimeStatus(),
                const SizedBox(height: 16),
              ],

              // Summary Cards
              _buildSummaryCards(),
              const SizedBox(height: 20),

              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _hasError
                        ? _buildErrorState()
                        : _allLogs.isEmpty
                            ? _buildEmptyState()
                            : _buildLogList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final totalData = _allLogs.length;
    final realtimeCount = _currentData.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryColor.withOpacity(0.1),
            _tertiaryColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.2),
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
              color: _isListening ? _primaryColor : Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isListening ? Icons.online_prediction : Icons.offline_bolt,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SmartFarm Tomat - ${_isListening ? 'REALTIME' : 'OFFLINE'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalData data monitoring ditemukan',
                  style: TextStyle(
                    fontSize: 14,
                    color: _primaryColor.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tahapan: ${_getCurrentPlantStage()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _primaryColor.withOpacity(0.7),
                  ),
                ),
                if (realtimeCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '🟢 Data realtime aktif',
                    style: TextStyle(
                      fontSize: 11,
                      color: _greenColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.calendar_today, color: _primaryColor, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeStatus() {
    if (_currentData.isEmpty) return const SizedBox();
    
    final currentLog = _currentData.first;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blueColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blueColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _blueColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 8),
          Text(
            'DATA REAL-TIME:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _blueColor,
            ),
          ),
          const SizedBox(width: 8),
          if (currentLog.temperature != null)
            _buildSensorItem('🌡', '${currentLog.temperature!.toStringAsFixed(1)}°C', _primaryColor),
          if (currentLog.humidity != null)
            _buildSensorItem('💧', '${currentLog.humidity!.toStringAsFixed(1)}%', _secondaryColor),
          if (currentLog.soilMoisture != null)
            _buildSensorItem('🌱', '${currentLog.soilMoisture!.toStringAsFixed(1)}%', _tertiaryColor),
          if (currentLog.pumpStatus != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: currentLog.pumpStatus == 'ON' ? _greenColor.withOpacity(0.2) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'POMPA: ${currentLog.pumpStatus}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: currentLog.pumpStatus == 'ON' ? _greenColor : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final allLogs = _allLogs;
    final drySoilCount = allLogs.where((log) => log.soilCategory == 'SANGAT KERING' || log.soilCategory == 'KERING').length;
    final pumpOnCount = allLogs.where((log) => log.pumpStatus == 'ON').length;
    final autoModeCount = allLogs.where((log) => log.operationMode == 'AUTO').length;
    final realtimeCount = _currentData.length;

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
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: _primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Ringkasan Data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const Spacer(),
              if (realtimeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 10,
                      color: _primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryCard('Total Data', allLogs.length.toString(), Icons.list, _primaryColor),
              _buildSummaryCard('Tanah Kering', drySoilCount.toString(), Icons.grass, _tertiaryColor),
              _buildSummaryCard('Pompa ON', pumpOnCount.toString(), Icons.water_drop, _blueColor),
              _buildSummaryCard('Auto Mode', autoModeCount.toString(), Icons.smart_toy, _greenColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
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

  Widget _buildLogList() {
    final allLogs = _allLogs;

    return Column(
      children: [
        // List Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.history, size: 16, color: _primaryColor),
              const SizedBox(width: 8),
              Text(
                'Riwayat Monitoring',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const Spacer(),
              Text(
                'Total: ${allLogs.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // List
        Expanded(
          child: ListView.separated(
            itemCount: allLogs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final log = allLogs[index];
              return _buildLogItem(log);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(LogEntry log) {
    final date = DateTime.fromMillisecondsSinceEpoch(log.timestamp);
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isToday = DateFormat('yyyyMMdd').format(date) == DateFormat('yyyyMMdd').format(DateTime.now());
    final isRealtime = log.isRealtime;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRealtime
              ? [_blueColor.withOpacity(0.1), _primaryColor.withOpacity(0.1)]
              : [_primaryColor.withOpacity(0.1), _blueColor.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isRealtime ? _blueColor : _primaryColor.withOpacity(0.3),
          width: isRealtime ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon dengan status
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isRealtime ? _blueColor : _getStatusColor(log),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRealtime ? Icons.fiber_manual_record : _getStatusIcon(log),
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dengan tahapan tanaman
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        log.plantStage ?? 'Tanaman',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isRealtime)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _blueColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'REALTIME',
                          style: TextStyle(
                            fontSize: 10,
                            color: _blueColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: log.operationMode == 'AUTO' ? _blueColor.withOpacity(0.1) : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Mode: ${log.operationMode ?? 'AUTO'}',
                        style: TextStyle(
                          fontSize: 10,
                          color: log.operationMode == 'AUTO' ? _blueColor : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Data sensor utama
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: _buildSensorData(log),
                ),
                const SizedBox(height: 8),

                // Status tambahan
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _buildStatusChips(log),
                ),
                
                // Tampilkan datetime asli dari Firebase jika ada
                if (log.datetime != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Waktu: ${log.datetime}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Time Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isRealtime 
                    ? _blueColor.withOpacity(0.2) 
                    : isToday 
                      ? _primaryColor.withOpacity(0.2) 
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeFormat.format(date),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isRealtime 
                      ? _blueColor 
                      : isToday 
                        ? _primaryColor 
                        : Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isRealtime ? 'LIVE NOW' : (isToday ? 'Hari Ini' : dateFormat.format(date)),
                style: TextStyle(
                  fontSize: 10,
                  color: isRealtime ? _blueColor.withOpacity(0.8) : Colors.grey.shade600,
                  fontWeight: isRealtime ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSensorData(LogEntry log) {
    return [
      if (log.temperature != null)
        _buildSensorItem('🌡', '${log.temperature!.toStringAsFixed(1)}°C', _primaryColor),
      if (log.humidity != null)
        _buildSensorItem('💧', '${log.humidity!.toStringAsFixed(1)}%', _secondaryColor),
      if (log.soilMoisture != null)
        _buildSensorItem('🌱', '${log.soilMoisture!.toStringAsFixed(1)}%', _tertiaryColor),
      if (log.brightness != null)
        _buildSensorItem('💡', '${log.brightness!.toStringAsFixed(1)}%', _accentColor),
    ];
  }

  Widget _buildSensorItem(String icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
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
            color: log.pumpStatus == 'ON' ? _greenColor.withOpacity(0.1) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Pompa: ${log.pumpStatus}',
            style: TextStyle(
              fontSize: 10,
              color: log.pumpStatus == 'ON' ? _greenColor : Colors.grey.shade700,
            ),
          ),
        ),
      );
    }

    if (log.timeOfDay != null) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: log.timeOfDay == 'Siang' ? _secondaryColor.withOpacity(0.1) : _blueColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            log.timeOfDay!,
            style: TextStyle(
              fontSize: 10,
              color: log.timeOfDay == 'Siang' ? _secondaryColor : _blueColor,
            ),
          ),
        ),
      );
    }
    
    return chips;
  }

  Color _getStatusColor(LogEntry log) {
    if (log.pumpStatus == 'ON') return _greenColor;
    if (log.soilCategory == 'SANGAT KERING') return Colors.red;
    if (log.soilCategory == 'KERING') return Colors.orange;
    return _primaryColor;
  }

  IconData _getStatusIcon(LogEntry log) {
    if (log.pumpStatus == 'ON') return Icons.water_drop;
    if (log.soilCategory == 'SANGAT KERING') return Icons.warning;
    return Icons.sensors;
  }

  Color _getSoilColor(String soilCategory) {
    switch (soilCategory) {
      case 'SANGAT KERING':
        return Colors.red;
      case 'KERING':
        return Colors.orange;
      case 'LEMBAB':
        return _tertiaryColor;
      case 'BASAH':
        return _blueColor;
      default:
        return Colors.grey;
    }
  }

  String _getCurrentPlantStage() {
    if (_currentData.isNotEmpty) {
      return _currentData.first.plantStage ?? 'Unknown';
    }
    if (_logs.isNotEmpty) {
      return _logs.first.plantStage ?? 'Unknown';
    }
    return 'Tidak ada data';
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: _primaryColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat data monitoring 2025...',
            style: TextStyle(
              fontSize: 16,
              color: _primaryColor,
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
              backgroundColor: _primaryColor,
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
            child: Icon(
              Icons.data_array,
              size: 50,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada data monitoring',
            style: TextStyle(
              fontSize: 16,
              color: _primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
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
  final String? datetime;
  final bool isRealtime;

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
    this.datetime,
    required this.isRealtime,
  });
}