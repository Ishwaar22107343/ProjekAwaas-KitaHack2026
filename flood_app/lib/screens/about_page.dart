import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/awaas_app_bar.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AwaasAppBar(title: "About"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHeroCard(),
            const SizedBox(height: 16),
            _buildSdgCard(),
            const SizedBox(height: 16),
            _buildTechStackCard(),
            const SizedBox(height: 16),
            _buildMissionCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accentDim.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.water_rounded, color: accent, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            "PROJEK AWAAS",
            style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3),
          ),
          const SizedBox(height: 6),
          const Text(
            "Your AI Safety Co-Pilot for Flooded Roads",
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: const Text(
              "v1.0.0 · KitaHack 2026",
              style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSdgCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentDim.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("UN SDG Alignment", style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              _SdgBadge(number: "3",  label: "Good Health\n& Well-being", color: const Color(0xFF4CAF50)),
              const SizedBox(width: 8),
              _SdgBadge(number: "11", label: "Sustainable\nCities",        color: const Color(0xFFFF9800)),
              const SizedBox(width: 8),
              _SdgBadge(number: "13", label: "Climate\nAction",            color: const Color(0xFF3F51B5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTechStackCard() {
    const rows = [
      [Icons.phone_android_rounded, "Frontend",  "Flutter & Dart"],
      [Icons.cloud_rounded,          "Backend",   "Google Cloud Functions (Python)"],
      [Icons.psychology_rounded,     "AI Model",  "Vertex AI · Gemini"],
      [Icons.storage_rounded,        "Database",  "Cloud Firestore"],
      [Icons.folder_rounded,         "Storage",   "Firebase Storage"],
      [Icons.lock_rounded,           "Auth",      "Firebase Authentication"],
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentDim.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Technology Stack", style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...rows.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(row[0] as IconData, color: accent, size: 16),
                const SizedBox(width: 10),
                Text(row[1] as String, style: const TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(row[2] as String, style: const TextStyle(color: textPrimary, fontSize: 12)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildMissionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentDim.withValues(alpha: 0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Our Mission", style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          SizedBox(height: 10),
          Text(
            "Floods are one of Malaysia's most recurring disasters. Projek Awaas was built to eliminate the dangerous guesswork drivers face at flooded roads — giving anyone an instant, AI-powered safety verdict using just their phone camera.",
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _SdgBadge extends StatelessWidget {
  final String number, label;
  final Color color;
  const _SdgBadge({required this.number, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text("SDG $number", style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: textSecondary, fontSize: 10, height: 1.3)),
          ],
        ),
      ),
    );
  }
}