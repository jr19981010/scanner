import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:omr_shared/omr_shared.dart';

import '../../net/api_client.dart';
import '../../net/sync_socket.dart';
import '../about/update_check.dart';
import '../scan/scan_hub_screen.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '4040');
  final _code = TextEditingController();
  String _status = 'Not connected';
  SyncSocket? _socket;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    final box = Hive.box('settings');
    _host.text = box.get('host', defaultValue: '192.168.43.1') as String;
    _port.text = box.get('port', defaultValue: '4040') as String;
    _code.text = box.get('code', defaultValue: '') as String;
  }

  @override
  void dispose() {
    _socket?.close();
    super.dispose();
  }

  String get _httpBase => 'http://${_host.text}:${_port.text}';
  String get _wsUrl => 'ws://${_host.text}:${_port.text}/sync';

  Future<void> _scanPairingQr() async {
    final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const _QrScanPage()));
    if (result == null) return;
    try {
      final p = PairingPayload.decode(result);
      _host.text = p.host;
      _port.text = p.port.toString();
      _code.text = p.code;
      setState(() => _status = 'Pairing QR decoded. Tap Connect.');
    } catch (e) {
      setState(() => _status = 'Bad pairing QR: $e');
    }
  }

  Future<void> _connect() async {
    setState(() => _status = 'Pinging…');
    try {
      final ok = await ApiClient(_httpBase, pairingCode: _code.text).health();
      if (!ok) throw 'health check failed';
      Hive.box('settings')
        ..put('host', _host.text)
        ..put('port', _port.text)
        ..put('code', _code.text);
      _socket = SyncSocket(
        url: _wsUrl,
        deviceId: 'phone-1',
        pairingCode: _code.text,
      );
      _socket!.statusStream.listen((authed) {
        if (!mounted) return;
        setState(() {
          _connected = authed;
          _status = authed
              ? 'Connected & paired — ready to scan.'
              : 'Disconnected — reconnecting…';
        });
      });
      await _socket!.connect();
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to laptop'),
        actions: [
          IconButton(
            tooltip: 'Check for updates',
            icon: const Icon(Icons.system_update_alt),
            onPressed: () => showUpdateCheckDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            FilledButton.icon(
              onPressed: _scanPairingQr,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan pairing QR from laptop'),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            const Text('…or enter manually:'),
            TextField(
              controller: _host,
              decoration: const InputDecoration(labelText: 'Laptop IP'),
            ),
            TextField(
              controller: _port,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Pairing code'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _connect,
              child: const Text('Connect'),
            ),
            const SizedBox(height: 12),
            Text(_status),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.assignment_turned_in),
              label: const Text('Start grading'),
              onPressed: !_connected
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ScanHubScreen(socket: _socket!),
                      )),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrScanPage extends StatelessWidget {
  const _QrScanPage();

  @override
  Widget build(BuildContext context) {
    final controller = MobileScannerController();
    return Scaffold(
      appBar: AppBar(title: const Text('Point at pairing QR')),
      body: MobileScanner(
        controller: controller,
        onDetect: (cap) {
          final raw = cap.barcodes.firstOrNull?.rawValue;
          if (raw == null) return;
          Navigator.of(context).pop(raw);
        },
      ),
    );
  }
}
