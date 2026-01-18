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
        extendBody: true,
        backgroundColor: Colors.transparent,

        // ===== APP BAR =====
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            _titles[_index],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
              ),
            ),
          ),
        ),

        // ===== BODY =====
        body: IndexedStack(index: _index, children: _pages),

        // ===== FLOATING CREATE QUIZ BUTTON =====
        floatingActionButton: _index == 0
            ? FloatingActionButton.extended(
                backgroundColor: Colors.white.withOpacity(0.95),
                foregroundColor: Colors.black,
                elevation: 8,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  "Create Quiz",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            : null,

        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

        // ===== BOTTOM NAV BAR =====
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withOpacity(0.12),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BottomNavigationBar(
              currentIndex: _index,
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white60,
              onTap: (i) {
                if (i != _index) {
                  setState(() => _index = i);
                }
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: "History",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
