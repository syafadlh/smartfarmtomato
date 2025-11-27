import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AppUser {
  static final Map<String, Map<String, dynamic>> _cache = {};
  static final Map<String, DateTime> _timestamps = {};

  static Future<Map<String, dynamic>> getUserRole(String uid) async {
    // Safety check untuk uid yang valid
    if (uid.isEmpty) {
      return _createDefaultUser(uid);
    }

    try {
      // Cek cache (valid 15 menit)
      if (_cache.containsKey(uid)) {
        final cacheTime = _timestamps[uid];
        if (cacheTime != null &&
            DateTime.now().difference(cacheTime).inMinutes < 15) {
          return _cache[uid]!;
        }
      }

      final ref = FirebaseDatabase.instance.ref("users/$uid");
      final snap = await ref.get().timeout(const Duration(seconds: 4));

      if (snap.exists && snap.value != null) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        _cache[uid] = data;
        _timestamps[uid] = DateTime.now();
        return data;
      } else {
        return await _createDefaultUser(uid);
      }
    } catch (e) {
      print('⚠️ Error in getUserRole: $e');
      return await _createDefaultUser(uid);
    }
  }

  static Future<Map<String, dynamic>> _createDefaultUser(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email?.toLowerCase() ?? '';

      String role = email.contains("admin") ? "admin" : "farmer";

      final data = {
        "email": user?.email,
        "role": role,
        "status": "active",
        "displayName": email.split("@").first,
        "createdAt": DateTime.now().millisecondsSinceEpoch,
        "lastLogin": DateTime.now().millisecondsSinceEpoch,
      };

      // Simpan ke Firebase secara async (jangan block)
      if (uid.isNotEmpty) {
        FirebaseDatabase.instance.ref("users/$uid").set(data).catchError((e) {
          print('⚠️ Error saving user data: $e');
        });
      }

      _cache[uid] = data;
      _timestamps[uid] = DateTime.now();

      return data;
    } catch (e) {
      print('❌ Error creating default user: $e');
      // Fallback data
      return {
        "email": FirebaseAuth.instance.currentUser?.email,
        "role": "farmer",
        "status": "active",
        "displayName": "User",
        "createdAt": DateTime.now().millisecondsSinceEpoch,
      };
    }
  }

  // Hanya ketika logout
  static void clearCache() {
    _cache.clear();
    _timestamps.clear();
  }

  static Future<void> preloadUser(String uid) async {
    if (_cache.containsKey(uid) || uid.isEmpty) return;
    try {
      final ref = FirebaseDatabase.instance.ref("users/$uid");
      final snap = await ref.get().timeout(const Duration(seconds: 3));
      if (snap.exists && snap.value != null) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        _cache[uid] = data;
        _timestamps[uid] = DateTime.now();
      }
    } catch (e) {
      print('⚠️ Preload user error: $e');
    }
  }
}