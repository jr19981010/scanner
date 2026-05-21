import 'package:flutter/material.dart';
import 'package:omr_shared/omr_shared.dart';

import '../../net/sync_socket.dart';
import 'result_preview_screen.dart';

/// Teacher taps each answer by hand. Fast and useful while OMR is being tuned.
class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({
    super.key,
    required this.exam,
    required this.answerKey,
    required this.studentNo,
    required this.socket,
  });

  final Exam exam;
  final List<AnswerKeyEntry> answerKey;
  final String studentNo;
  final SyncSocket socket;

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  late List<int> _answers; // -1 = unanswered

  @override
  void initState() {
    super.initState();
    _answers = List<int>.filled(widget.exam.itemCount, -1);
  }

  void _review() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultPreviewScreen(
        exam: widget.exam,
        answerKey: widget.answerKey,
        studentNo: widget.studentNo,
        answers: _answers,
        socket: widget.socket,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final exam = widget.exam;
    final answered = _answers.where((a) => a >= 0).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Manual entry · ${widget.studentNo}'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: exam.itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) {
          return Row(
            children: [
              SizedBox(
                  width: 36,
                  child: Text('${i + 1}.',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16))),
              const SizedBox(width: 8),
              for (var c = 0; c < exam.choiceCount; c++) ...[
                ChoiceChip(
                  label: Text(exam.choiceCount == 2
                      ? (c == 0 ? 'T' : 'F')
                      : letters[c]),
                  selected: _answers[i] == c,
                  onSelected: (_) => setState(() {
                    _answers[i] = _answers[i] == c ? -1 : c;
                  }),
                ),
                const SizedBox(width: 4),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('$answered / ${exam.itemCount} answered'),
              const Spacer(),
              FilledButton.icon(
                onPressed: _review,
                icon: const Icon(Icons.preview),
                label: const Text('Review & submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
