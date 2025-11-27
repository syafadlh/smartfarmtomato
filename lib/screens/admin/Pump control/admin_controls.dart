import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, unread, read

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    _databaseRef.child('notifications')
      .orderByChild('timestamp')
      .onValue.listen((event) {
      try {
        final data = event.snapshot.value;
        final List<Map<String, dynamic>> notifications = [];
        
        if (data != null && data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              notifications.add({
                'id': key,
                'title': value['title'] ?? 'Notifikasi',
                'message': value['message'] ?? 'No message',
                'type': value['type'] ?? 'general',
                'severity': value['severity'] ?? 'medium',
                'timestamp': value['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
                'read': value['read'] ?? false,
                'nodeId': value['nodeId'],
                'farmerId': value['farmerId'],
              });
            }
          });
          
          setState(() {
            _notifications = notifications.reversed.toList();
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading notifications: $e');
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _markAsRead(String notificationId) {
    _databaseRef.child('notifications/$notificationId/read').set(true);
  }

  void _markAllAsRead() {
    for (var notification in _notifications.where((n) => !n['read'])) {
      _markAsRead(notification['id']);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua notifikasi ditandai sudah dibaca')),
    );
  }

  void _deleteNotification(String notificationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Notifikasi'),
        content: const Text('Apakah Anda yakin ingin menghapus notifikasi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              await _databaseRef.child('notifications/$notificationId').remove();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifikasi berhasil dihapus')),
              );
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua'),
        content: const Text('Apakah Anda yakin ingin menghapus semua notifikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              await _databaseRef.child('notifications').remove();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Semua notifikasi berhasil dihapus')),
              );
            },
            child: const Text('Hapus Semua', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    switch (_filter) {
      case 'unread':
        return _notifications.where((n) => !n['read']).toList();
      case 'read':
        return _notifications.where((n) => n['read']).toList();
      default:
        return _notifications;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'alarm': return Icons.alarm;
      case 'warning': return Icons.warning;
      case 'info': return Icons.info;
      case 'success': return Icons.check_circle;
      case 'error': return Icons.error;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n['read']).length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Notifikasi',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'mark_all_read',
                          child: Row(
                            children: [
                              Icon(Icons.done_all, size: 20),
                              SizedBox(width: 8),
                              Text('Tandai Semua Dibaca'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'clear_all',
                          child: Row(
                            children: [
                              Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Hapus Semua', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'mark_all_read') {
                          _markAllAsRead();
                        } else if (value == 'clear_all') {
                          _clearAll();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Semua', 'all'),
                      _buildFilterChip('Belum Dibaca', 'unread'),
                      _buildFilterChip('Sudah Dibaca', 'read'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Notifications List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada notifikasi',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredNotifications.length,
                        itemBuilder: (context, index) {
                          final notification = _filteredNotifications[index];
                          return _buildNotificationCard(notification);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filter = value;
          });
        },
        selectedColor: Colors.blue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isUnread = !notification['read'];
    final date = DateTime.fromMillisecondsSinceEpoch(notification['timestamp']);
    final timeFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Dismissible(
      key: Key(notification['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _deleteNotification(notification['id']);
      },
      child: GestureDetector(
        onTap: () {
          if (isUnread) {
            _markAsRead(notification['id']);
          }
        },
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isUnread 
              ? _getSeverityColor(notification['severity']).withOpacity(0.05)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(notification['severity']).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getTypeIcon(notification['type']),
                    color: _getSeverityColor(notification['severity']),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification['message'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            timeFormat.format(date),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (notification['nodeId'] != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.sensors, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Node: ${notification['nodeId']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}