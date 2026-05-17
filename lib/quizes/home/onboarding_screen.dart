// ============================================================
// FILE: lib/quizes/home/onboarding_screen.dart
// CHANGES: Ads and Premium functionality commented out.
//   Skeleton loading on lazy pages retained.
// ============================================================

// import 'package:QuizSphere/ads/provider/premium_provider.dart'; // ADS DISABLED
// import 'package:QuizSphere/ads/screen/premium_screen.dart';     // ADS DISABLED
// import 'package:QuizSphere/ads/widgets/banner_ad_widget.dart';  // ADS DISABLED
import 'package:QuizSphere/features/battle/screens/battle_home_screen.dart';
import 'package:QuizSphere/quizes/admin/screens/admin_dashboard_screen.dart';
import 'package:QuizSphere/quizes/home/daily_quiz/daily_quiz_entry_screen.dart';
import 'package:QuizSphere/quizes/home/history_screen.dart';
import 'package:QuizSphere/quizes/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/tournament/screens/tournament_list_screen.dart';
import '../../features/performance/screens/performance_dashboard_screen.dart';

import 'home_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  final List<Widget> _pages = const [
    _LazyPage(child: HomePage()),
    _LazyPage(child: DailyQuizEntryScreen()),
    // _LazyPage(child: BattleHomeScreen()),
    _LazyPage(child: TournamentListScreen()),
    _LazyPage(child: HistoryScreen()),
    _LazyPage(child: ProfileScreen()),
  ];

  final List<String> _titles = const [
    'QuizAura',
    'Daily Quiz',
    // '⚔️ Battle',
    '🏆 Tournaments',
    'History',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    // final isPremium = ref.watch(isPremiumProvider); // ADS DISABLED

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,

        // ── APP BAR ──────────────────────────────────────────────────────
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            _titles[_index],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
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
          actions: [
            // ── Premium / Remove Ads button DISABLED ─────────────────
            // if (!isPremium) TextButton.icon(...) // ADS DISABLED

            // Performance dashboard icon
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PerformanceDashboardScreen(),
                ),
              ),
              icon: const Icon(Icons.insights_outlined, color: Colors.white70),
              tooltip: 'Performance',
            ),
          ],
        ),

        // ── BODY ─────────────────────────────────────────────────────────
        body: Column(
          children: [
            Expanded(
              child: IndexedStack(index: _index, children: _pages),
            ),
            // const BannerAdWidget(), // ADS DISABLED
          ],
        ),

        // ── FAB (Admin — only on Home tab) ────────────────────────────
        floatingActionButton: _index == 0
            ? FloatingActionButton.extended(
                backgroundColor: Colors.white.withOpacity(0.95),
                foregroundColor: Colors.black,
                elevation: 8,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminDashboardScreen(),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text(
                  'Create Quiz',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            : null,

        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

        // ── BOTTOM NAV BAR ────────────────────────────────────────────
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
              selectedFontSize: 10,
              unselectedFontSize: 10,
              onTap: (i) {
                if (i != _index) setState(() => _index = i);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.local_fire_department_outlined),
                  activeIcon: Icon(Icons.local_fire_department),
                  label: 'Daily',
                ),
                // BottomNavigationBarItem(
                //   icon: Icon(Icons.sports_kabaddi_outlined),
                //   activeIcon: Icon(Icons.sports_kabaddi),
                //   label: 'Battle',
                // ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.emoji_events_outlined),
                  activeIcon: Icon(Icons.emoji_events),
                  label: 'Tournaments',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_outlined),
                  activeIcon: Icon(Icons.history),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Lazy page wrapper ────────────────────────────────────────────────────────
class _LazyPage extends StatefulWidget {
  final Widget child;
  const _LazyPage({required this.child});

  @override
  State<_LazyPage> createState() => _LazyPageState();
}

class _LazyPageState extends State<_LazyPage> {
  bool _visited = false;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: true,
      maintainState: true,
      child: Builder(
        builder: (ctx) {
          if (!_visited) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _visited = true);
            });
            return const _PageSkeleton();
          }
          return widget.child;
        },
      ),
    );
  }
}

// ── Page skeleton ─────────────────────────────────────────────────────────────
class _PageSkeleton extends StatelessWidget {
  const _PageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.tealAccent,
          strokeWidth: 2,
        ),
      ),
    );
  }
}
