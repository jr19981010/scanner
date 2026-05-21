import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:omr_shared/omr_shared.dart';

import '../../net/sync_socket.dart';

/// Shows the detected/typed answers vs the answer key with per-item ✓/✗,
/// the projected score, and a confirm button to submit.
class ResultPreviewScreen extends StatefulWidget {
  const ResultPreviewScreen({
    super.key,
    required this.exam,
    required this.answerKey,
    required this.studentNo,
    required this.answers,
    required this.socket,
  });

  final Exam exam;
  final List<AnswerKeyEntry> answerKey;
  final String studentNo;
  final List<int> answers;
  final SyncSocket socket;

  @override
  State<ResultPreviewScreen> createState() => _ResultPreviewScreenState();
}

class _ResultPreviewScreenState extends State<ResultPreviewScreen> {
  late List<int> _answers;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _answers = List<int>.from(widget.answers);
  }

  int get _score {
    final byItem = {for (final k in widget.answerKey) k.itemNo: k};
    var s = 0;
    for (var i = 0; i < _answers.length; i++) {
      final k = byItem[i + 1];
      if (k != null && _answers[i] == k.correct) s += k.points;
    }
    return s;
  }

  int get _total => widget.answerKey.fold(0, (a, k) => a + k.points);

  Future<void> _submit() async {
    final submission = ScanSubmission(
      examId: widget.exam.id!,
      studentNo: widget.studentNo,
      answers: _answers,
      deviceId: 'phone-1',
    );
    widget.socket.submit(submission);

    final box = Hive.box('settings');
    final history = (box.get('history') as List?) ?? <dynamic>[];
    history.insert(0, {
      'student_no': widget.studentNo,
      'exam_id': widget.exam.id,
      'exam_title': widget.exam.title,
      'score': _score,
      'total': _total,
      'queued': !widget.socket.isAuthed,
      'at': DateTime.now().toIso8601String(),
      'answers': jsonEncode(_answers),
    });
    while (history.length > 200) {
      history.removeLast();
    }
    await box.put('history', history);

    if (!mounted) return;
    setState(() => _submitted = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(widget.socket.isAuthed
          ? 'Submitted: $_score / $_total'
          : 'Queued (offline): $_score / $_total'),
    ));
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/hub');
  }

  @override
  Widget build(BuildContext context) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final byItem = {for (final k in widget.answerKey) k.itemNo: k};
    final score = _score;
    final total = _total;

    return Scaffold(
      appBar: AppBar(title: Text('Preview · ${widget.studentNo}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(widget.exam.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('$score / $total',
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: widget.exam.itemCount,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final correct = byItem[i + 1]?.correct;
                final got = _answers[i];
                final ok = got == correct;
                final letter = (int? c) => c == null || c < 0
                    ? '—'
                    : widget.exam.choiceCount == 2
                        ? (c == 0 ? 'T' : 'F')
                        : letters[c];
                return ListTile(
                  dense: true,
                  leading: Text('${i + 1}.',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  title: Row(
                    children: [
                      Text('You: ${letter(got)}'),
                      const SizedBox(width: 24),
                      Text('Key: ${letter(correct)}',
                          style:
                              const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  trailing: got < 0
                      ? const Icon(Icons.help_outline, color: Colors.orange)
                      : Icon(
                          ok ? Icons.check : Icons.close,
                          color: ok ? Colors.green : Colors.red,
                        ),
                  onTap: () async {
                    final newVal = await _pickChoice(i, got);
                    if (newVal != null) {
                      setState(() => _answers[i] = newVal);
                    }
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (!widget.socket.isAuthed)
                    const Row(children: [
                      Icon(Icons.cloud_off, color: Colors.orange),
                      SizedBox(width: 6),
                      Text('Offline — will queue'),
                    ]),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _submitted ? null : _submit,
                    icon: const Icon(Icons.send),
                    label: Text(_submitted ? 'Submitted' : 'Submit'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<int?> _pickChoice(int itemIdx, int current) async {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    return showModalBottomSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Item ${itemIdx + 1} — pick answer'),
              trailing: TextButton(
                onPressed: () => Navigator.pop(context, -1),
                child: const Text('Clear'),
              ),
            ),
            const Divider(height: 1),
            Wrap(
              spacing: 8,
              children: List.generate(widget.exam.choiceCount, (c) {
                final label = widget.exam.choiceCount == 2
                    ? (c == 0 ? 'T' : 'F')
                    : letters[c];
                return ChoiceChip(
                  label: Text(label),
                  selected: current == c,
                  onSelected: (_) => Navigator.pop(context, c),
                );
              }),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
