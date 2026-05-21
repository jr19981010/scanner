import 'dart:convert';

import '../models/scan.dart';

enum WsMsgType { hello, scan, score, examUpdated, error, ack }

WsMsgType _typeFromString(String s) {
  switch (s) {
    case 'hello':
      return WsMsgType.hello;
    case 'scan':
      return WsMsgType.scan;
    case 'score':
      return WsMsgType.score;
    case 'exam_updated':
      return WsMsgType.examUpdated;
    case 'ack':
      return WsMsgType.ack;
    default:
      return WsMsgType.error;
  }
}

String _typeToString(WsMsgType t) {
  switch (t) {
    case WsMsgType.hello:
      return 'hello';
    case WsMsgType.scan:
      return 'scan';
    case WsMsgType.score:
      return 'score';
    case WsMsgType.examUpdated:
      return 'exam_updated';
    case WsMsgType.ack:
      return 'ack';
    case WsMsgType.error:
      return 'error';
  }
}

class WsMessage {
  final WsMsgType type;
  final Map<String, dynamic> payload;

  const WsMessage(this.type, this.payload);

  factory WsMessage.hello({required String device, String? pairingCode}) =>
      WsMessage(WsMsgType.hello, {
        'device': device,
        if (pairingCode != null) 'code': pairingCode,
      });

  factory WsMessage.scan(ScanSubmission s) =>
      WsMessage(WsMsgType.scan, s.toJson());

  String encode() => jsonEncode({
        'type': _typeToString(type),
        if (type == WsMsgType.scan || type == WsMsgType.score)
          'payload': payload
        else
          ...payload,
      });

  factory WsMessage.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final t = _typeFromString(j['type'] as String);
    final p = (j['payload'] as Map?)?.cast<String, dynamic>() ??
        (Map<String, dynamic>.from(j)..remove('type'));
    return WsMessage(t, p);
  }
}

/// Encoded into the pairing QR shown on the desktop dashboard. Mobile decodes
/// this string to auto-fill IP, port, and pairing code.
class PairingPayload {
  static const int currentVersion = 1;

  final int version;
  final String host;
  final int port;
  final String code;

  const PairingPayload({
    this.version = currentVersion,
    required this.host,
    required this.port,
    required this.code,
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'h': host,
        'p': port,
        'c': code,
      };

  String encode() => base64Url.encode(utf8.encode(jsonEncode(toJson())));

  factory PairingPayload.decode(String raw) {
    final s = raw.trim();
    final jsonStr = s.startsWith('{')
        ? s
        : utf8.decode(base64Url.decode(_padBase64(s)));
    final j = jsonDecode(jsonStr) as Map<String, dynamic>;
    return PairingPayload(
      version: j['v'] as int? ?? currentVersion,
      host: j['h'] as String,
      port: j['p'] as int,
      code: j['c'] as String,
    );
  }

  static String _padBase64(String s) {
    final mod = s.length % 4;
    return mod == 0 ? s : s + '=' * (4 - mod);
  }
}
