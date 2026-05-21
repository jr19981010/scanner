class ScanSubmission {
  final int examId;
  final String studentNo;
  final List<int> answers; // -1 = blank/ambiguous
  final String deviceId;

  const ScanSubmission({
    required this.examId,
    required this.studentNo,
    required this.answers,
    required this.deviceId,
  });

  factory ScanSubmission.fromJson(Map<String, dynamic> j) => ScanSubmission(
        examId: j['exam_id'] as int,
        studentNo: j['student_no'] as String,
        answers: (j['answers'] as List).cast<int>(),
        deviceId: j['device_id'] as String? ?? 'unknown',
      );

  Map<String, dynamic> toJson() => {
        'exam_id': examId,
        'student_no': studentNo,
        'answers': answers,
        'device_id': deviceId,
      };
}

class ScoreBroadcast {
  final int examId;
  final String studentNo;
  final String fullName;
  final int score;
  final int total;
  final double percentage;
  final DateTime scannedAt;
  final String deviceId;

  const ScoreBroadcast({
    required this.examId,
    required this.studentNo,
    required this.fullName,
    required this.score,
    required this.total,
    required this.percentage,
    required this.scannedAt,
    required this.deviceId,
  });

  factory ScoreBroadcast.fromJson(Map<String, dynamic> j) => ScoreBroadcast(
        examId: j['exam_id'] as int,
        studentNo: j['student_no'] as String,
        fullName: j['full_name'] as String,
        score: j['score'] as int,
        total: j['total'] as int,
        percentage: (j['percentage'] as num).toDouble(),
        scannedAt: DateTime.parse(j['scanned_at'] as String),
        deviceId: j['device_id'] as String? ?? 'unknown',
      );

  Map<String, dynamic> toJson() => {
        'exam_id': examId,
        'student_no': studentNo,
        'full_name': fullName,
        'score': score,
        'total': total,
        'percentage': percentage,
        'scanned_at': scannedAt.toIso8601String(),
        'device_id': deviceId,
      };
}
