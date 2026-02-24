import 'dart:io';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/analysis_record.dart';

class HistoryPage extends StatelessWidget {
  final List<AnalysisRecord> history;
  final VoidCallback onClear;

  const HistoryPage({Key? key, required this.history, required this.onClear}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgCard,
        title: const Text(
          "Scan History",
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: accent),
        actions: [
          if (history.isNotEmpty)
            TextButton(
              onPressed: () {
                onClear();
                Navigator.pop(context);
              },
              child: const Text("Clear All", style: TextStyle(color: danger, fontSize: 13)),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: accent.withValues(alpha: 0.1)),
        ),
      ),
      body: history.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, color: textSecondary, size: 52),
                  SizedBox(height: 12),
                  Text("No scans yet", style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text("Your scan history will appear here", style: TextStyle(color: textSecondary, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (_, i) {
                final rec = history[i];
                final isProceed = rec.result == AnalysisResult.proceed;
                final color = isProceed ? safe : danger;
                final timeStr =
                    "${rec.time.day.toString().padLeft(2, '0')}/${rec.time.month.toString().padLeft(2, '0')}/${rec.time.year}  "
                    "${rec.time.hour.toString().padLeft(2, '0')}:${rec.time.minute.toString().padLeft(2, '0')}";

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(rec.imagePath),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 64,
                            height: 64,
                            color: bgSurface,
                            child: const Icon(Icons.broken_image_outlined, color: textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isProceed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                  color: color,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isProceed ? "PROCEED" : "TURN BACK",
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              rec.reason,
                              style: const TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Text(timeStr, style: const TextStyle(color: textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}