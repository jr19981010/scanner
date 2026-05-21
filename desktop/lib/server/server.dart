import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:omr_shared/omr_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../db/database.dart';

class LocalServer {
  LocalServer({required this.db, this.port = 4040});

  final AppDatabase db;
  final int port;

  HttpServer? _http;
  String? _boundIp;
  String? get boundIp => _boundIp;

  final Set<WebSocketChannel> _authedClients = {};
  final StreamController<Map<String, dynamic>> _scoreStream =
      StreamController.broadcast();

  /// Stream of every score the server has accepted.
  Stream<Map<String, dynamic>> get scores => _scoreStream.stream;

  /// Stream of socket connection count changes (for the UI).
  final StreamController<int> _connectionCount =
      StreamController<int>.broadcast();
  Stream<int> get connectionCountStream => _connectionCount.stream;
  int get connectionCount => _authedClients.length;

  Future<void> start() async {
    final router = Router()
      ..get('/health', _health)
      ..get('/sections', _listSections)
      ..get('/exams', _listExams)
      ..get('/exams/<id|[0-9]+>', _examById)
      ..post('/scans', _submitScan);

    final wsHandler = webSocketHandler(_onSocket);

    final cascade = Cascade()
        .add((req) =>
            req.url.path == 'sync' ? wsHandler(req) : Response.notFound(''))
        .add(router.call)
        .handler;

    _http = await shelf_io.serve(
      const Pipeline()
          .addMiddleware(_cors())
          .addMiddleware(logRequests())
          .addHandler(cascade),
      InternetAddress.anyIPv4,
      port,
    );

    _boundIp = await _detectIp();
    // ignore: avoid_print
    print('OMR server listening on http://$_boundIp:$port '
        '(pairing code: ${db.pairingCode})');
  }

  Future<void> stop() async {
    for (final c in _authedClients) {
      await c.sink.close();
    }
    await _http?.close(force: true);
    await _scoreStream.close();
    await _connectionCount.close();
  }

  Middleware _cors() => (inner) => (req) async {
        if (req.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final r = await inner(req);
        return r.change(headers: {...r.headersAll, ..._corsHeaders});
      };

  static const _corsHeaders = {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'content-type, x-pairing-code',
  };

  bool _checkCode(Request req) {
    final h = req.headers['x-pairing-code'];
    return h == db.pairingCode;
  }

  // ---- HTTP handlers --------------------------------------------------------

  Response _health(Request _) => Response.ok(
        jsonEncode({'ok': true, 'version': 1}),
        headers: const {'content-type': 'application/json'},
      );

  Future<Response> _listSections(Request req) async {
    if (!_checkCode(req)) return Response.forbidden('bad code');
    final rows = await db.listSections();
    return _json({'sections': rows});
  }

  Future<Response> _listExams(Request req) async {
    if (!_checkCode(req)) return Response.forbidden('bad code');
    final rows = await db.listExams();
    return _json({'exams': rows});
  }

  Future<Response> _examById(Request req, String id) async {
    if (!_checkCode(req)) return Response.forbidden('bad code');
    final exam = await db.examById(int.parse(id));
    if (exam == null) return Response.notFound('exam not found');
    final key = await db.answerKey(exam.id!);
    return _json({
      'exam': exam.toJson(),
      'answer_key': key.map((e) => e.toJson()).toList(),
    });
  }

  Future<Response> _submitScan(Request req) async {
    if (!_checkCode(req)) return Response.forbidden('bad code');
    final body = await req.readAsString();
    final j = jsonDecode(body) as Map<String, dynamic>;
    final submission = ScanSubmission.fromJson(j);
    final result = await db.recordScan(submission);
    _broadcastScore(result);
    return _json(result);
  }

  Response _json(Object body) => Response.ok(jsonEncode(body),
      headers: const {'content-type': 'application/json'});

  // ---- WebSocket ------------------------------------------------------------

  void _onSocket(WebSocketChannel channel, String? _) {
    bool authed = false;
    channel.stream.listen(
      (raw) => _handleSocketMessage(channel, raw as String, () => authed,
          (v) => authed = v),
      onDone: () => _drop(channel),
      onError: (_) => _drop(channel),
    );
  }

  void _drop(WebSocketChannel ch) {
    if (_authedClients.remove(ch)) {
      _connectionCount.add(_authedClients.length);
    }
  }

  Future<void> _handleSocketMessage(WebSocketChannel ch, String raw,
      bool Function() isAuthed, void Function(bool) setAuthed) async {
    try {
      final msg = WsMessage.decode(raw);
      switch (msg.type) {
        case WsMsgType.hello:
          final code = msg.payload['code'] as String?;
          if (code != db.pairingCode) {
            ch.sink.add(jsonEncode(
                {'type': 'error', 'msg': 'pairing code mismatch'}));
            await ch.sink.close();
            return;
          }
          setAuthed(true);
          _authedClients.add(ch);
          _connectionCount.add(_authedClients.length);
          ch.sink.add(jsonEncode({'type': 'ack', 'server_version': 1}));
        case WsMsgType.scan:
          if (!isAuthed()) {
            ch.sink.add(jsonEncode(
                {'type': 'error', 'msg': 'not authed; send hello first'}));
            return;
          }
          final submission = ScanSubmission.fromJson(msg.payload);
          final result = await db.recordScan(submission);
          _broadcastScore(result);
          ch.sink.add(jsonEncode(
              {'type': 'ack', 'ok': true, 'score': result['score']}));
        default:
          ch.sink.add(jsonEncode({'type': 'error', 'msg': 'unhandled type'}));
      }
    } catch (e) {
      ch.sink.add(jsonEncode({'type': 'error', 'msg': e.toString()}));
    }
  }

  void _broadcastScore(Map<String, dynamic> result) {
    _scoreStream.add(result);
    final encoded = jsonEncode({'type': 'score', 'payload': result});
    for (final c in _authedClients) {
      try {
        c.sink.add(encoded);
      } catch (_) {/* dropped client */}
    }
  }

  Future<String?> _detectIp() async {
    try {
      final ip = await NetworkInfo().getWifiIP();
      if (ip != null && ip.isNotEmpty) return ip;
    } catch (_) {}
    for (final iface in await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false)) {
      for (final addr in iface.addresses) {
        return addr.address;
      }
    }
    return null;
  }
}
