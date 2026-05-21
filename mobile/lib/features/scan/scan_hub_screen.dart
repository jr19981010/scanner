import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:omr_shared/omr_shared.dart';

import '../../net/api_client.dart';
import '../../net/sync_socket.dart';
import '../../storage/local_cache.dart';
import '../history/history_screen.dart';
import '../result/manual_entry_screen.dart';
import 'scan_screen.dart';

/// After connecting, the teacher lands here:
///  - Pick which exam they're grading.
///  - Tap "Scan QR + OMR" to use the camera pipeline.
///  - Tap "Scan QR + manual" to scan the student QR and tap bubbles by hand.
class ScanHubScreen extends ConsumerStatefulWidget {
  const ScanHubScreen({super.key, required this.socket});
  final SyncSocket socket;

  @override
  ConsumerState<ScanHubScreen> createState() => _ScanHubScreenState();
}

class _ScanHubScreenState extends ConsumerState<ScanHubScreen> {
  int? _selectedExamId;
  Future<List<Map<String, dynamic>>>? _examsFuture;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _connected = widget.socket.isAuthed;
    widget.socket.statusStream.listen((v) {
      if (mounted) setState(() => _connected = v);
    });
    _examsFuture = _fetchExams();
  }

  Future<List<Map<String, dynamic>>> _fetchExams() async {
    final box = Hive.box('settings');
    final host = box.get('host') as String;
    final port = box.get('port') as String;
    final code = box.get('code') as String;
    final api = ApiClient('http://$host:$port', pairingCode: code);
    final exams = await api.listExams();
    // Cache them so we can show something even if the network drops.
    await Hive.box('exam_cache').put('list', exams);
    return exams;
  }

  Future<void> _pickStudentAndGrade({required bool manual}) async {
    if (_selectedExamId == null) return;
    // 1. Pull exam + key (online; fallback to Hive cache).
    final box = Hive.box('settings');
    final api = ApiClient(
      'http://${box.get('host')}:${box.get('port')}',
      pairingCode: box.get('code') as String,
    );
    final cache = LocalCache(Hive.box('exam_cache'));
    Exam exam;
    List<AnswerKeyEntry> key;
    try {
      final fetched = await api.fetchExam(_selectedExamId!);
      exam = fetched.exam;
      key = fetched.key;
      await cache.cacheExam(exam, key);
    } catch (_) {
      final cachedExam = cache.exam(_selectedExamId!);
      final cachedKey = cache.answerKey(_selectedExamId!);
      if (cachedExam == null || cachedKey == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Offline and no cache for this exam yet. Reconnect once.')));
        }
        return;
      }
      exam = cachedExam;
      key = cachedKey;
    }

    if (!mounted) return;
    final qrRaw = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const _StudentQrScanPage()));
    if (qrRaw == null) return;

    QrPayload qr;
    try {
      qr = QrPayload.decode(qrRaw);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bad student QR: $e')));
      }
      return;
    }
    if (qr.examId != exam.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'QR is for exam ${qr.examId}, but you selected ${exam.id}.')));
      }
      return;
    }

    if (!mounted) return;
    if (manual) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ManualEntryScreen(
          exam: exam,
          answerKey: key,
          studentNo: qr.studentNo,
          socket: widget.socket,
        ),
      ));
    } else {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ScanScreen(
          socket: widget.socket,
          exam: exam,
          answerKey: key,
          studentNo: qr.studentNo,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grade exam'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const HistoryScreen())),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(
                _connected
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                color: _connected ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(_connected
                  ? 'Connected to laptop'
                  : 'Offline — scans will queue locally'),
              const Spacer(),
              if (widget.socket.pendingCount > 0)
                Text('${widget.socket.pendingCount} pending'),
            ]),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _examsFuture,
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final exams = snap.data!;
                if (exams.isEmpty) {
                  return const Text('No exams found on the laptop.');
                }
                return DropdownButtonFormField<int>(
                  initialValue: _selectedExamId,
                  items: [
                    for (final e in exams)
                      DropdownMenuItem(
                        value: e['id'] as int,
                        child: Text(
                            '${e['title']} · ${e['item_count']} items'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _selectedExamId = v),
                  decoration: const InputDecoration(labelText: 'Exam'),
                );
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _selectedExamId == null
                  ? null
                  : () => _pickStudentAndGrade(manual: false),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan QR + camera OMR'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _selectedExamId == null
                  ? null
                  : () => _pickStudentAndGrade(manual: true),
              icon: const Icon(Icons.edit),
              label: const Text('Scan QR + manual entry'),
            ),
            const SizedBox(height: 24),
            const Text(
                'Camera OMR is the goal — until it\'s tuned for your sheets, '
                'use manual entry: scan the student QR then tap each answer.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _StudentQrScanPage extends StatelessWidget {
  const _StudentQrScanPage();

  @override
  Widget build(BuildContext context) {
    final ctl = MobileScannerController();
    return Scaffold(
      appBar: AppBar(title: const Text('Scan student QR')),
      body: MobileScanner(
        controller: ctl,
        onDetect: (cap) {
          final raw = cap.barcodes.firstOrNull?.rawValue;
          if (raw == null) return;
          Navigator.of(context).pop(raw);
        },
      ),
    );
  }
}
