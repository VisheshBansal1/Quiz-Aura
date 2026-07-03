import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// AiQuizAccessService — central web/mobile access gate for
/// "AI Quiz Generation".
///
/// AI Quiz Generation (Groq-powered MCQ generation — used by both the
/// per-quiz "AI Generate" flow on `AiGenerateQuestionsScreen` and the
/// Daily Quiz "Generate with AI" flow on `AdminDailyQuizManagerScreen`)
/// is intentionally mobile-only (Android/iOS).
///
/// On web (`kIsWeb == true`) the feature must be fully disabled:
///   • no navigation to the AI generation screen
///   • no Groq API calls
///   • every tap on an AI-generation entry point shows the same message
///
/// Every entry point (buttons, cards, menu items, FABs, dashboard tiles,
/// etc.) should route its tap handler through [guard] instead of
/// re-implementing the `kIsWeb` check locally. That keeps the disabled
/// behavior, message copy, and button copy consistent — and maintained in
/// exactly one place — across the whole app.
/// ─────────────────────────────────────────────────────────────────────────
class AiQuizAccessService {
  AiQuizAccessService._();

  /// True when AI Quiz Generation must be disabled — i.e. running on web.
  /// Always false on Android/iOS, so mobile behavior is untouched.
  static bool get isBlockedOnWeb => kIsWeb;

  /// Message shown whenever a web user taps an AI Quiz Generation entry
  /// point.
  static const String blockedMessage =
      'AI Quiz Generation is available only in our mobile application. '
      'Please download the app to continue.';

  /// Replacement label for AI-generation buttons when running on web.
  static const String webButtonLabel = 'Download App for AI Quiz';

  /// Icon to pair with an AI-generation button when running on web.
  static const IconData webIcon = Icons.download_rounded;

  /// Returns [webButtonLabel] on web, or [mobileLabel] unchanged on
  /// Android/iOS. Use this to build the text for any AI-generation button.
  static String buttonLabel(String mobileLabel) =>
      isBlockedOnWeb ? webButtonLabel : mobileLabel;

  /// Returns [webIcon] on web, or [mobileIcon] unchanged on Android/iOS.
  static IconData buttonIcon(IconData mobileIcon) =>
      isBlockedOnWeb ? webIcon : mobileIcon;

  /// Wrap any AI Quiz Generation tap handler with this call.
  ///
  /// * Android/iOS → runs [onAllowed] immediately; behavior is 100%
  ///   unchanged.
  /// * Web         → shows [blockedMessage] and returns. [onAllowed] is
  ///   never invoked, so there is no navigation and no AI generation call.
  static void guard(BuildContext context, VoidCallback onAllowed) {
    if (isBlockedOnWeb) {
      showBlockedMessage(context);
      return;
    }
    onAllowed();
  }

  /// Shows the standard "mobile only" SnackBar. Exposed separately so a
  /// screen can self-guard (e.g. bail out if it is ever reached directly
  /// on web) without going through [guard].
  static void showBlockedMessage(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(blockedMessage),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
  }
}
