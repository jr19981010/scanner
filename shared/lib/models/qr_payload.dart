import 'dart:convert';

class QrPayload {
  static const int currentVersion = 1;

  final int version;
  final String studentNo;
  final int examId;
  final int itemCount;
  final int choiceCount;

  const QrPayload({
    this.version = currentVersion,
    required this.studentNo,
    required this.examId,
    required this.itemCount,
    required this.choiceCount,
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'sid': studentNo,
        'eid': examId,
        'n': itemCount,
        'c': choiceCount,
      };

  String encode() => base64Url.encode(utf8.encode(jsonEncode(toJson())));

  factory QrPayload.decode(String raw) {
    final s = raw.trim();
    final jsonStr = s.startsWith('{')
        ? s
        : utf8.decode(base64Url.decode(_padBase64(s)));
    final j = jsonDecode(jsonStr) as Map<String, dynamic>;
    return QrPayload(
      version: j['v'] as int? ?? currentVersion,
      studentNo: j['sid'] as String,
      examId: j['eid'] as int,
      itemCount: j['n'] as int,
      choiceCount: j['c'] as int,
    );
  }

  static String _padBase64(String s) {
    final mod = s.length % 4;
    return mod == 0 ? s : s + '=' * (4 - mod);
  }
}
