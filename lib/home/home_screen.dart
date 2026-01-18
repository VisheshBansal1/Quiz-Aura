import 'package:flutter/material.dart';
import 'package:quiz_app/admin/screens/admin_dashboard_screen.dart';

import 'home_page.dart';
import 'history_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final List<Widget> _pages = const [
    HomePage(),
    HistoryScreen(),
    AdminDashboardScreen(), // 🔥 NEW
  ];

  final List<String> _titles = const [
    "Quiz App",
    "History",
    "Admin Dashboard", // 🔥 NEW
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_index != 0) {
          setState(() => _index = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_index]),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),

        // ✅ Keeps state alive
        body: IndexedStack(
          index: _index,
          children: _pages,
        ),

        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          type: BottomNavigationBarType.fixed, // 🔥 IMPORTANT (4 items)
          onTap: (i) {
            if (i != _index) {
              setState(() => _index = i);
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: "History",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box),
              label: "Create",
            ),
          ],
        ),
      ),
    );
  }
}
