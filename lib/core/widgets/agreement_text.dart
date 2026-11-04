import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Shared "By continuing, you agree to..." text with tappable Terms &
/// Privacy links. Used on both the Login and Create Account screens so the
/// legal copy and link behavior live in one place instead of being
/// duplicated per screen.
class AgreementText extends StatelessWidget {
  const AgreementText({super.key});

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          height: 1.6,
        ),
        children: [
          const TextSpan(text: 'By continuing, you agree to QuizAura\n'),
          // ── Terms & Conditions link ──
          TextSpan(
            text: 'Terms & Conditions',
            style: const TextStyle(
              color: Color(0xFFB3AEFF),
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFFB3AEFF),
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Navigator.of(context).pushNamed('/terms'),
          ),
          const TextSpan(text: ' and '),
          // ── Privacy Policy link ──
          TextSpan(
            text: 'Privacy Policy',
            style: const TextStyle(
              color: Color(0xFFB3AEFF),
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFFB3AEFF),
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Navigator.of(context).pushNamed('/privacy'),
          ),
        ],
      ),
    );
  }
}
