import 'package:flutter/material.dart';
import '../theme.dart';
import '../constants.dart';
import '../widgets/awaas_app_bar.dart';

class FloodRiskMapPage extends StatelessWidget {
  const FloodRiskMapPage({Key? key}) : super(key: key);

  Color _riskColor(String risk) {
    if (risk == 'High')   return danger;
    if (risk == 'Medium') return warn;
    return safe;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AwaasAppBar(title: "Flood Risk Map"),
      body: Column(
        children: [
          // Legend
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentDim.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _LegendDot(color: danger, label: "High Risk"),
                _LegendDot(color: warn,   label: "Medium Risk"),
                _LegendDot(color: safe,   label: "Low Risk"),
              ],
            ),
          ),
          // Disclaimer
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: warn.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: warn.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: warn, size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Based on historical flood data (2015–2024). Check JPS Malaysia for real-time alerts.",
                    style: TextStyle(color: warn, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: floodAreas.length,
              itemBuilder: (_, i) {
                final area = floodAreas[i];
                final color = _riskColor(area['risk']!);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(area['state']!, style: const TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(area['area']!, style: const TextStyle(color: textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          area['risk']!,
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: textSecondary, fontSize: 12)),
    ],
  );
}