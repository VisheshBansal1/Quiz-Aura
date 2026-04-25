import 'package:flutter/material.dart';

class MenuItemTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool enabled;

  const MenuItemTile({
    super.key,
    required this.icon,
    required this.title,
    this.trailingText,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color tileColor = const Color(0xFF1C1A2E);
    final Color disabledColor = Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          splashFactory: InkRipple.splashFactory,
          splashColor: Colors.deepPurpleAccent.withOpacity(0.15),
          highlightColor: Colors.transparent,
          child: Opacity(
            opacity: enabled ? 1 : 0.6,
            child: ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Icon(
                icon,
                size: 22,
                color: enabled ? Colors.grey[300] : disabledColor,
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: enabled ? Colors.white : disabledColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              trailing: trailingText != null
                  ? Text(
                      trailingText!,
                      style: TextStyle(
                        color: enabled
                            ? Colors.grey.shade400
                            : disabledColor,
                        fontSize: 13,
                      ),
                    )
                  : Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: enabled
                          ? Colors.grey.shade400
                          : disabledColor,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
