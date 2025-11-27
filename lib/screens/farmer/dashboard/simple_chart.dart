import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SimpleChart extends StatelessWidget {
  final List<ChartData> data;
  final String title;
  final Color color;
  final String dataType; // 'temperature', 'humidity', 'soilMoisture', 'brightness'

  const SimpleChart({
    super.key,
    required this.data,
    required this.title,
    required this.color,
    required this.dataType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: _getMinY(),
                maxY: _getMaxY(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: _getYInterval(),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: _getXInterval(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _formatTimeLabel(data[index].time),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: _getYInterval(),
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatYValue(value),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.value);
                    }).toList(),
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: data.length <= 20, // Jangan tampilkan dot jika data terlalu banyak
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: color,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(0.3),
                          color.withOpacity(0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.white,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((touchedSpot) {
                        final index = touchedSpot.spotIndex;
                        return LineTooltipItem(
                          '${_formatTimeForTooltip(data[index].time)}\n${_getValueWithUnit(data[index].value)}',
                          const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeLabel(String time) {
    // Format waktu untuk label sumbu X (menampilkan jam saja)
    try {
      final date = DateTime.parse(time);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      // Jika parsing gagal, tampilkan aslinya
      if (time.length > 5) {
        return time.substring(11, 16); // Ambil jam dan menit saja
      }
      return time;
    }
  }

  String _formatTimeForTooltip(String time) {
    // Format waktu lengkap untuk tooltip
    try {
      final date = DateTime.parse(time);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return time;
    }
  }

  String _formatYValue(double value) {
    // Format nilai Y berdasarkan tipe data
    switch (dataType) {
      case 'temperature':
        return '${value.toInt()}°C';
      case 'humidity':
      case 'soilMoisture':
      case 'brightness':
        return '${value.toInt()}%';
      default:
        return value.toInt().toString();
    }
  }

  String _getValueWithUnit(double value) {
    // Format nilai dengan unit untuk tooltip
    switch (dataType) {
      case 'temperature':
        return '${value.toStringAsFixed(1)}°C';
      case 'humidity':
        return '${value.toStringAsFixed(1)}% RH';
      case 'soilMoisture':
        return '${value.toStringAsFixed(1)}% Soil';
      case 'brightness':
        return '${value.toStringAsFixed(1)}% Light';
      default:
        return value.toStringAsFixed(1);
    }
  }

  double _getMinY() {
    if (data.isEmpty) return 0;
    
    double min = data.first.value;
    for (final item in data) {
      if (item.value < min) min = item.value;
    }
    
    // Berikan margin berdasarkan tipe data
    switch (dataType) {
      case 'temperature':
        return (min - 2).clamp(0, double.infinity);
      case 'humidity':
        return (min - 5).clamp(0, 100);
      case 'soilMoisture':
        return (min - 5).clamp(0, 100);
      case 'brightness':
        return (min - 5).clamp(0, 100);
      default:
        return (min - 5).clamp(0, double.infinity);
    }
  }

  double _getMaxY() {
    if (data.isEmpty) {
      switch (dataType) {
        case 'temperature':
          return 40;
        case 'humidity':
        case 'soilMoisture':
        case 'brightness':
          return 100;
        default:
          return 100;
      }
    }
    
    double max = data.first.value;
    for (final item in data) {
      if (item.value > max) max = item.value;
    }
    
    // Berikan margin berdasarkan tipe data
    switch (dataType) {
      case 'temperature':
        return max + 2;
      case 'humidity':
        return (max + 5).clamp(0, 100);
      case 'soilMoisture':
        return (max + 5).clamp(0, 100);
      case 'brightness':
        return (max + 5).clamp(0, 100);
      default:
        return max + 5;
    }
  }

  double _getYInterval() {
    final range = _getMaxY() - _getMinY();
    
    // Sesuaikan interval berdasarkan range dan tipe data
    if (range <= 10) return 2;
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    return 20;
  }

  double _getXInterval() {
    // Sesuaikan interval sumbu X berdasarkan jumlah data
    if (data.length <= 10) return 1;
    if (data.length <= 20) return 2;
    if (data.length <= 50) return 5;
    return 10;
  }
}

class ChartData {
  final String time;
  final double value;

  ChartData(this.time, this.value);
}