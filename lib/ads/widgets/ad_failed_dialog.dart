// ============================================================================
// AdFailedDialog
//
// The "Ad Couldn't Be Loaded" dialog shown whenever a rewarded ad fails to
// load or show for a free user gated behind one. Pure presentation only —
// it owns no ad or premium logic itself. The caller decides what Retry /
// Go Premium / Cancel actually DO, which keeps this dialog reusable for
// any future ad-gated feature, not just the quiz-result gate it was built
// for.
//
// Usage:
//   showDialog(
//     context: context,
//     barrierDismissible: false,
//     builder: (_) => AdFailedDialog(
//       onRetry: () { ... },
//       onGoPremium: () { ... },
//       onCancel: () { ... },
//     ),
//   );
// ============================================================================

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class AdFailedDialog extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onGoPremium;
  final VoidCallback onCancel;

  const AdFailedDialog({
    super.key,
    required this.onRetry,
    required this.onGoPremium,
    required this.onCancel,
  });

  static const List<String> _causes = [
    'Ad Blockers',
    'Private DNS',
    'VPN',
    'Network filtering',
    'Poor Internet connection',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgMid,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.orangeAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Ad Couldn't Be Loaded",
              style: TextStyle(color: Colors.white, fontSize: 17),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This free feature requires watching a rewarded ad.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 10),
            const Text(
              "We couldn't load an ad on your device.",
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 10),
            const Text(
              'This is commonly caused by:',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 6),
            for (final cause in _causes)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '•  $cause',
                  style: const TextStyle(color: Colors.white60, height: 1.4),
                ),
              ),
            const SizedBox(height: 10),
            const Text(
              'Please disable these if enabled and try again.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        SizedBox(
          width: double.maxFinite,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Retry',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: onGoPremium,
                  icon: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 18,
                    color: Colors.amberAccent,
                  ),
                  label: const Text(
                    'Go Premium',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.amberAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
