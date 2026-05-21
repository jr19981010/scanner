import 'dart:async';
import 'dart:convert';

import 'package:omr_shared/omr_shared.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Thin wrapper over the desktop's `/sync` WebSocket.
///
/// - Sends `hello` with the pairing code on every (re)connect.
/// - Auto-reconnects with exponential backoff (capped 30s).
/// - Queues outbound `scan` messages while disconnected; replays on reconnect.
/// - Exposes a stream of events and a connection-status stream.
class SyncSocket {
  SyncSocket({
    required this.url,
    required this.deviceId,
    required this.pairingCode,
  });

  final String url; // ws://192.168.x.x:4040/sync
  final String deviceId;
  final String pairingCode;

  WebSocketChannel? _ch;
  bool _closed = false;
  bool _authed = false;
  Duration _backoff = const Duration(seconds: 1);
  final List<ScanSubmission> _queue = [];

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  final _status = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _status.stream;

  Future<void> connect() async {
    if (_closed) return;
    try {
      _ch = WebSocketChannel.connect(Uri.parse(url));
      await _ch!.ready;
      _backoff = const Duration(seconds: 1);
      _ch!.sink.add(WsMessage.hello(
        device: deviceId,
        pairingCode: pairingCode,
      ).encode());
      _ch!.stream.listen(_onMessage, onDone: _onDone, onError: (_) => _onDone());
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final j = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = j['type'];
      if (type == 'ack' && !_authed) {
        _authed = true;
        _status.add(true);
        _drain();
      }
      if (type == 'error') {
        _authed = false;
        _status.add(false);
      }
      _events.add(j);
    } catch (_) {/* ignore malformed */}
  }

  void _onDone() {
    _ch = null;
    _authed = false;
    _status.add(false);
    if (!_closed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    Future.delayed(_backoff, connect);
    _backoff = Duration(seconds: (_backoff.inSeconds * 2).clamp(1, 30));
  }

  bool get isAuthed => _authed;

  /// Submit a scan. If the socket is open + authed, sends immediately;
  /// otherwise enqueues and flushes on the next successful `ack`.
  void submit(ScanSubmission s) {
    _queue.add(s);
    if (_authed) _drain();
  }

  void _drain() {
    while (_queue.isNotEmpty && _authed && _ch != null) {
      final s = _queue.removeAt(0);
      try {
        _ch!.sink.add(WsMessage.scan(s).encode());
      } catch (_) {
        _queue.insert(0, s);
        break;
      }
    }
  }

  int get pendingCount => _queue.length;

  Future<void> close() async {
    _closed = true;
    await _ch?.sink.close(ws_status.normalClosure);
    await _events.close();
    await _status.close();
  }
}
