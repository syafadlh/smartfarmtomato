// ignore_for_file: undefined_class, unused_local_variable
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

  @override
  void initState() {
    super.initState();
    _loadFarmers();
    _searchController.addListener(_searchFilter);
  }

  void _loadFarmers() {
    _databaseRef.child('users').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      final List<Map<String, dynamic>> farmers = [];

      if (data != null) {
        data.forEach((key, value) {
          if (value['role'] == 'farmer') {
            farmers.add({
              'id': key,
              'name': value['name'] ?? 'Unknown',
              'email': value['email'] ?? '-',
            });
          }
        });
      }

      // Add dummy farmers if none exist
      if (farmers.isEmpty) {
        farmers.addAll([
          {'id': 'farmer1', 'name': 'Syafa', 'email': 'syafa@example.com'},
          {'id': 'farmer2', 'name': 'Nadyne', 'email': 'nadyne@example.com'},
          {'id': 'farmer3', 'name': 'April', 'email': 'april@example.com'},
        ]);
      }

      setState(() {
        _farmers = farmers;
        _filteredFarmers = farmers;
        _isLoading = false;
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

  void _showNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifikasi: Tidak ada notifikasi baru')),
    );
  }

  void _addFarmer() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Petani Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  emailController.text.isNotEmpty &&
                  passwordController.text.isNotEmpty) {
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
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Petani berhasil ditambahkan')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _editFarmer(Map<String, dynamic> farmer) {
    final TextEditingController nameController =
        TextEditingController(text: farmer['name']);
    final TextEditingController emailController =
        TextEditingController(text: farmer['email']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Petani'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  emailController.text.isNotEmpty) {
                await _databaseRef.child('users').child(farmer['id']).update({
                  'name': nameController.text,
                  'email': emailController.text,
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Petani berhasil diupdate')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteFarmer(Map<String, dynamic> farmer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Petani'),
        content: Text('Apakah Anda yakin ingin menghapus ${farmer['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _databaseRef.child('users').child(farmer['id']).remove();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Petani berhasil dihapus')),
              );
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //------------------------------------------------------------------
            // HEADER FIGMA STYLE
            //------------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back, size: 26),
                  const SizedBox(width: 8),

                  // TEXT TITLE
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Management User SmartFarm",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          "Kelola data pengguna dan akses sistem SmartFarm.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        )
                      ],
                    ),
                  ),

                  // NOTIFICATION ICON
                  GestureDetector(
                    onTap: _showNotifications,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFE4EEC8),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Color(0xFF6E8036),
                      ),
                    ),
                  )
                ],
              ),
            ),

            //------------------------------------------------------------------
            // SEARCH + TAMBAH PETANI
            //------------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  // SEARCH BAR
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: "Search",
                          icon: Icon(Icons.search),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ADD BUTTON
                  ElevatedButton(
                    onPressed: _addFarmer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCC4B31),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Tambah Petani",
                      style: TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  )
                ],
              ),
            ),

            //------------------------------------------------------------------
            // TABLE HEADER
            //------------------------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.white,
              child: const Row(
                children: [
                  Expanded(
                      flex: 1,
                      child: Text("No",
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                      flex: 4,
                      child: Text("Name",
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                      flex: 2,
                      child: Text("Action",
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),

            //------------------------------------------------------------------
            // DATA TABLE LIST
            //------------------------------------------------------------------
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredFarmers.isEmpty
                      ? const Center(child: Text("Tidak ada data"))
                      : ListView.builder(
                          itemCount: _filteredFarmers.length,
                          itemBuilder: (context, index) {
                            final farmer = _filteredFarmers[index];

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 0.6,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Text("${index + 1}",
                                        style: const TextStyle(fontSize: 14)),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      farmer['name'],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        IconButton(
                                          onPressed: () => _editFarmer(farmer),
                                          icon: const Icon(Icons.edit,
                                              color: Colors.green),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _deleteFarmer(farmer),
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
