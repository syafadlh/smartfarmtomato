import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';

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
  List<Map<String, dynamic>> _passwordResetRequests = [];
  bool _isLoading = true;
  bool _showResetRequests = false;

  // Warna konsisten dengan tema
  final Color _primaryColor = const Color(0xFF006B5D); // Warna utama
  final Color _secondaryColor = const Color(0xFFB8860B); // Warna sekunder
  final Color _addButtonColor = const Color.fromARGB(255, 156, 9, 9); // Warna merah untuk tombol tambah

  @override
  void initState() {
    super.initState();
    _loadFarmers();
    _loadPasswordResetRequests();
    _searchController.addListener(_searchFilter);
  }

  void _loadFarmers() {
    _databaseRef.child('users').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      final List<Map<String, dynamic>> farmers = [];

      if (data != null) {
        data.forEach((key, value) {
          // Hanya tampilkan user dengan role 'farmer'
          if (value['role'] == 'farmer') {
            farmers.add({
              'id': key,
              'name': value['name'] ?? value['displayName'] ?? 'Unknown',
              'email': value['email'] ?? '-',
              'status': value['status'] ?? 'active',
              'createdAt': value['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
              'lastLogin': value['lastLogin'] ?? DateTime.now().millisecondsSinceEpoch,
              'farmCount': value['farmCount'] ?? 0,
            });
          }
        });
      }

      // Urutkan berdasarkan tanggal pendaftaran (terbaru)
      farmers.sort((a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));

      setState(() {
        _farmers = farmers;
        _filteredFarmers = farmers;
        _isLoading = false;
      });
    });
  }

  void _loadPasswordResetRequests() {
    _databaseRef.child('passwordResetRequests').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      final List<Map<String, dynamic>> requests = [];

      if (data != null) {
        data.forEach((key, value) {
          if (value['status'] == 'pending') {
            requests.add({
              'requestId': key,
              'userId': value['userId'],
              'userName': value['userName'],
              'email': value['email'],
              'newPassword': value['newPassword'],
              'requestedAt': value['requestedAt'],
              'status': value['status'],
            });
          }
        });
      }

      // Urutkan berdasarkan tanggal request (terbaru)
      requests.sort((a, b) => (b['requestedAt'] as int).compareTo(a['requestedAt'] as int));

      setState(() {
        _passwordResetRequests = requests;
      });
    });
  }

  void _searchFilter() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredFarmers = _farmers.where((f) {
        return f['name'].toLowerCase().contains(query) ||
            f['email'].toLowerCase().contains(query);
      }).toList();
    });
  }

  String _formatDate(int timestamp) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return '-';
    }
  }

  // Method untuk approve reset password
  void _approvePasswordReset(Map<String, dynamic> request) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.white,
        title: Text(
          'Setujui Reset Password',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menyetujui reset password untuk ${request['userName']} (${request['email']})?',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Update password di Firebase Auth
                try {
                  await FirebaseAuth.instance.signInWithEmailAndPassword(
                    email: request['email'],
                    password: 'temp123', // Password sementara untuk mendapatkan user
                  );
                  
                  // Note: Di Firebase, admin tidak bisa langsung update password user lain
                  // Solusi: Simpan password baru di database untuk digunakan saat login
                } catch (e) {
                  // Ignore error, lanjut ke metode alternatif
                }

                // Simpan password baru yang di-approve di database
                await _databaseRef.child('users/${request['userId']}').update({
                  'approvedNewPassword': request['newPassword'],
                  'passwordUpdatedAt': DateTime.now().millisecondsSinceEpoch,
                  'passwordChangeStatus': 'approved',
                  'passwordChangeRequestId': request['requestId'],
                });

                // Update status permintaan
                await _databaseRef
                    .child('passwordResetRequests/${request['requestId']}')
                    .update({
                  'status': 'approved',
                  'processedAt': DateTime.now().millisecondsSinceEpoch,
                  'processedBy': 'admin',
                  'adminNotes': 'Password disetujui dan siap digunakan',
                });

                // Simpan aktivitas
                await _databaseRef.child('activities').push().set({
                  'type': 'password_reset_approved',
                  'title': 'Reset Password Disetujui',
                  'message': 'Reset password untuk ${request['userName']} telah disetujui. User dapat login dengan password baru.',
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'userId': request['userId'],
                  'userName': request['userName'],
                  'adminAction': true,
                });

                // Hapus dari daftar permintaan
                setState(() {
                  _passwordResetRequests.removeWhere(
                    (req) => req['requestId'] == request['requestId']
                  );
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reset password disetujui. User dapat login dengan password baru.'),
                    backgroundColor: Colors.green,
                  ),
                );

              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 8, 66, 37)),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
  }

  // Method untuk reject reset password
  void _rejectPasswordReset(Map<String, dynamic> request) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          bool _isSubmitting = false;
          
          return AlertDialog(
            backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.white,
            title: Text(
              'Tolak Reset Password',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Masukkan alasan penolakan untuk ${request['userName']}:',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: 'Alasan penolakan...',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100],
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: _isSubmitting ? null : () async {
                  if (reasonController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Harap masukkan alasan penolakan'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  setState(() => _isSubmitting = true);

                  try {
                    // Update status permintaan
                    await _databaseRef
                        .child('passwordResetRequests/${request['requestId']}')
                        .update({
                      'status': 'rejected',
                      'processedAt': DateTime.now().millisecondsSinceEpoch,
                      'processedBy': 'admin',
                      'reason': reasonController.text,
                      'adminNotes': 'Permintaan ditolak: ${reasonController.text}',
                    });

                    // Simpan aktivitas
                    await _databaseRef.child('activities').push().set({
                      'type': 'password_reset_rejected',
                      'title': 'Reset Password Ditolak',
                      'message': 'Reset password untuk ${request['userName']} ditolak: ${reasonController.text}',
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                      'userId': request['userId'],
                      'userName': request['userName'],
                      'adminAction': true,
                    });

                    // Hapus dari daftar permintaan
                    setState(() {
                      _passwordResetRequests.removeWhere(
                        (req) => req['requestId'] == request['requestId']
                      );
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reset password ditolak'),
                        backgroundColor: Colors.orange,
                      ),
                    );

                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } finally {
                    setState(() => _isSubmitting = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Tolak'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Widget untuk menampilkan notifikasi reset password
  Widget _buildResetPasswordNotification() {
    if (_passwordResetRequests.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: Colors.orange, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ada ${_passwordResetRequests.length} permintaan reset password',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Klik untuk melihat dan menyetujui',
                  style: TextStyle(
                    color: Colors.orange.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _showResetRequests = true),
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.orange, size: 16),
          ),
        ],
      ),
    );
  }

  // Widget untuk panel permintaan reset password
  Widget _buildResetRequestsPanel() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final cardColor = isDarkMode ? Colors.grey[800]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_reset, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Permintaan Reset Password',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.orange),
                onPressed: () => setState(() => _showResetRequests = false),
              ),
            ],
          ),
          const Divider(color: Colors.orange),
          
          if (_passwordResetRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 10),
                    Text(
                      'Tidak ada permintaan reset password',
                      style: TextStyle(color: textColor),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _passwordResetRequests.map((request) {
                final requestedDate = _formatDate(request['requestedAt']);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[900]! : Colors.grey[50]!,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request['userName'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              request['email'],
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Diajukan: $requestedDate',
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PillIcon(
                            Icons.check,
                            Colors.green,
                            () => _approvePasswordReset(request),
                            isDarkMode,
                          ),
                          const SizedBox(width: 8),
                          _PillIcon(
                            Icons.close,
                            Colors.red,
                            () => _rejectPasswordReset(request),
                            isDarkMode,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _addFarmer() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tambah Petani Baru',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: isDarkMode ? Colors.white : const Color(0xFF344054),
                  ),
                ),
                const SizedBox(height: 16),
                _inputField('Nama Lengkap', nameController, isDarkMode),
                const SizedBox(height: 12),
                _inputField('Email', emailController, isDarkMode, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _inputField('Password', passwordController, isDarkMode, obscureText: true),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(0, 52),
                      ),
                      onPressed: () async {
                        if (nameController.text.isEmpty ||
                            emailController.text.isEmpty ||
                            passwordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nama, email, dan password harus diisi'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        try {
                          UserCredential userCredential = await FirebaseAuth.instance
                              .createUserWithEmailAndPassword(
                            email: emailController.text,
                            password: passwordController.text,
                          );

                          await _databaseRef
                              .child('users')
                              .child(userCredential.user!.uid)
                              .set({
                            'name': nameController.text,
                            'email': emailController.text,
                            'role': 'farmer',
                            'createdAt': DateTime.now().millisecondsSinceEpoch,
                            'lastLogin': DateTime.now().millisecondsSinceEpoch,
                            'status': 'active',
                            'displayName': nameController.text,
                            'farmCount': 0,
                            'passwordChangeStatus': 'none',
                            'approvedNewPassword': null,
                          });

                          // Tambah activity log
                          await _databaseRef
                              .child('activities')
                              .push()
                              .set({
                            'type': 'farmer_registered',
                            'title': 'Petani Baru Terdaftar',
                            'message': '${nameController.text} telah didaftarkan sebagai petani baru',
                            'timestamp': DateTime.now().millisecondsSinceEpoch,
                            'userId': userCredential.user!.uid,
                            'userName': nameController.text,
                          });

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Petani berhasil ditambahkan'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } on FirebaseAuthException catch (e) {
                          String errorMessage = 'Terjadi kesalahan';
                          if (e.code == 'email-already-in-use') {
                            errorMessage = 'Email sudah digunakan';
                          } else if (e.code == 'weak-password') {
                            errorMessage = 'Password terlalu lemah';
                          } else if (e.code == 'invalid-email') {
                            errorMessage = 'Format email tidak valid';
                          }
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $errorMessage'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Simpan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller,
    bool isDarkMode, {
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String hintText = '',
  }) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.black,
          ),
          hintText: hintText.isNotEmpty ? hintText : null,
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
          filled: true,
          fillColor: isDarkMode ? Colors.grey[700]! : const Color(0xFFF2F4F7),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  void _editFarmer(Map<String, dynamic> farmer) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    final TextEditingController nameController = TextEditingController(text: farmer['name']);
    final TextEditingController emailController = TextEditingController(text: farmer['email']);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Edit Data Petani',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: isDarkMode ? Colors.white : const Color(0xFF344054),
                  ),
                ),
                const SizedBox(height: 16),
                _inputField('Nama Lengkap', nameController, isDarkMode),
                const SizedBox(height: 12),
                _inputField('Email', emailController, isDarkMode, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(0, 52),
                      ),
                      onPressed: () async {
                        if (nameController.text.isNotEmpty &&
                            emailController.text.isNotEmpty) {
                          await _databaseRef.child('users').child(farmer['id']).update({
                            'name': nameController.text,
                            'email': emailController.text,
                            'displayName': nameController.text,
                          });

                          // Tambah activity log
                          await _databaseRef
                              .child('activities')
                              .push()
                              .set({
                            'type': 'farmer_updated',
                            'title': 'Data Petani Diperbarui',
                            'message': 'Data ${farmer['name']} telah diperbarui',
                            'timestamp': DateTime.now().millisecondsSinceEpoch,
                            'userId': farmer['id'],
                            'userName': nameController.text,
                          });

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Data petani berhasil diperbarui'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Simpan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteFarmer(Map<String, dynamic> farmer) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.white,
        title: Text(
          'Hapus Petani',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus ${farmer['name']}? Semua data terkait juga akan dihapus.',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.black,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Tambah activity log sebelum menghapus
                await _databaseRef
                    .child('activities')
                    .push()
                    .set({
                      'type': 'farmer_deleted',
                      'title': 'Petani Dihapus',
                      'message': '${farmer['name']} telah dihapus dari sistem',
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                      'userId': farmer['id'],
                      'userName': farmer['name'],
                    });

                // Hapus data dari database
                await _databaseRef.child('users').child(farmer['id']).remove();
                
                // Hapus juga permintaan reset password terkait
                final requestsSnapshot = await _databaseRef
                    .child('passwordResetRequests')
                    .orderByChild('userId')
                    .equalTo(farmer['id'])
                    .once();
                
                final requestsData = requestsSnapshot.snapshot.value as Map<dynamic, dynamic>?;
                if (requestsData != null) {
                  requestsData.forEach((key, value) async {
                    await _databaseRef.child('passwordResetRequests/$key').remove();
                  });
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Petani berhasil dihapus'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? Colors.grey[900]! : const Color(0xFFF6F7FB);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF344054);
    final textSecondaryColor = isDarkMode ? Colors.grey[400]! : const Color(0xFF667085);
    final cardColor = isDarkMode ? Colors.grey[800]! : Colors.white;
    final borderColor = isDarkMode ? Colors.grey[700]! : const Color(0xFFE4E7EC);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.12), 
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Manajemen Petani",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Kelola data petani dan akses sistem SmartFarm",
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notifikasi reset password
                  _buildResetPasswordNotification(),

                  // SEARCH BAR + ADD BUTTON
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[700]! : const Color(0xFFF2F4F7),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.12),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(
                              color: textColor,
                            ),
                            decoration: InputDecoration(
                              hintText: "Cari nama atau email petani...",
                              hintStyle: TextStyle(
                                color: textSecondaryColor,
                              ),
                              prefixIcon: Icon(
                                Icons.search, 
                                color: isDarkMode ? Colors.grey[400] : const Color(0xFF98A2B3)
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _addButtonColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: _addFarmer,
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text("Tambah Petani"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Panel permintaan reset password (jika ada dan ditampilkan)
            if (_showResetRequests && _passwordResetRequests.isNotEmpty)
              _buildResetRequestsPanel(),

            // TABLE/CARD AREA
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    // TABLE HEADER dengan border
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.12),
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _Col("Nama Petani", 3, isDarkMode),
                          _Col("Email", 3, isDarkMode),
                          _Col("Tanggal Daftar", 2, isDarkMode),
                          _Col("Status", 1, isDarkMode),
                          _Col("Aksi", 2, isDarkMode, center: true),
                        ],
                      ),
                    ),

                    // DATA LIST
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: isDarkMode ? Colors.white : _primaryColor,
                              ),
                            )
                          : _filteredFarmers.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    border: Border.all(color: borderColor, width: 1),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(14),
                                      bottomRight: Radius.circular(14),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.12),
                                        blurRadius: 3,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 60,
                                        color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        "Belum ada petani terdaftar",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Silakan tambah petani baru",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    border: Border.all(color: borderColor, width: 1),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(14),
                                      bottomRight: Radius.circular(14),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.12),
                                        blurRadius: 3,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    itemCount: _filteredFarmers.length,
                                    itemBuilder: (context, index) {
                                      final farmer = _filteredFarmers[index];
                                      final isActive = farmer['status'] == 'active';
                                      final joinDate = _formatDate(farmer['createdAt']);

                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: borderColor,
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(isDarkMode ? 0.1 : 0.12),
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Row(
                                            children: [
                                              _Text(farmer['name'], 3, isDarkMode, bold: true),
                                              _Text(farmer['email'], 3, isDarkMode),
                                              _Text(joinDate, 2, isDarkMode),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isActive
                                                        ? Colors.green.withOpacity(0.1)
                                                        : Colors.red.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: isActive ? Colors.green : Colors.red,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isActive ? 'Aktif' : 'Nonaktif',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: isActive ? Colors.green : Colors.red,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    _PillIcon(
                                                      Icons.edit,
                                                      Colors.blue,
                                                      () => _editFarmer(farmer),
                                                      isDarkMode,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    _PillIcon(
                                                      Icons.delete,
                                                      Colors.red,
                                                      () => _deleteFarmer(farmer),
                                                      isDarkMode,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// WIDGET UNTUK KOLOM HEADER
class _Col extends StatelessWidget {
  final String text;
  final int flex;
  final bool center;
  final bool isDarkMode;

  const _Col(this.text, this.flex, this.isDarkMode, {this.center = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.grey[400] : const Color(0xFF667085),
        ),
      ),
    );
  }
}

// WIDGET UNTUK TEKS DALAM CELL
class _Text extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;
  final bool isDarkMode;

  const _Text(this.text, this.flex, this.isDarkMode, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w500 : FontWeight.normal,
          color: isDarkMode ? Colors.white : const Color(0xFF344054),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// WIDGET UNTUK ICON BUTTON
class _PillIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _PillIcon(this.icon, this.color, this.onTap, this.isDarkMode);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}