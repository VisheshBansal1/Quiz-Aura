// ============================================================
// FILE: lib/quizes/profile/about_screen.dart
//
// "About" screen — reachable from Profile → Quick Actions → About.
// Tells the user about the QuizAura app itself, and about EnquSoft,
// the company behind it, with tappable contact links (email /
// YouTube / Instagram).
//
// DEPENDENCY NOTE: this screen uses the official `url_launcher`
// package to open the email client and social links. If it isn't
// already in pubspec.yaml, add it with:
//     flutter pub add url_launcher
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../ads/widgets/banner_ad_widget.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // ── Brand / contact constants ────────────────────────────────────────────
  static const String _appName = 'QuizAura';
  static const String _companyName = 'EnquSoft';
  static const String _email = 'enqusoft@gmail.com';
  static const String _youtubeUrl =
      'https://youtube.com/@enqusoft?si=s34s-2rPPuyTsO-q';
  static const String _instagramUrl =
      'https://www.instagram.com/enqusoft/?utm_source=ig_web_button_share_sheet';

  // ── Link helpers ──────────────────────────────────────────────────────────

  static String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _openEmail(BuildContext context) => _openLink(
        context,
        Uri(
          scheme: 'mailto',
          path: _email,
          query: _encodeQueryParameters(
            {'subject': 'Regarding $_appName App'},
          ),
        ),
      );

  Future<void> _openYouTube(BuildContext context) =>
      _openLink(context, Uri.parse(_youtubeUrl));

  Future<void> _openInstagram(BuildContext context) =>
      _openLink(context, Uri.parse(_instagramUrl));

  Future<void> _openLink(BuildContext context, Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('launchUrl returned false for $uri');
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, "Couldn't open that link.");
      }
    }
  }

  Future<void> _copyToClipboard(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) _showMessage(context, 'Copied "$value" to clipboard');
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          backgroundColor: const Color(0xFF203A43),
        ),
      );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'About',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AppHeaderCard(),

                const SizedBox(height: 18),

                // ── 01 · About the app ────────────────────────────────────
                _SectionCard(
                  icon: Icons.info_outline_rounded,
                  number: '01',
                  title: 'About $_appName',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_appName is a competitive quiz platform built to '
                        'make learning engaging, social, and rewarding. Test '
                        'your knowledge across a wide range of topics, '
                        'challenge others in real time, and track your '
                        'growth every step of the way.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _FeatureRow(
                        icon: Icons.quiz_rounded,
                        text:
                            'Quizzes across a wide range of topics and difficulty levels',
                      ),
                      const _FeatureRow(
                        icon: Icons.bolt_rounded,
                        text: 'Real-time 1v1 Battles',
                      ),
                      const _FeatureRow(
                        icon: Icons.emoji_events_rounded,
                        text: 'Tournaments and competitive events',
                      ),
                      const _FeatureRow(
                        icon: Icons.school_rounded,
                        text: 'College communities and leaderboards',
                      ),
                      const _FeatureRow(
                        icon: Icons.local_fire_department_rounded,
                        text: 'Daily Quiz with streak tracking',
                      ),
                      const _FeatureRow(
                        icon: Icons.workspace_premium_rounded,
                        text: 'XP, levels, coins, badges and certificates',
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── 02 · About the company ────────────────────────────────
                _SectionCard(
                  icon: Icons.business_rounded,
                  number: '02',
                  title: 'About $_companyName',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_appName is proudly developed by $_companyName, a '
                        'software, application, and website development '
                        'company building digital products for everyday, '
                        'general-purpose use.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Beyond our own apps, $_companyName partners with '
                        'individuals and businesses to turn ideas into fully '
                        'working products. Have a concept for an app, '
                        'website, or piece of software in mind? Send it our '
                        'way by email, DM, or comment — we\'ll help bring it '
                        'to life.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── 03 · Contact ───────────────────────────────────────────
                _SectionCard(
                  icon: Icons.connect_without_contact_rounded,
                  number: '03',
                  title: 'Get in Touch',
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Have an idea, feedback, or a question? Reach us '
                            'through any of the channels below.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                      _ContactTile(
                        icon: Icons.email_rounded,
                        color: Colors.tealAccent,
                        label: 'Email',
                        subtitle: _email,
                        onTap: () => _openEmail(context),
                        onCopy: () => _copyToClipboard(context, _email),
                      ),
                      Divider(color: Colors.white.withOpacity(0.08), height: 22),
                      _ContactTile(
                        icon: Icons.smart_display_rounded,
                        color: const Color(0xFFFF4B4B),
                        label: 'YouTube',
                        subtitle: '@enqusoft',
                        onTap: () => _openYouTube(context),
                        onCopy: () => _copyToClipboard(context, _youtubeUrl),
                      ),
                      Divider(color: Colors.white.withOpacity(0.08), height: 22),
                      _ContactTile(
                        icon: Icons.camera_alt_rounded,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF833AB4),
                            Color(0xFFE1306C),
                            Color(0xFFF77737),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        label: 'Instagram',
                        subtitle: '@enqusoft',
                        onTap: () => _openInstagram(context),
                        onCopy: () => _copyToClipboard(context, _instagramUrl),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                Center(
                  child: Text(
                    'Developed with care by $_companyName',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '© 2026 $_companyName. All rights reserved.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BannerAdWidget(screenName: 'about'),
    );
  }
}

// ── App header banner ────────────────────────────────────────────────────

class _AppHeaderCard extends StatelessWidget {
  const _AppHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7B4FFF), Color(0xFF00E5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: DecorationImage(image: AssetImage("assets/logo/app_logo.png",),fit: BoxFit.cover),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            
          ),
          const SizedBox(height: 16),
          const Text(
            'QuizAura',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'KNOWLEDGE  ·  BATTLE  ·  CONQUER',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Built by EnquSoft',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable numbered section card ───────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String number;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.number,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.tealAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: TextStyle(
                        color: Colors.tealAccent.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withOpacity(0.08)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Feature bullet row ───────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isLast;

  const _FeatureRow({
    required this.icon,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.tealAccent, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact tile (tap to open, trailing icon to copy) ────────────────────

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Gradient? gradient;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  const _ContactTile({
    required this.icon,
    this.color,
    this.gradient,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: gradient == null ? color?.withOpacity(0.15) : null,
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: gradient == null ? color : Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onCopy,
          tooltip: 'Copy',
          icon: Icon(
            Icons.copy_rounded,
            color: Colors.white.withOpacity(0.4),
            size: 18,
          ),
        ),
      ],
    );
  }
}
