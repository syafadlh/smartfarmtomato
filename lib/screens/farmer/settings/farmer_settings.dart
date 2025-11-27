import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../auth/home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoRefreshEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    // Load dari local storage - default values
    setState(() {
      _notificationsEnabled = true;
      _darkModeEnabled = false;
      _autoRefreshEnabled = true;
    });
  }

  void _toggleNotifications(bool value) {
    setState(() {
      _notificationsEnabled = value;
    });
    _showSnackBar('Notifikasi ${value ? 'diaktifkan' : 'dinonaktifkan'}');
  }

  void _toggleDarkMode(bool value) {
    setState(() {
      _darkModeEnabled = value;
    });
    _showSnackBar('Mode gelap ${value ? 'diaktifkan' : 'dinonaktifkan'}');
  }

  void _toggleAutoRefresh(bool value) {
    setState(() {
      _autoRefreshEnabled = value;
    });
    _showSnackBar('Auto refresh ${value ? 'diaktifkan' : 'dinonaktifkan'}');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.agriculture, color: Colors.green),
            SizedBox(width: 8),
            Text(
              'Tentang TomaFarm',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE8F5E8), Color(0xFFC8E6C9)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Text(
                      '🍅 TomaFarm',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Smart Tomato Farming System',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aplikasi TomaFarm adalah sistem monitoring dan kontrol otomatis untuk budidaya tanaman tomat. '
                'Dilengkapi dengan berbagai fitur canggih untuk memastikan tanaman tomat tumbuh optimal.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '🎯 Fitur Utama:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildFeatureItem('📊 Monitoring real-time sensor'),
              _buildFeatureItem('💧 Kontrol otomatis pompa air'),
              _buildFeatureItem('💡 Kontrol lampu tumbuh'),
              _buildFeatureItem('📈 Riwayat data dan grafik'),
              _buildFeatureItem('🔔 Notifikasi cerdas'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Informasi Teknis:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Versi: 1.0.0\nBuild: 2024.12.01\nDikembangkan untuk Project Based Learning',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
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

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Konfirmasi Logout'),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin logout dari akun Anda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showAccountInfo() {
    final user = _auth.currentUser;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person, color: Colors.blue),
            SizedBox(width: 8),
            Text('Informasi Akun'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAccountInfoItem('Nama', user?.displayName ?? 'Tidak diatur'),
            _buildAccountInfoItem('Email', user?.email ?? 'Tidak tersedia'),
            _buildAccountInfoItem(
              'Status Email',
              user?.emailVerified == true ? 'Terverifikasi' : 'Belum diverifikasi',
            ),
            _buildAccountInfoItem(
              'Bergabung',
              user?.metadata.creationTime != null 
                  ? '${DateTime.now().difference(user!.metadata.creationTime!).inDays} hari yang lalu'
                  : 'Tidak tersedia',
            ),
          ],
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

  Widget _buildAccountInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '⚙️ Pengaturan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E8), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? user?.email?.split('@').first ?? 'Pengguna TomaFarm',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? 'email@example.com',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: user?.emailVerified == true 
                                        ? Colors.white.withOpacity(0.3)
                                        : Colors.orange.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    user?.emailVerified == true ? '✓ Email Terverifikasi' : '! Verifikasi Email',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _showAccountInfo,
                        icon: const Icon(Icons.info_outline, color: Colors.white),
                        tooltip: 'Info Akun',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Settings List
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(Icons.settings, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Pengaturan Aplikasi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildSettingItem(
                        icon: Icons.notifications_active,
                        title: 'Notifikasi Sistem',
                        subtitle: 'Terima notifikasi kondisi tanaman',
                        trailing: Switch(
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          activeColor: Colors.green,
                          activeTrackColor: Colors.green.shade200,
                        ),
                      ),
                      const Divider(height: 1, indent: 20),
                      _buildSettingItem(
                        icon: Icons.dark_mode,
                        title: 'Mode Gelap',
                        subtitle: 'Tampilan tema gelap',
                        trailing: Switch(
                          value: _darkModeEnabled,
                          onChanged: _toggleDarkMode,
                          activeColor: Colors.blue,
                          activeTrackColor: Colors.blue.shade200,
                        ),
                      ),
                      const Divider(height: 1, indent: 20),
                      _buildSettingItem(
                        icon: Icons.refresh,
                        title: 'Auto Refresh',
                        subtitle: 'Refresh data otomatis',
                        trailing: Switch(
                          value: _autoRefreshEnabled,
                          onChanged: _toggleAutoRefresh,
                          activeColor: Colors.orange,
                          activeTrackColor: Colors.orange.shade200,
                        ),
                      ),
                      const Divider(height: 1, indent: 20),
                      _buildSettingItem(
                        icon: Icons.language,
                        title: 'Bahasa',
                        subtitle: 'Bahasa Indonesia',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () {
                          _showSnackBar('Bahasa Indonesia aktif');
                        },
                      ),
                      const Divider(height: 1, indent: 20),
                      _buildSettingItem(
                        icon: Icons.info_outline,
                        title: 'Tentang Aplikasi',
                        subtitle: 'Versi 1.0.0',
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: _showAboutDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showLogoutConfirmation,
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Keluar dari Akun',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: Colors.red.withOpacity(0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 16), // Extra padding for bottom
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.green, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }
}