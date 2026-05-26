import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
          'Terms & Conditions',
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
                  colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF11998E).withOpacity(0.4),
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
                        child: const Icon(Icons.gavel_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Terms & Conditions – QuizAura',
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
                    'By using QuizAura, you agree to be bound by these terms. '
                    'Please read them carefully before proceeding.',
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
            _TermsSection(
              icon: Icons.person_pin_rounded,
              number: '01',
              accentColor: const Color(0xFF6C63FF),
              title: 'User Responsibility',
              paragraphs: const [
                'Users must use QuizAura in a fair and ethical manner. Any form of cheating, '
                    'exploiting bugs, or misusing the platform is strictly prohibited.',
                'Accounts found violating this policy may be suspended or permanently banned.',
              ],
            ),

            const SizedBox(height: 14),

            // ── Section 2 ──────────────────────────────────────────────
            _TermsSection(
              icon: Icons.manage_accounts_rounded,
              number: '02',
              accentColor: const Color(0xFF38EF7D),
              title: 'Account Usage',
              paragraphs: const [
                'You are solely responsible for maintaining the confidentiality of your '
                    'account credentials and for all activities that occur under your account.',
                'Do not share your account with others or use another person\'s account.',
              ],
            ),

            const SizedBox(height: 14),

            // ── Section 3 ──────────────────────────────────────────────
            _TermsSection(
              icon: Icons.emoji_events_rounded,
              number: '03',
              accentColor: const Color(0xFFF7971E),
              title: 'Leaderboards and Rewards',
              paragraphs: const [
                'All rankings and scores on QuizAura leaderboards are generated automatically '
                    'based on quiz performance.',
                'Scores may change over time as other users participate. QuizAura does not '
                    'guarantee any specific position or reward.',
              ],
            ),

            const SizedBox(height: 14),

            // ── Section 4 ──────────────────────────────────────────────
            _TermsSection(
              icon: Icons.security_rounded,
              number: '04',
              accentColor: const Color(0xFFEE0979),
              title: 'Anti-Cheat Policy',
              paragraphs: const [
                'QuizAura employs measures to detect suspicious behavior, including but not '
                    'limited to: excessive tab switching, automated responses, or any other '
                    'unfair activity.',
                'Users found engaging in such activities will face appropriate action, '
                    'including score invalidation or account termination.',
              ],
              highlight: true,
            ),

            const SizedBox(height: 14),

            // ── Section 5 ──────────────────────────────────────────────
            _TermsSection(
              icon: Icons.update_rounded,
              number: '05',
              accentColor: const Color(0xFF4FACFE),
              title: 'Service Changes',
              paragraphs: const [
                'QuizAura reserves the right to update, modify, or discontinue any features '
                    'or services at any time without prior notice.',
                'Continued use of the app after changes constitutes acceptance of the updated terms.',
              ],
            ),

            const SizedBox(height: 20),

            // ── Agreement Box ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF38EF7D), size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'By creating an account and using QuizAura, you acknowledge that you '
                      'have read, understood, and agree to these Terms & Conditions.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
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
    );
  }
}

// ── Reusable Terms Section Card ──────────────────────────────────────────────

class _TermsSection extends StatelessWidget {
  final IconData icon;
  final String number;
  final String title;
  final List<String> paragraphs;
  final Color accentColor;
  final bool highlight;

  const _TermsSection({
    required this.icon,
    required this.number,
    required this.title,
    required this.paragraphs,
    required this.accentColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlight
            ? accentColor.withOpacity(0.08)
            : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight
              ? accentColor.withOpacity(0.35)
              : Colors.white.withOpacity(0.12),
        ),
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
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withOpacity(0.4)),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: TextStyle(
                        color: accentColor.withOpacity(0.8),
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
              if (highlight)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'IMPORTANT',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withOpacity(0.08)),
          const SizedBox(height: 14),

          // Paragraphs
          ...paragraphs.asMap().entries.map((entry) => Padding(
                padding: EdgeInsets.only(
                    bottom: entry.key < paragraphs.length - 1 ? 10 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}