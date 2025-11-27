// screens/admin/settings/admin_settings.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final TextEditingController _tempMinController = TextEditingController();
  final TextEditingController _tempMaxController = TextEditingController();
  final TextEditingController _soilMinController = TextEditingController();
  final TextEditingController _soilMaxController = TextEditingController();
  final TextEditingController _lightMinController = TextEditingController();
  
  Map<String, dynamic> _systemSettings = {};
  Map<String, dynamic> _systemInfo = {};
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _autoModeEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSystemSettings();
    _loadSystemInfo();
  }

  void _loadSystemSettings() {
    _databaseRef.child('systemSettings').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _systemSettings = Map<String, dynamic>.from(data);
          
          // Set controller values
          _tempMinController.text = (_systemSettings['temperatureMin'] ?? 20).toString();
          _tempMaxController.text = (_systemSettings['temperatureMax'] ?? 30).toString();
          _soilMinController.text = (_systemSettings['soilMoistureMin'] ?? 30).toString();
          _soilMaxController.text = (_systemSettings['soilMoistureMax'] ?? 70).toString();
          _lightMinController.text = (_systemSettings['lightIntensityMin'] ?? 300).toString();
          
          _notificationsEnabled = _systemSettings['notificationsEnabled'] ?? true;
          _autoModeEnabled = _systemSettings['autoModeEnabled'] ?? true;
        });
      }
    });
  }

  void _loadSystemInfo() {
    _databaseRef.child('systemInfo').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _systemInfo = Map<String, dynamic>.from(data);
          _isLoading = false;
        });
      }
    });
  }

  void _saveSystemSettings() async {
    try {
      await _databaseRef.child('systemSettings').update({
        'temperatureMin': double.tryParse(_tempMinController.text) ?? 20,
        'temperatureMax': double.tryParse(_tempMaxController.text) ?? 30,
        'soilMoistureMin': double.tryParse(_soilMinController.text) ?? 30,
        'soilMoistureMax': double.tryParse(_soilMaxController.text) ?? 70,
        'lightIntensityMin': double.tryParse(_lightMinController.text) ?? 300,
        'notificationsEnabled': _notificationsEnabled,
        'autoModeEnabled': _autoModeEnabled,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedBy': _auth.currentUser?.email,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan sistem berhasil disimpan')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _resetSystemSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Pengaturan'),
        content: const Text('Apakah Anda yakin ingin mengembalikan pengaturan ke nilai default?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              await _databaseRef.child('systemSettings').remove();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pengaturan telah direset ke default')),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _changePassword() async {
    final user = _auth.currentUser;
    if (user?.email == null) return;

    try {
      await _auth.sendPasswordResetEmail(email: user!.email!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email reset password telah dikirim')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _logout() async {
    await _auth.signOut();
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tentang TomaFarm Admin'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TomaFarm Admin Panel',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Panel administrasi untuk sistem monitoring dan kontrol pertanian tomat pintar. '
                'Dilengkapi dengan berbagai fitur untuk mengelola node IoT, petani, dan pengaturan sistem.',
              ),
              SizedBox(height: 12),
              Text(
                'Fitur:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Monitoring real-time seluruh node'),
              Text('• Manajemen petani dan node IoT'),
              Text('• Sistem notifikasi dan alarm'),
              Text('• Pengaturan ambang batas otomatis'),
              Text('• Analytics dan reporting'),
              SizedBox(height: 12),
              Text(
                'Versi: 1.0.0\n© 2024 TomaFarm Team',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Text(
                      'Pengaturan Sistem',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kelola pengaturan sistem TomaFarm',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // System Thresholds
                    _buildSystemThresholds(),
                    const SizedBox(height: 16),

                    // System Features
                    _buildSystemFeatures(),
                    const SizedBox(height: 16),

                    // Account Settings
                    _buildAccountSettings(),
                    const SizedBox(height: 16),

                    // System Information
                    _buildSystemInfo(),
                    const SizedBox(height: 16),

                    // Actions
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSystemThresholds() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
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
              Icon(Icons.tune, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Ambang Batas Sistem',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Suhu (°C)',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tempMinController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _tempMaxController,
                  decoration: const InputDecoration(
                    labelText: 'Maksimum',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Kelembapan Tanah (%)',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _soilMinController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _soilMaxController,
                  decoration: const InputDecoration(
                    labelText: 'Maksimum',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Intensitas Cahaya Minimum (lux)',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _lightMinController,
            decoration: const InputDecoration(
              labelText: 'Nilai Minimum',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemFeatures() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
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
              Icon(Icons.settings, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Fitur Sistem',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Mode Otomatis'),
            subtitle: const Text('Aktifkan kontrol otomatis untuk semua node'),
            value: _autoModeEnabled,
            onChanged: (value) {
              setState(() {
                _autoModeEnabled = value;
              });
            },
            secondary: const Icon(Icons.auto_mode),
          ),
          SwitchListTile(
            title: const Text('Notifikasi Sistem'),
            subtitle: const Text('Aktifkan notifikasi untuk alarm dan alert'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
            secondary: const Icon(Icons.notifications),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
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
              Icon(Icons.admin_panel_settings, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Pengaturan Akun',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingItem(
            icon: Icons.lock_reset,
            title: 'Ubah Password',
            subtitle: 'Reset password akun admin',
            onTap: _changePassword,
          ),
          const Divider(),
          _buildSettingItem(
            icon: Icons.person,
            title: 'Profil Admin',
            subtitle: 'Kelola informasi profil',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur profil akan segera hadir')),
              );
            },
          ),
          const Divider(),
          _buildSettingItem(
            icon: Icons.info,
            title: 'Tentang Aplikasi',
            subtitle: 'Informasi versi dan developer',
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.blue, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSystemInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
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
              Icon(Icons.info, color: Colors.purple),
              SizedBox(width: 8),
              Text(
                'Informasi Sistem',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem('Versi Aplikasi', _systemInfo['appVersion'] ?? '1.0.0'),
          _buildInfoItem('Database', _systemInfo['databaseStatus'] ?? 'Online'),
          _buildInfoItem('Server', _systemInfo['serverStatus'] ?? 'Active'),
          _buildInfoItem('Total Node', '${_systemInfo['totalNodes'] ?? 0}'),
          _buildInfoItem('Total Petani', '${_systemInfo['totalFarmers'] ?? 0}'),
          _buildInfoItem(
            'Uptime', 
            _systemInfo['uptime'] != null 
              ? '${(_systemInfo['uptime'] / 3600).toStringAsFixed(1)} jam'
              : '0 jam'
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveSystemSettings,
                icon: const Icon(Icons.save),
                label: const Text('Simpan Pengaturan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetSystemSettings,
                icon: const Icon(Icons.restore),
                label: const Text('Reset Default'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}