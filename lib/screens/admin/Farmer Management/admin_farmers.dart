// lib/screens/admin/farmers/admin_farmers.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminFarmersScreen extends StatefulWidget {
  const AdminFarmersScreen({super.key});

  @override
  State<AdminFarmersScreen> createState() => _AdminFarmersScreenState();
}

class _AdminFarmersScreenState extends State<AdminFarmersScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _farmers = [];
  List<Map<String, dynamic>> _filteredFarmers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFarmers();
    _searchController.addListener(_onSearchChanged);
  }

  void _loadFarmers() {
    _databaseRef.child('users').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      final List<Map<String, dynamic>> farmers = [];
      
      if (data != null) {
        data.forEach((key, value) {
          if (value['role'] == 'farmer') {
            farmers.add({
              'id': key,
              'email': value['email'] ?? 'No Email',
              'name': value['name'] ?? 'Unknown Farmer',
              'status': value['status'] ?? 'active',
              'createdAt': value['createdAt'],
              'lastLogin': value['lastLogin'],
              'nodeCount': value['nodeCount'] ?? 0,
            });
          }
        });
        
        setState(() {
          _farmers = farmers;
          _filteredFarmers = farmers;
          _isLoading = false;
        });
      }
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filteredFarmers = _farmers.where((farmer) =>
        farmer['email'].toLowerCase().contains(_searchQuery) ||
        farmer['name'].toLowerCase().contains(_searchQuery)
      ).toList();
    });
  }

  void _showFarmerDetails(Map<String, dynamic> farmer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(farmer['name']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Email', farmer['email']),
              _buildDetailItem('Status', farmer['status']),
              _buildDetailItem('Jumlah Node', '${farmer['nodeCount']}'),
              _buildDetailItem(
                'Terdaftar Sejak', 
                farmer['createdAt'] != null 
                  ? _formatDate(DateTime.fromMillisecondsSinceEpoch(farmer['createdAt']))
                  : 'Unknown'
              ),
              _buildDetailItem(
                'Login Terakhir', 
                farmer['lastLogin'] != null 
                  ? _formatDate(DateTime.fromMillisecondsSinceEpoch(farmer['lastLogin']))
                  : 'Never'
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Column(
        children: [
          // Header dengan Search
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
              children: [
                const Row(
                  children: [
                    Text(
                      'Manajemen Petani',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari petani...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Farmers List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFarmers.isEmpty
                    ? const Center(child: Text('Tidak ada petani ditemukan'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredFarmers.length,
                        itemBuilder: (context, index) {
                          final farmer = _filteredFarmers[index];
                          return _buildFarmerCard(farmer);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerCard(Map<String, dynamic> farmer) {
    final isActive = farmer['status'] == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: isActive ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        farmer['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        farmer['email'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 20),
                          SizedBox(width: 8),
                          Text('Detail'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'details') {
                      _showFarmerDetails(farmer);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip('Status', farmer['status'], isActive ? Colors.green : Colors.red),
                _buildInfoChip('Node', '${farmer['nodeCount']}', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}