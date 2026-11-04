import 'package:flutter/material.dart';
import 'package:QuizSphere/ads/widgets/banner_ad_widget.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1C2C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1C2C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.white.withOpacity(0.1),
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Banner ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF928DAB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shield_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Privacy Policy – QuizAura',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Last updated: June 2025',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We value your privacy. This policy explains how QuizAura '
                    'collects, uses, and protects your personal information.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Section 1 ──────────────────────────────────────────────
            _PolicySection(
              icon: Icons.info_outline_rounded,
              number: '01',
              title: 'Information We Collect',
              items: const [
                _PolicyItem(
                  icon: Icons.person_rounded,
                  text: 'Name',
                ),
                _PolicyItem(
                  icon: Icons.email_rounded,
                  text: 'Email address',
                ),
                _PolicyItem(
                  icon: Icons.account_circle_rounded,
                  text: 'Profile picture (if Google login is used)',
                ),
                _PolicyItem(
                  icon: Icons.quiz_rounded,
                  text: 'Quiz scores',
                ),
                _PolicyItem(
                  icon: Icons.leaderboard_rounded,
                  text: 'Leaderboard data',
                ),
                _PolicyItem(
                  icon: Icons.bar_chart_rounded,
                  text: 'App usage information',
                ),
                _PolicyItem(
                  icon: Icons.phone_android_rounded,
                  text: 'Device information',
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Section 2 ──────────────────────────────────────────────
            _PolicySection(
              icon: Icons.help_outline_rounded,
              number: '02',
              title: 'Why We Collect Data',
              items: const [
                _PolicyItem(
                  icon: Icons.how_to_reg_rounded,
                  text: 'To create user accounts',
                ),
                _PolicyItem(
                  icon: Icons.save_rounded,
                  text: 'To save quiz progress',
                ),
                _PolicyItem(
                  icon: Icons.emoji_events_rounded,
                  text: 'To display leaderboards',
                ),
                _PolicyItem(
                  icon: Icons.speed_rounded,
                  text: 'To improve app performance',
                ),
                _PolicyItem(
                  icon: Icons.gpp_maybe_rounded,
                  text: 'To prevent cheating and misuse',
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Section 3 ──────────────────────────────────────────────
            _PolicySection(
              icon: Icons.share_rounded,
              number: '03',
              title: 'Data Sharing',
              paragraphs: const [
                'We do not sell users\' personal information to any third parties.',
                'Some information may be processed using Firebase services provided by Google to support app functionality.',
              ],
            ),

            const SizedBox(height: 14),

            // ── Section 4 ──────────────────────────────────────────────
            _PolicySection(
              icon: Icons.lock_rounded,
              number: '04',
              title: 'Data Security',
              paragraphs: const [
                'User data is stored securely and protected from unauthorized access using industry-standard security measures and Firebase security rules.',
              ],
            ),

            const SizedBox(height: 14),

            // ── Section 5 ──────────────────────────────────────────────
            _PolicySection(
              icon: Icons.child_care_rounded,
              number: '05',
              title: 'Children\'s Privacy',
              paragraphs: const [
                'QuizAura is not intended for children under the age of 13 without parental supervision. We encourage parents to monitor their children\'s use of the app.',
              ],
            ),

            const SizedBox(height: 14),

            // ── Section 6 ──────────────────────────────────────────────
            _PolicySection(
              icon: Icons.contact_mail_rounded,
              number: '06',
              title: 'Contact Us',
              paragraphs: const [
                'If you have any questions or concerns about this Privacy Policy, please reach out to us:',
              ],
              contact: 'enqusoft@gmail.com',
            ),

            const SizedBox(height: 30),

            // ── Footer ─────────────────────────────────────────────────
            Center(
              child: Text(
                '© 2025 QuizAura. All rights reserved.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: const BannerAdWidget(screenName: 'privacy_policy'),
    );
  }
}

// ── Reusable Section Card ────────────────────────────────────────────────────

class _PolicySection extends StatelessWidget {
  final IconData icon;
  final String number;
  final String title;
  final List<_PolicyItem> items;
  final List<String> paragraphs;
  final String? contact;

  const _PolicySection({
    required this.icon,
    required this.number,
    required this.title,
    this.items = const [],
    this.paragraphs = const [],
    this.contact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF928DAB)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: const TextStyle(
                        color: Color(0xFF928DAB),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (items.isNotEmpty || paragraphs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.08),
            ),
            const SizedBox(height: 14),
          ],

          // Bullet Items
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon,
                        color: const Color(0xFF928DAB), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.text,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          // Paragraphs
          ...paragraphs.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  p,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              )),

          // Contact Email
          if (contact != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alternate_email_rounded,
                      color: Color(0xFF928DAB), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    contact!,
                    style: const TextStyle(
                      color: Color(0xFFB3AEFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Policy Item Model ────────────────────────────────────────────────────────

class _PolicyItem {
  final IconData icon;
  final String text;

  const _PolicyItem({required this.icon, required this.text});
}