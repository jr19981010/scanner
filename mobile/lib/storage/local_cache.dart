import 'package:hive/hive.dart';
import 'package:omr_shared/omr_shared.dart';

/// Small Hive-backed cache so the mobile app can grade offline if the socket
/// drops mid-quiz. Pull the exam + answer key once via REST, save here, replay
/// queued scans on reconnect.
class LocalCache {
  LocalCache(this.box);
  final Box box;

  Future<void> cacheExam(Exam exam, List<AnswerKeyEntry> key) async {
    await box.put('exam:${exam.id}', exam.toJson());
    await box.put(
        'key:${exam.id}', key.map((e) => e.toJson()).toList(growable: false));
  }

  Exam? exam(int id) {
    final j = box.get('exam:$id');
    return j == null ? null : Exam.fromJson(Map<String, dynamic>.from(j));
  }

  List<AnswerKeyEntry>? answerKey(int examId) {
    final j = box.get('key:$examId') as List?;
    return j
        ?.map((e) => AnswerKeyEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> queueScan(ScanSubmission s) async {
    final q = (box.get('queue') as List?) ?? <dynamic>[];
    q.add(s.toJson());
    await box.put('queue', q);
  }

  List<ScanSubmission> drainQueue() {
    final q = (box.get('queue') as List?) ?? const [];
    box.put('queue', <dynamic>[]);
    return q
        .map((e) => ScanSubmission.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
