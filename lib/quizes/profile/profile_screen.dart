// ============================================================
// FILE: lib/quizes/profile/profile_screen.dart
//
// BUGS FIXED:
//  FIX 1: ProfileScreen is now a StatefulWidget so initState can
//          call StreakService + seed missing Firestore fields.
//  FIX 2: StreakService.updateStreak() is called in initState —
//          streak was always 0 because it was NEVER called.
//  FIX 3: _seedMissingFields() writes email / displayName / uid
//          from FirebaseAuth into Firestore on first open —
//          fixes blank email and "User" name for OAuth users.
//  FIX 4: Email display falls back to user.email when Firestore
//          field is empty (handles email/password users whose
//          registration code skipped writing the email field).
//  FIX 5: Logout used pushReplacementNamed('/login') → no named
//          routes defined. Now pushAndRemoveUntil to LoginScreen.
//  FIX 6: EditProfileScreen called with deprecated name/email
//          params → now called with no args (loads its own data).
//  FIX 7: HeaderSection imagePath reads 'photoUrl' field
//          (Firebase Storage URL) not 'profileImage' (old path).
// ============================================================

import 'package:QuizSphere/features/college/screens/college_hub_screen.dart';
import 'package:QuizSphere/login/login_screen.dart';
import 'package:QuizSphere/quizes/profile/profile_screen_widget/header_section.dart';
import 'package:QuizSphere/quizes/profile/profile_screen_widget/info_card.dart';
import 'package:QuizSphere/quizes/profile/profile_screen_widget/logout_tile.dart';
import 'package:QuizSphere/quizes/profile/services/level_service.dart';
import 'package:QuizSphere/quizes/profile/services/streak_service.dart';
import 'package:QuizSphere/ads/widgets/banner_ad_widget.dart';
// import 'package:QuizSphere/ads/screen/premium_screen.dart'; // ADS DISABLED
// import 'package:QuizSphere/ads/provider/premium_provider.dart'; // ADS DISABLED
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'profile_screen_widget/xp_level_card.dart';
import '../../features/college/screens/college_onboarding_screen.dart';
import '../../features/college/screens/college_leaderboard_screen.dart';
import '../../features/leaderboard/screens/global_leaderboard_screen.dart';
import '../../features/leaderboard/screens/branch_leaderboard_screen.dart';
import '../../features/rewards/screens/badges_screen.dart';
import '../../features/performance/screens/performance_dashboard_screen.dart';
import 'edit_profile_screen.dart';
import 'about_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    StreakService.updateStreak();
    _seedMissingFields();
  }

  /// Reads the current Firebase Auth user and fills any empty Firestore
  /// fields (uid, email, name) so the profile UI is never blank.
  Future<void> _seedMissingFields() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    final snap = await docRef.get();
    final data = snap.exists ? (snap.data() ?? {}) : <String, dynamic>{};

    final updates = <String, dynamic>{};

    // Seed uid — always safe to write
    if (data['uid'] == null || (data['uid'] as String).isEmpty) {
      updates['uid'] = user.uid;
    }

    final firestoreEmail = (data['email'] as String?) ?? '';
    if (firestoreEmail.isEmpty && (user.email?.isNotEmpty ?? false)) {
      updates['email'] = user.email!;
    }

    // Seed name from displayName (Google / Apple sign-in sets this)
    final firestoreName = (data['name'] as String?) ?? '';
    if ((firestoreName.isEmpty || firestoreName == 'User') &&
        (user.displayName?.isNotEmpty ?? false)) {
      updates['name'] = user.displayName!;
    }

    // Seed photoUrl from Firebase Auth photoURL (Google profile picture)
    final firestorePhoto = (data['photoUrl'] as String?) ?? '';
    if (firestorePhoto.isEmpty && (user.photoURL?.isNotEmpty ?? false)) {
      updates['photoUrl'] = user.photoURL!;
    }

    if (updates.isNotEmpty) {
      // Use set+merge so it creates the doc if it doesn't exist yet
      await docRef.set(updates, SetOptions(merge: true));
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _gradientBg() => Container(
    decoration: const BoxDecoration(gradient: AppColors.mainGradient),
  );

  Widget _glassContainer({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: Colors.white.withOpacity(0.08),
      border: Border.all(color: Colors.white.withOpacity(0.15)),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'User not logged in',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _gradientBg(),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _ProfileSkeleton();
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(
                  child: Text(
                    'Profile not found',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              final data = snapshot.data!.data()!;

              // fields are empty (covers email/password AND OAuth users).
              final name = () {
                final n = (data['name'] as String?) ?? '';
                if (n.isNotEmpty && n != 'User') return n;
                return user.displayName?.isNotEmpty == true
                    ? user.displayName!
                    : (n.isNotEmpty ? n : 'User');
              }();

              final email = () {
                final e = (data['email'] as String?) ?? '';
                if (e.isNotEmpty) return e;
                return user.email ?? '';
              }();

              final level = (data['level'] ?? 1) as int;
              final xp = (data['xp'] ?? 0) as int;
              final totalXp = (data['totalXp'] ?? 0) as int;
              final requiredXp = (data['requiredXp'] ?? 100) as int;
              final streak = (data['streakCount'] ?? 0) as int;
              final coins = (data['coins'] ?? 0) as int;
              final badges = List<String>.from(data['badges'] ?? []);
              final collegeId = data['collegeId'] as String?;
              final collegeName = (data['collegeName'] as String?) ?? '';
              final branch = (data['branch'] as String?) ?? 'CSE';
              final rankTitle = LevelService.getRankTitle(level);

              // EditProfileScreen) with fallback to old 'profileImage' field
              final photoUrl =
                  (data['photoUrl'] as String?) ??
                  (data['profileImage'] as String?) ??
                  user
                      .photoURL // Auth photo fallback
                      ??
                  '';

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Header
                      HeaderSection(
                        name: name,
                        email: email,
                        imagePath: photoUrl,
                        onProfileUpdated:
                            (updatedName, updatedEmail, updatedImage) async {
                              final updates = <String, dynamic>{
                                'name': updatedName,
                                'email': updatedEmail,
                              };
                              if (updatedImage != null &&
                                  updatedImage.isNotEmpty) {
                                updates['photoUrl'] = updatedImage;
                              }
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .update(updates);
                            },
                      ),

                      const SizedBox(height: 16),

                      // XP & Level Card
                      XpLevelCard(
                        level: level,
                        xp: xp,
                        requiredXp: requiredXp,
                        totalXp: totalXp,
                      ),

                      const SizedBox(height: 16),

                      // Coins + Badges + Streak
                      _glassContainer(
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BadgesScreen(),
                                  ),
                                ),
                                child: _statColumn(
                                  '🪙',
                                  '$coins',
                                  'Coins',
                                  Colors.amber,
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 60,
                              color: Colors.white12,
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BadgesScreen(),
                                  ),
                                ),
                                child: _statColumn(
                                  '🏅',
                                  '${badges.length}',
                                  'Badges',
                                  Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 60,
                              color: Colors.white12,
                            ),
                            Expanded(
                              child: _statColumn(
                                '🔥',
                                '$streak',
                                'Streak',
                                Colors.orangeAccent,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      InfoCard(
                        icon: Icons.person,
                        label: 'Name',
                        value: name,
                        iconColor: Colors.blueAccent,
                      ),
                      const SizedBox(height: 8),
                      InfoCard(
                        icon: Icons.email,
                        label: 'Email',
                        value: email,
                        iconColor: Colors.orangeAccent,
                      ),
                      const SizedBox(height: 8),
                      InfoCard(
                        icon: Icons.workspace_premium,
                        label: 'Rank',
                        value: rankTitle,
                        iconColor: Colors.purpleAccent,
                      ),

                      const SizedBox(height: 16),

                      // College section
                      _glassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.school,
                                  color: Colors.tealAccent,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'College',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (collegeId != null &&
                                collegeName.isNotEmpty) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          collegeName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          branch,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CollegeLeaderboardScreen(
                                              collegeId: collegeId,
                                              collegeName: collegeName,
                                            ),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.tealAccent,
                                      side: const BorderSide(
                                        color: Colors.tealAccent,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      'Leaderboard',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CollegeOnboardingScreen(),
                                    ),
                                  ),
                                  icon: const Icon(Icons.group_add),
                                  label: const Text('Join or Create College'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Leaderboards
                      _glassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.leaderboard,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Leaderboards',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _LeaderboardTile(
                              icon: '🌍',
                              label: 'Global Leaderboard',
                              subtitle: 'All-time top players worldwide',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const GlobalLeaderboardScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _LeaderboardTile(
                              icon: '🎓',
                              label: 'Branch Leaderboard',
                              subtitle: 'Top players in $branch',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const BranchLeaderboardScreen(),
                                ),
                              ),
                            ),
                            if (collegeId != null) ...[
                              const SizedBox(height: 8),
                              _LeaderboardTile(
                                icon: '🏫',
                                label: 'College Leaderboard',
                                subtitle: collegeName,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CollegeHubScreen(
                                      collegeId: collegeId!,
                                      collegeName: collegeName!,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Quick actions
                      _glassContainer(
                        child: Column(
                          children: [
                            _QuickActionTile(
                              icon: Icons.insights,
                              label: 'Performance Dashboard',
                              color: Colors.purple,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const PerformanceDashboardScreen(),
                                ),
                              ),
                            ),
                            const Divider(color: Colors.white12),
                            _QuickActionTile(
                              icon: Icons.military_tech,
                              label: 'My Badges & Certificates',
                              color: Colors.amber,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BadgesScreen(),
                                ),
                              ),
                            ),
                            const Divider(color: Colors.white12),

                            _QuickActionTile(
                              icon: Icons.edit,
                              label: 'Edit Profile',
                              color: Colors.teal,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen(),
                                ),
                              ),
                            ),
                            const Divider(color: Colors.white12),
                            _QuickActionTile(
                              icon: Icons.info_outline_rounded,
                              label: 'About',
                              color: Colors.blueAccent,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AboutScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Go Premium / Remove Ads — ADS DISABLED ──
                      // _PremiumTile(), // ADS DISABLED
                      const SizedBox(height: 12),

                      LogoutTile(
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Log Out'),
                              content: const Text(
                                'Are you sure you want to log out?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Log Out',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          try {
                            // Sign out Google first (so picker shows on next login)
                            try {
                              await GoogleSignIn(
                                clientId: kIsWeb
                                    ? '296193820246-6bqlgd3ss35q0pgclm4c7jj538kq7e4a.apps.googleusercontent.com'
                                    : null,
                              ).signOut();
                            } catch (_) {}
                            // Sign out Firebase
                            await FirebaseAuth.instance.signOut();
                            // Explicitly navigate to LoginScreen and clear the entire stack
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Logout failed: $e')),
                              );
                            }
                          }
                        },
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: const BannerAdWidget(screenName: 'profile'),
    );
  }

  Widget _statColumn(
    String emoji,
    String value,
    String label,
    Color valueColor,
  ) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────

class _LeaderboardTile extends StatelessWidget {
  final String icon, label, subtitle;
  final VoidCallback onTap;
  const _LeaderboardTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30, size: 18),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white30, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Go Premium tile — ADS DISABLED ──────────────────────────────────────────
// _PremiumTile class removed. Ads and payments are disabled in this build.

// ── Profile skeleton loading ──────────────────────────────────────────────────
class _ProfileSkeleton extends StatefulWidget {
  const _ProfileSkeleton();

  @override
  State<_ProfileSkeleton> createState() => _ProfileSkeletonState();
}

class _ProfileSkeletonState extends State<_ProfileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _bar(double w, double h) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(h / 2),
        color: Color.lerp(
          Colors.white.withOpacity(0.07),
          Colors.white.withOpacity(0.18),
          _anim.value,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Avatar circle
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.2),
                  _anim.value,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _bar(140, 18),
          const SizedBox(height: 10),
          _bar(100, 13),
          const SizedBox(height: 32),
          // Stats row placeholders
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 0; i < 3; i++)
                Column(
                  children: [
                    _bar(50, 22),
                    const SizedBox(height: 8),
                    _bar(60, 12),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 28),
          // Card placeholders
          for (int i = 0; i < 4; i++) ...[
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Color.lerp(
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.14),
                    _anim.value,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
