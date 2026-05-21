import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../app.dart';
import '../../pdf/answer_sheet.dart';

class SheetGeneratorScreen extends ConsumerStatefulWidget {
  const SheetGeneratorScreen({super.key});

  @override
  ConsumerState<SheetGeneratorScreen> createState() =>
      _SheetGeneratorScreenState();
}

class _SheetGeneratorScreenState extends ConsumerState<SheetGeneratorScreen> {
  int? _examId;
  late Future<List<Map<String, dynamic>>> _exams;

  @override
  void initState() {
    super.initState();
    _exams = ref.read(appDatabaseProvider).listExams();
  }

  Future<void> _previewFirst() async {
    if (_examId == null) return;
    final db = ref.read(appDatabaseProvider);
    final exam = await db.examById(_examId!);
    if (exam == null) return;
    final students = await db.listStudents(sectionId: exam.sectionId);
    final sections = await db.listSections();
    final section = sections.firstWhere((s) => s['id'] == exam.sectionId,
        orElse: () => {'name': ''});
    if (students.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No students in this section.')));
      }
      return;
    }
    final first = students.first;
    await Printing.layoutPdf(
      onLayout: (format) => buildAnswerSheetPdf(
        exam: exam,
        studentNo: first['student_no'] as String,
        fullName: first['full_name'] as String,
        sectionName: section['name'] as String,
        pageFormat: format,
      ),
    );
  }

  Future<void> _printAllAsOne() async {
    if (_examId == null) return;
    final db = ref.read(appDatabaseProvider);
    final exam = await db.examById(_examId!);
    if (exam == null) return;
    final students = await db.listStudents(sectionId: exam.sectionId);
    final sections = await db.listSections();
    final section = sections.firstWhere((s) => s['id'] == exam.sectionId,
        orElse: () => {'name': ''});
    if (students.isEmpty) return;

    await Printing.layoutPdf(
      onLayout: (format) => buildBatchAnswerSheetPdf(
        exam: exam,
        students: [
          for (final s in students)
            (
              studentNo: s['student_no'] as String,
              fullName: s['full_name'] as String,
            ),
        ],
        sectionName: section['name'] as String,
        pageFormat: format,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Generate answer sheets',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _exams,
            builder: (_, snap) {
              final exams = snap.data ?? const [];
              return DropdownButtonFormField<int>(
                initialValue: _examId,
                items: [
                  for (final e in exams)
                    DropdownMenuItem(
                      value: e['id'] as int,
                      child: Text(
                          '${e['title']} · ${e['section_name']} · ${e['item_count']} items'),
                    ),
                ],
                onChanged: (v) => setState(() => _examId = v),
                decoration: const InputDecoration(labelText: 'Exam'),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _examId == null ? null : _previewFirst,
                icon: const Icon(Icons.visibility),
                label: const Text('Preview first student'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _examId == null ? null : _printAllAsOne,
                icon: const Icon(Icons.print),
                label: const Text('Print/save for whole section'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Each sheet has corner fiducials, a unique QR per student, '
            'and the bubble grid sized to the exam. Use the Print dialog '
            'to print or "Save as PDF" to share for printing elsewhere.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
