enum AnalysisResult { none, proceed, turnBack }

class AnalysisRecord {
  final String imagePath;
  final AnalysisResult result;
  final String reason;
  final DateTime time;

  AnalysisRecord({
    required this.imagePath,
    required this.result,
    required this.reason,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'result': result.index,
    'reason': reason,
    'time': time.toIso8601String(),
  };

  factory AnalysisRecord.fromJson(Map<String, dynamic> j) => AnalysisRecord(
    imagePath: j['imagePath'],
    result: AnalysisResult.values[j['result']],
    reason: j['reason'],
    time: DateTime.parse(j['time']),
  );
}