import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omr_shared/omr_shared.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app.dart';
import '../about/update_check.dart';

class LiveFeedScreen extends ConsumerStatefulWidget {
  const LiveFeedScreen({super.key});

  @override
  ConsumerState<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends ConsumerState<LiveFeedScreen> {
  final List<Map<String, dynamic>> _scores = [];
  StreamSubscription? _scoreSub;
  StreamSubscription? _connSub;
  int _connections = 0;

  @override
  void initState() {
    super.initState();
    final server = ref.read(localServerProvider);
    _scoreSub = server.scores.listen((result) {
      if (!mounted) return;
      setState(() => _scores.insert(0, result));
    });
    _connSub = server.connectionCountStream.listen((n) {
      if (!mounted) return;
      setState(() => _connections = n);
    });
    _connections = server.connectionCount;
  }

  @override
  void dispose() {
    _scoreSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(localServerProvider);
    final db = ref.watch(appDatabaseProvider);
    final host = server.boundIp ?? '0.0.0.0';
    final pairing =
        PairingPayload(host: host, port: server.port, code: db.pairingCode)
            .encode();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Pair your phone',
                  style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => showUpdateCheckDialog(context),
                icon: const Icon(Icons.system_update_alt),
                label: const Text('Check for updates'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: QrImageView(data: pairing, size: 200),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        '1. Turn on the phone hotspot.\n'
                        '2. Connect this laptop to that hotspot.\n'
                        '3. Open the OMR Scanner app and tap "Scan pairing QR".'),
                    const SizedBox(height: 16),
                    _kv('Laptop IP', host),
                    _kv('Port', '${server.port}'),
                    _kv('Pairing code', db.pairingCode,
                        emphasis: true),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(
                        _connections > 0
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _connections > 0
                            ? Colors.green
                            : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text('$_connections phone(s) connected'),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 48),
          Text('Live scans',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Expanded(
            child: _scores.isEmpty
                ? const Center(child: Text('Waiting for the first scan…'))
                : ListView.separated(
                    itemCount: _scores.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = _scores[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${s['score']}')),
                        title: Text(
                            '${s['full_name']} (${s['student_no']})'),
                        subtitle: Text(
                            'Exam ${s['exam_id']} · ${s['score']}/${s['total']} '
                            '· ${s['percentage']}% · ${s['device_id']}'),
                        trailing: Text(
                          (s['scanned_at'] as String).substring(11, 19),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool emphasis = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        SizedBox(width: 110, child: Text(k)),
        SelectableText(v,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: emphasis ? 22 : 16,
              fontWeight: emphasis ? FontWeight.bold : FontWeight.normal,
            )),
      ]),
    );
  }
}
