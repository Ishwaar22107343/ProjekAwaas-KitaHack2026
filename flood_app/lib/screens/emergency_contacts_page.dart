import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../constants.dart';
import '../widgets/awaas_app_bar.dart';

class EmergencyContactsPage extends StatelessWidget {
  const EmergencyContactsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AwaasAppBar(title: "Emergency Contacts"),
      body: Column(
        children: [
          // Warning banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: danger.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: danger, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "In an emergency, call 999 immediately. Do not attempt to cross dangerous floodwaters.",
                    style: TextStyle(color: textPrimary, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          // Contact list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: emergencyContacts.length,
              itemBuilder: (_, i) {
                final c = emergencyContacts[i];
                final color = Color(c['color'] as int);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(c['icon'] as IconData, color: color, size: 22),
                    ),
                    title: Text(
                      c['name'] as String,
                      style: const TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      c['number'] as String,
                      style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                    trailing: GestureDetector(
                      onTap: () async {
                        final uri = Uri(scheme: 'tel', path: c['number'] as String);
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not open dialler. Please call manually.')),
                            );
                          }
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.call_rounded, color: color, size: 20),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}