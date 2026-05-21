import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  int? _filterSectionId;
  late Future<List<Map<String, dynamic>>> _students;
  late Future<List<Map<String, dynamic>>> _sections;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final db = ref.read(appDatabaseProvider);
    setState(() {
      _sections = db.listSections();
      _students = db.listStudents(sectionId: _filterSectionId);
    });
  }

  Future<void> _editStudent({Map<String, dynamic>? row}) async {
    final sections = await ref.read(appDatabaseProvider).listSections();
    if (!mounted) return;
    if (sections.isEmpty) {
      _toast('Create a section first.');
      return;
    }
    final no = TextEditingController(text: row?['student_no'] as String? ?? '');
    final name = TextEditingController(text: row?['full_name'] as String? ?? '');
    var sectionId =
        (row?['section_id'] as int?) ?? sections.first['id'] as int;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: Text(row == null ? 'New student' : 'Edit student'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: no,
                  decoration: const InputDecoration(labelText: 'Student #')),
              TextField(
                  controller: name,
                  decoration:
                      const InputDecoration(labelText: 'Full name (Last, First)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: sectionId,
                items: [
                  for (final s in sections)
                    DropdownMenuItem(
                        value: s['id'] as int, child: Text(s['name'] as String)),
                ],
                onChanged: (v) => setS(() => sectionId = v ?? sectionId),
                decoration: const InputDecoration(labelText: 'Section'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        );
      }),
    );
    if (ok != true) return;
    final db = ref.read(appDatabaseProvider);
    try {
      if (row == null) {
        await db.createStudent(
            studentNo: no.text.trim(),
            fullName: name.text.trim(),
            sectionId: sectionId);
      } else {
        await db.updateStudent(row['id'] as int,
            studentNo: no.text.trim(),
            fullName: name.text.trim(),
            sectionId: sectionId);
      }
    } catch (e) {
      _toast('Save failed: $e');
    }
    _reload();
  }

  Future<void> _csvImport() async {
    final sections = await ref.read(appDatabaseProvider).listSections();
    if (!mounted) return;
    if (sections.isEmpty) {
      _toast('Create a section first.');
      return;
    }
    final csv = TextEditingController();
    var sectionId = sections.first['id'] as int;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Bulk import students'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: sectionId,
                  items: [
                    for (final s in sections)
                      DropdownMenuItem(
                          value: s['id'] as int,
                          child: Text(s['name'] as String)),
                  ],
                  onChanged: (v) => setS(() => sectionId = v ?? sectionId),
                  decoration: const InputDecoration(labelText: 'Section'),
                ),
                const SizedBox(height: 12),
                const Text(
                    'Paste CSV — one row per student: STUDENT_NO,FULL_NAME'),
                const SizedBox(height: 8),
                TextField(
                  controller: csv,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText:
                        '2026-00010,Dela Cruz, Juan\n2026-00011,Reyes, Maria',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Import')),
          ],
        );
      }),
    );
    if (ok != true) return;
    final n = await ref
        .read(appDatabaseProvider)
        .importStudentsCsv(sectionId, csv.text);
    _toast('Imported $n students.');
    _reload();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _delete(int id) async {
    await ref.read(appDatabaseProvider).deleteStudent(id);
    _reload();
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
              Text('Students',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: 24),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _sections,
                  builder: (_, snap) {
                    final secs = snap.data ?? const [];
                    return DropdownButtonFormField<int?>(
                      initialValue: _filterSectionId,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All sections')),
                        for (final s in secs)
                          DropdownMenuItem(
                              value: s['id'] as int,
                              child: Text(s['name'] as String)),
                      ],
                      onChanged: (v) {
                        _filterSectionId = v;
                        _reload();
                      },
                      decoration: const InputDecoration(isDense: true),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _csvImport,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import CSV'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _editStudent(),
                icon: const Icon(Icons.add),
                label: const Text('New student'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _students,
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data!;
                if (rows.isEmpty) {
                  return const Center(child: Text('No students.'));
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    return ListTile(
                      title: Text(r['full_name'] as String),
                      subtitle: Text(
                          '#${r['student_no']} · ${r['section_name'] ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editStudent(row: r)),
                          IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(r['id'] as int)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
