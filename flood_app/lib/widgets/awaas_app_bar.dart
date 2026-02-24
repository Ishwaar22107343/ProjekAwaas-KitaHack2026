import 'package:flutter/material.dart';
import '../theme.dart';

class AwaasAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const AwaasAppBar({Key? key, required this.title}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: bgCard,
    elevation: 0,
    title: Text(title,
        style: const TextStyle(
            color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
    iconTheme: const IconThemeData(color: accent),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: accent.withValues(alpha: 0.1)),
    ),
  );
}