import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omr_shared/omr_shared.dart';

import '../../app.dart';

class ExamEditorScreen extends ConsumerStatefulWidget {
  const ExamEditorScreen({
    super.key,
    this.existing,
    this.initialKey = const [],
  });

  final Exam? existing;
  final List<AnswerKeyEntry> initialKey;

  @override
  ConsumerState<ExamEditorScreen> createState() => _ExamEditorScreenState();
}

class _ExamEditorScreenState extends ConsumerState<ExamEditorScreen> {
  final _title = TextEditingController();
  final _subject = TextEditingController();
  String _examType = 'quiz';
  int? _sectionId;
  int _itemCount = 10;
  int _choiceCount = 4;
  BubbleStyle _bubbleStyle = BubbleStyle.circle;

  late List<int> _key; // 0-indexed; length == _itemCount
  late Future<List<Map<String, dynamic>>> _sections;

  @override
  void initState() {
    super.initState();
    _sections = ref.read(appDatabaseProvider).listSections();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _subject.text = e.subject;
      _examType = e.examType;
      _sectionId = e.sectionId;
      _itemCount = e.itemCount;
      _choiceCount = e.choiceCount;
      _bubbleStyle = e.bubbleStyle;
    }
    _key = List<int>.filled(_itemCount, 0);
    for (final k in widget.initialKey) {
      if (k.itemNo >= 1 && k.itemNo <= _key.length) {
        _key[k.itemNo - 1] = k.correct;
      }
    }
  }

  void _resizeKey(int newCount) {
    final next = List<int>.filled(newCount, 0);
    for (var i = 0; i < newCount && i < _key.length; i++) {
      next[i] = _key[i] >= _choiceCount ? 0 : _key[i];
    }
    _key = next;
    _itemCount = newCount;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _sectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title and section are required.')));
      return;
    }
    final exam = Exam(
      id: widget.existing?.id,
      title: _title.text.trim(),
      subject: _subject.text.trim(),
      examType: _examType,
      sectionId: _sectionId!,
      itemCount: _itemCount,
      choiceCount: _choiceCount,
      bubbleStyle: _bubbleStyle,
      totalPoints: _itemCount,
    );
    final keyEntries = [
      for (var i = 0; i < _itemCount; i++)
        AnswerKeyEntry(itemNo: i + 1, correct: _key[i]),
    ];
    final db = ref.read(appDatabaseProvider);
    if (widget.existing == null) {
      await db.createExam(exam, keyEntries);
    } else {
      await db.updateExam(widget.existing!.id!, exam, keyEntries);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.existing == null ? 'New exam' : 'Edit exam'),
        actions: [
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(
                controller: _title,
                decoration:
                    const InputDecoration(labelText: 'Title (e.g. Math Quiz 3)')),
            const SizedBox(height: 8),
            TextField(
                controller: _subject,
                decoration: const InputDecoration(labelText: 'Subject')),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _sections,
              builder: (_, snap) {
                final secs = snap.data ?? const [];
                _sectionId ??=
                    secs.isNotEmpty ? secs.first['id'] as int : null;
                return DropdownButtonFormField<int>(
                  initialValue: _sectionId,
                  items: [
                    for (final s in secs)
                      DropdownMenuItem(
                          value: s['id'] as int,
                          child: Text(s['name'] as String)),
                  ],
                  onChanged: (v) => setState(() => _sectionId = v),
                  decoration: const InputDecoration(labelText: 'Section'),
                );
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _examType,
              items: const [
                DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
                DropdownMenuItem(value: 'unit_test', child: Text('Unit test')),
                DropdownMenuItem(
                    value: 'periodical', child: Text('Periodical')),
              ],
              onChanged: (v) => setState(() => _examType = v ?? 'quiz'),
              decoration: const InputDecoration(labelText: 'Exam type'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _itemCount,
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10 items')),
                      DropdownMenuItem(value: 20, child: Text('20 items')),
                      DropdownMenuItem(value: 40, child: Text('40 items')),
                      DropdownMenuItem(value: 50, child: Text('50 items')),
                      DropdownMenuItem(value: 100, child: Text('100 items')),
                    ],
                    onChanged: (v) =>
                        setState(() => _resizeKey(v ?? _itemCount)),
                    decoration:
                        const InputDecoration(labelText: 'Number of items'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _choiceCount,
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('True / False')),
                      DropdownMenuItem(value: 4, child: Text('A – D')),
                      DropdownMenuItem(value: 5, child: Text('A – E')),
                    ],
                    onChanged: (v) =>
                        setState(() => _choiceCount = v ?? _choiceCount),
                    decoration:
                        const InputDecoration(labelText: 'Choices'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<BubbleStyle>(
                    initialValue: _bubbleStyle,
                    items: const [
                      DropdownMenuItem(
                          value: BubbleStyle.circle, child: Text('Circle')),
                      DropdownMenuItem(
                          value: BubbleStyle.box, child: Text('Box')),
                    ],
                    onChanged: (v) =>
                        setState(() => _bubbleStyle = v ?? _bubbleStyle),
                    decoration:
                        const InputDecoration(labelText: 'Bubble style'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Answer key',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: List.generate(_itemCount, (i) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text('${i + 1}.',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 4),
                    for (var c = 0; c < _choiceCount; c++) ...[
                      ChoiceChip(
                        label: Text(_choiceCount == 2
                            ? (c == 0 ? 'T' : 'F')
                            : letters[c]),
                        selected: _key[i] == c,
                        onSelected: (_) =>
                            setState(() => _key[i] = c),
                      ),
                      const SizedBox(width: 2),
                    ],
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
