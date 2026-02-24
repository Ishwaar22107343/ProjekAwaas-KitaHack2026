import 'package:flutter/material.dart';
import '../theme.dart';

class DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const DrawerItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: bgSurface, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: accent, size: 18),
      ),
      title: Text(label,
          style: const TextStyle(
              color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: badge != null
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge!,
                  style: const TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            )
          : const Icon(Icons.chevron_right_rounded,
              color: textSecondary, size: 20),
      onTap: onTap,
    );
  }
}