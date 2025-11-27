import 'package:flutter/material.dart';
import '../screens/farmer/dashboard/farmer_dashboard.dart';
import '../screens/farmer/control/farmer_control.dart';
import '../screens/farmer/history/farmer_history.dart';
import '../screens/farmer/settings/farmer_settings.dart';

class FarmerNavigation extends StatefulWidget {
  const FarmerNavigation({super.key});

  @override
  State<FarmerNavigation> createState() => _FarmerNavigationState();
}

class _FarmerNavigationState extends State<FarmerNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const FarmerDashboardScreen(),
    const ControlScreen(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).cardColor,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.control_camera),
            label: 'Kontrol',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}