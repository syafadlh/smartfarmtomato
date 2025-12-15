import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signin_screen.dart';

class LocalNotificationService {
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  static Future<void> notifyPasswordResetRequest(
    String userName,
    String userEmail,
    String userId,
    String requestId,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newRef = _databaseRef.child('admin_notifications').push();

      await newRef.set({
        'title': '🔐 Permintaan Reset Password',
        'message': '$userName ($userEmail) mengajukan permintaan reset password',
        'timestamp': timestamp,
        'isRead': false,
        'type': 'warning',
        'source': 'password_reset',
        'action': 'password_reset_request',
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'requestId': requestId,
        'category': 'password_reset',
        'priority': 'high',
      });

      print('✅ Notifikasi: Permintaan reset password - $userName');
    } catch (e) {
      print('❌ Error notifikasi reset password: $e');
    }
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _requestSent = false;

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _submitPasswordChangeRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password dan konfirmasi password tidak cocok'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password minimal 6 karakter'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final newPassword = _newPasswordController.text;
      
      // Cek apakah email terdaftar
      final usersSnapshot = await _databaseRef
          .child('users')
          .orderByChild('email')
          .equalTo(email)
          .once();
      
      final usersData = usersSnapshot.snapshot.value as Map<dynamic, dynamic>?;
      
      if (usersData == null || usersData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email tidak ditemukan'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Ambil user ID
      final userId = usersData.keys.first;
      final userData = usersData[userId] as Map<dynamic, dynamic>;
      final userName = userData['name'] ?? userData['displayName'] ?? 'User';

      // Cek apakah sudah ada permintaan pending
      final existingRequestsSnapshot = await _databaseRef
          .child('passwordResetRequests')
          .orderByChild('userId')
          .equalTo(userId)
          .once();
      
      final existingRequests = existingRequestsSnapshot.snapshot.value as Map<dynamic, dynamic>?;
      
      if (existingRequests != null) {
        final pendingRequests = existingRequests.values.where((req) => 
          req['status'] == 'pending').toList();
        
        if (pendingRequests.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda sudah memiliki permintaan reset password yang sedang diproses'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // Simpan permintaan reset password
      final requestRef = _databaseRef.child('passwordResetRequests').push();
      final requestId = requestRef.key!;
      
      await requestRef.set({
        'userId': userId,
        'userName': userName,
        'email': email,
        'newPassword': newPassword,
        'status': 'pending', 
        'requestedAt': DateTime.now().millisecondsSinceEpoch,
        'processedAt': null,
        'processedBy': null,
        'reason': null,
        'adminNotes': null,
      });

      // Update status user
      await _databaseRef.child('users/$userId').update({
        'passwordChangeStatus': 'pending',
        'passwordChangeRequestId': requestId,
      });

      // ✅ KIRIM NOTIFIKASI KE ADMIN - MENGGUNAKAN SERVICE LOKAL
      await LocalNotificationService.notifyPasswordResetRequest(
        userName,
        email,
        userId,
        requestId,
      );

      // Simpan aktivitas
      await _databaseRef.child('activities').push().set({
        'type': 'password_reset_requested',
        'title': 'Permintaan Reset Password',
        'message': '$userName mengajukan permintaan reset password',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'userId': userId,
        'userName': userName,
        'adminAction': false,
      });

      setState(() {
        _isLoading = false;
        _requestSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permintaan perubahan password telah dikirim ke admin'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // 🔙 Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                const SizedBox(height: 10),

                // 🍅 Logo Tomat
                Image.asset(
                  'images/tomato.png',
                  height: 250,
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  _requestSent ? 'Permintaan Terkirim' : 'Reset Password',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF264E36),
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  _requestSent
                      ? 'Permintaan reset password telah dikirim ke admin. Silakan tunggu approval.'
                      : 'Masukkan email dan password baru untuk reset password',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 30),

                if (!_requestSent) ...[
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email tidak boleh kosong';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Email tidak valid';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  // New Password Field
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password tidak boleh kosong';
                      }
                      if (value.length < 6) {
                        return 'Password minimal 6 karakter';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_showConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_showConfirmPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Konfirmasi password tidak boleh kosong';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 25),

                  // Info penting
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Informasi Penting:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Password baru akan aktif setelah disetujui oleh admin. Anda akan dapat login dengan password baru setelah approval.',
                          style: TextStyle(
                            color: Color.fromARGB(255, 83, 138, 201),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitPasswordChangeRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : const Text(
                              'Ajukan Reset Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  // Status setelah request
                  Card(
                    color: Colors.blue[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.pending_actions, size: 80, color: Colors.orange),
                          const SizedBox(height: 20),
                          const Text(
                            'Menunggu Approval Admin',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Email: ${_emailController.text}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: const Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.schedule, color: Colors.orange, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      'Status Permintaan:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Permintaan Anda sedang ditinjau oleh admin. Anda akan mendapatkan notifikasi ketika sudah disetujui.',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 186, 86, 61),
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignInScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                'Kembali ke Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _requestSent = false;
                                _emailController.clear();
                                _newPasswordController.clear();
                                _confirmPasswordController.clear();
                              });
                            },
                            child: const Text(
                              'Ajukan permintaan baru',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // Back to Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Ingat password? ',
                      style: TextStyle(fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignInScreen(),
                        ),
                      ),
                      child: const Text(
                        'Masuk di sini',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}