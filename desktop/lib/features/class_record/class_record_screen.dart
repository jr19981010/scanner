import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../app.dart';
import '../../export/excel_exporter.dart';

class ClassRecordScreen extends ConsumerStatefulWidget {
  const ClassRecordScreen({super.key});

  @override
  ConsumerState<ClassRecordScreen> createState() => _ClassRecordScreenState();
}

class _ClassRecordScreenState extends ConsumerState<ClassRecordScreen> {
  int? _sectionId;
  late Future<List<Map<String, dynamic>>> _sections;
  Future<List<Map<String, dynamic>>>? _rowsFuture;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sections = ref.read(appDatabaseProvider).listSections().then((s) {
      if (s.isNotEmpty && _sectionId == null) {
        _sectionId = s.first['id'] as int;
        _refreshRows();
      }
      return s;
    });
    _sub = ref.read(localServerProvider).scores.listen((_) => _refreshRows());
  }

  void _refreshRows() {
    if (_sectionId == null) return;
    setState(() {
      _rowsFuture =
          ref.read(appDatabaseProvider).classRecord(_sectionId!);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  ({List<String> examTitles, List<ClassRecordRow> rows}) _pivot(
      List<Map<String, dynamic>> raw) {
    final examTitles = <String>{};
    final byStudent = <String, ClassRecordRow>{};
    for (final r in raw) {
      final no = r['student_no'] as String;
      byStudent.putIfAbsent(
          no,
          () => ClassRecordRow(
                studentNo: no,
                fullName: r['full_name'] as String,
                byExam: <String, ExamCell>{},
              ));
      final title = r['exam_title'] as String?;
      if (title != null && r['score'] != null && r['total'] != null) {
        examTitles.add(title);
        byStudent[no]!.byExam[title] =
            ExamCell(r['score'] as int, r['total'] as int);
      }
    }
    final titles = examTitles.toList()..sort();
    final rows = byStudent.values.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    return (examTitles: titles, rows: rows);
  }

  Future<void> _exportExcel(
      List<String> titles, List<ClassRecordRow> rows) async {
    final bytes = exportClassRecordXlsx(
      sheetName: 'Class Record',
      examTitles: titles,
      rows: rows,
    );
    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final out = File(p.join(dir.path, 'class_record_$stamp.xlsx'));
    await out.writeAsBytes(bytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${out.path}')));
    }
  }

  Future<void> _exportPdf(
      List<String> titles, List<ClassRecordRow> rows) async {
    final averages = <String, double>{};
    for (final r in rows) {
      var s = 0, t = 0;
      for (final c in r.byExam.values) {
        s += c.score;
        t += c.total;
      }
      averages[r.studentNo] = t == 0 ? 0 : 100 * s / t;
    }
    final sorted = averages.keys.toList()
      ..sort((a, b) => averages[b]!.compareTo(averages[a]!));
    final rank = {for (var i = 0; i < sorted.length; i++) sorted[i]: i + 1};

    await Printing.layoutPdf(onLayout: (format) async {
      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        pageFormat: format.landscape,
        build: (ctx) => [
          pw.Header(level: 0, child: pw.Text('Class Record')),
          pw.TableHelper.fromTextArray(
            headers: [
              '#',
              'Name',
              ...titles,
              'Total',
              'Avg %',
              'Rank',
            ],
            data: [
              for (final r in rows)
                () {
                  var s = 0, t = 0;
                  final cells = [r.studentNo, r.fullName];
                  for (final title in titles) {
                    final c = r.byExam[title];
                    if (c == null) {
                      cells.add('—');
                    } else {
                      cells.add('${c.score}/${c.total}');
                      s += c.score;
                      t += c.total;
                    }
                  }
                  final avg = t == 0 ? 0 : (100 * s / t);
                  cells.add(s.toString());
                  cells.add(avg.toStringAsFixed(2));
                  cells.add('${rank[r.studentNo] ?? '-'}');
                  return cells;
                }(),
            ],
          ),
        ],
      ));
      return doc.save();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Class record',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: 24),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _sections,
                  builder: (_, snap) {
                    final secs = snap.data ?? const [];
                    return DropdownButtonFormField<int>(
                      initialValue: _sectionId,
                      items: [
                        for (final s in secs)
                          DropdownMenuItem(
                              value: s['id'] as int,
                              child: Text(s['name'] as String)),
                      ],
                      onChanged: (v) {
                        _sectionId = v;
                        _refreshRows();
                      },
                      decoration: const InputDecoration(isDense: true),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _rowsFuture == null
                ? const Center(child: Text('Pick a section.'))
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: _rowsFuture,
                    builder: (_, snap) {
                      if (!snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final pivot = _pivot(snap.data!);
                      final titles = pivot.examTitles;
                      final rows = pivot.rows;

                      // Average + rank for table display.
                      final averages = <String, double>{};
                      for (final r in rows) {
                        var s = 0, t = 0;
                        for (final c in r.byExam.values) {
                          s += c.score;
                          t += c.total;
                        }
                        averages[r.studentNo] = t == 0 ? 0 : 100 * s / t;
                      }
                      final sorted = averages.keys.toList()
                        ..sort((a, b) =>
                            averages[b]!.compareTo(averages[a]!));
                      final rank = {
                        for (var i = 0; i < sorted.length; i++)
                          sorted[i]: i + 1
                      };

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: rows.isEmpty
                                    ? null
                                    : () => _exportExcel(titles, rows),
                                icon: const Icon(Icons.table_chart),
                                label: const Text('Export Excel'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: rows.isEmpty
                                    ? null
                                    : () => _exportPdf(titles, rows),
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('Export PDF'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columns: [
                                    const DataColumn(label: Text('Student #')),
                                    const DataColumn(label: Text('Name')),
                                    for (final t in titles)
                                      DataColumn(label: Text(t)),
                                    const DataColumn(label: Text('Avg %')),
                                    const DataColumn(label: Text('Rank')),
                                  ],
                                  rows: [
                                    for (final r in rows)
                                      DataRow(cells: [
                                        DataCell(Text(r.studentNo)),
                                        DataCell(Text(r.fullName)),
                                        for (final t in titles)
                                          DataCell(Text(r.byExam[t] == null
                                              ? '—'
                                              : '${r.byExam[t]!.score}/${r.byExam[t]!.total}')),
                                        DataCell(Text(averages[r.studentNo]!
                                            .toStringAsFixed(2))),
                                        DataCell(Text(
                                            (rank[r.studentNo] ?? '-')
                                                .toString())),
                                      ]),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
