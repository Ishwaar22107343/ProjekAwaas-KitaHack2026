import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/awaas_app_bar.dart';

class HowToUsePage extends StatelessWidget {
  const HowToUsePage({Key? key}) : super(key: key);

  static const _steps = [
    {'icon': Icons.location_on_rounded,    'title': 'Find a Flooded Road',    'desc': 'Approach a flooded area you need to cross. Keep your distance initially.'},
    {'icon': Icons.camera_alt_rounded,     'title': 'Open the App & Point',   'desc': 'Launch Projek Awaas and point your phone camera clearly at the flooded road ahead.'},
    {'icon': Icons.touch_app_rounded,      'title': 'Tap "Analyze Flood"',    'desc': 'Press the Analyze button. The app captures the image and sends it to our AI instantly.'},
    {'icon': Icons.cloud_upload_rounded,   'title': 'AI Processes the Image', 'desc': 'Google\'s Gemini AI model assesses water depth, flow, and road visibility.'},
    {'icon': Icons.check_circle_rounded,   'title': 'Get Your Decision',      'desc': 'In seconds, you\'ll see PROCEED (safe) or TURN BACK (dangerous) with a clear reason.'},
    {'icon': Icons.directions_car_rounded, 'title': 'Act on the Result',      'desc': 'Always follow the AI\'s advice. If in doubt, turn back — no road is worth your life.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AwaasAppBar(title: "How to Use"),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _steps.length,
        itemBuilder: (_, i) => _StepCard(
          number: i + 1,
          total: _steps.length,
          icon: _steps[i]['icon'] as IconData,
          title: _steps[i]['title'] as String,
          desc: _steps[i]['desc'] as String,
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int number, total;
  final IconData icon;
  final String title, desc;

  const _StepCard({
    required this.number,
    required this.total,
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "$number",
                    style: const TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (number < total)
                Container(width: 2, height: 20, color: accent.withValues(alpha: 0.15)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, color: accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: const TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}