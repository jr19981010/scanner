import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:omr_shared/omr_shared.dart';

class ApiClient {
  ApiClient(this.baseUrl, {this.pairingCode});
  final String baseUrl; // http://192.168.x.x:4040
  final String? pairingCode;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (pairingCode != null) 'x-pairing-code': pairingCode!,
      };

  Future<bool> health() async {
    final r = await http.get(Uri.parse('$baseUrl/health'));
    return r.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> listExams() async {
    final r = await http.get(Uri.parse('$baseUrl/exams'), headers: _headers);
    if (r.statusCode != 200) {
      throw StateError('exams fetch failed: ${r.statusCode}');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (j['exams'] as List).cast<Map<String, dynamic>>();
  }

  Future<({Exam exam, List<AnswerKeyEntry> key})> fetchExam(int id) async {
    final r = await http.get(Uri.parse('$baseUrl/exams/$id'), headers: _headers);
    if (r.statusCode != 200) {
      throw StateError('exam fetch failed: ${r.statusCode}');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (
      exam: Exam.fromJson(j['exam'] as Map<String, dynamic>),
      key: (j['answer_key'] as List)
          .cast<Map<String, dynamic>>()
          .map(AnswerKeyEntry.fromJson)
          .toList(),
    );
  }

  Future<Map<String, dynamic>> submitScan(ScanSubmission s) async {
    final r = await http.post(
      Uri.parse('$baseUrl/scans'),
      headers: _headers,
      body: jsonEncode(s.toJson()),
    );
    if (r.statusCode != 200) {
      throw StateError('scan submit failed: ${r.statusCode}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
