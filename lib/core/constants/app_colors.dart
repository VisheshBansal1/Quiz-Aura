import 'package:flutter/material.dart';

/// Centralized color tokens — keeps UI consistent across all screens.
/// All new screens MUST use these instead of hardcoded Color() values.
class AppColors {
  AppColors._();

  // ── Background gradient (matches existing app) ──────────────────────────
  static const Color bgDark    = Color(0xFF0F2027);
  static const Color bgMid     = Color(0xFF203A43);
  static const Color bgLight   = Color(0xFF2C5364);

  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgDark, bgMid, bgLight],
  );

  // ── Login screen gradient ────────────────────────────────────────────────
  static const LinearGradient loginGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
  );

  // ── Glass effect ─────────────────────────────────────────────────────────
  static Color glassBg    = Colors.white.withOpacity(0.08);
  static Color glassBg12  = Colors.white.withOpacity(0.12);
  static Color glassBorder = Colors.white.withOpacity(0.15);
  static Color glassBorder25 = Colors.white.withOpacity(0.25);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted     = Colors.white60;

  // ── Accent ───────────────────────────────────────────────────────────────
  static const Color accentTeal    = Colors.teal;
  static const Color accentAmber   = Colors.amber;
  static const Color accentGreen   = Color(0xFF4CAF50);
  static const Color accentRed     = Color(0xFFEF5350);
  static const Color accentOrange  = Colors.orangeAccent;
  static const Color accentPurple  = Color(0xFF9C27B0);
  static const Color accentBlue    = Color(0xFF2196F3);

  // ── Battle ───────────────────────────────────────────────────────────────
  static const Color battleRed     = Color(0xFFEF5350);
  static const Color battleBlue    = Color(0xFF2196F3);
  static const Color battleGold    = Color(0xFFFFD700);

  // ── Tournament ───────────────────────────────────────────────────────────
  static const Color tournamentGold   = Color(0xFFFFD700);
  static const Color tournamentSilver = Color(0xFFC0C0C0);
  static const Color tournamentBronze = Color(0xFFCD7F32);

  // ── Rank colors ───────────────────────────────────────────────────────────
  static Color rankColor(int rank) {
    switch (rank) {
      case 1: return tournamentGold;
      case 2: return tournamentSilver;
      case 3: return tournamentBronze;
      default: return textSecondary;
    }
  }
}
