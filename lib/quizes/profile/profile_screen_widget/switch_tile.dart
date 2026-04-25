import 'package:flutter/material.dart';

class SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  const SwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabledColor = Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: const Color(0xFF1C1A2E),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? () => onChanged(!value) : null,
          splashColor: Colors.deepPurpleAccent.withOpacity(0.2),
          highlightColor: Colors.transparent,
          child: ListTile(
            dense: true,
            leading: Icon(
              icon,
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
            trailing: Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: Colors.deepPurpleAccent,
              inactiveThumbColor: disabledColor,
              inactiveTrackColor: disabledColor.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }
}
