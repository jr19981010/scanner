import 'dart:convert';
import 'dart:math';

import 'package:omr_shared/omr_shared.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._(this._db);
  final Database _db;
  Database get raw => _db;

  /// Persisted across launches; mobile clients must echo this on `hello`.
  late String pairingCode;

  static Future<AppDatabase> open({String? overridePath}) async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = overridePath ?? p.join(dir.path, 'omr.db');
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
      ),
    );
    final app = AppDatabase._(db);
    await app._loadOrCreatePairingCode();
    await app._seedIfEmpty();
    return app;
  }

  static Future<void> _onCreate(Database d, int _) async {
    await d.execute('''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');
    await d.execute('''
      CREATE TABLE sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        school_year TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )''');
    await d.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_no TEXT NOT NULL UNIQUE,
        full_name TEXT NOT NULL,
        section_id INTEGER NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )''');
    await d.execute(
        'CREATE INDEX idx_students_section ON students(section_id)');
    await d.execute('''
      CREATE TABLE exams (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        subject TEXT NOT NULL,
        exam_type TEXT NOT NULL,
        section_id INTEGER NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
        item_count INTEGER NOT NULL,
        choice_count INTEGER NOT NULL,
        bubble_style TEXT NOT NULL,
        total_points INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )''');
    await d.execute('''
      CREATE TABLE answer_keys (
        exam_id INTEGER NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
        item_no INTEGER NOT NULL,
        correct INTEGER NOT NULL,
        points INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (exam_id, item_no)
      )''');
    await d.execute('''
      CREATE TABLE scans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exam_id INTEGER NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
        student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
        device_id TEXT,
        raw_answers TEXT NOT NULL,
        score INTEGER NOT NULL,
        total INTEGER NOT NULL,
        scanned_at TEXT NOT NULL DEFAULT (datetime('now')),
        UNIQUE (exam_id, student_id)
      )''');
    await d.execute('CREATE INDEX idx_scans_exam ON scans(exam_id)');
  }

  Future<void> _loadOrCreatePairingCode() async {
    final rows = await _db
        .query('meta', where: 'key = ?', whereArgs: ['pairing_code']);
    if (rows.isNotEmpty) {
      pairingCode = rows.first['value'] as String;
      return;
    }
    final rng = Random.secure();
    pairingCode = List.generate(6, (_) => rng.nextInt(10)).join();
    await _db.insert(
        'meta', {'key': 'pairing_code', 'value': pairingCode});
  }

  Future<void> _seedIfEmpty() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) c FROM sections');
    if ((rows.first['c'] as int) > 0) return;

    await _db.transaction((txn) async {
      final sectionId = await txn.insert('sections',
          {'name': 'Grade 7 - Sampaguita', 'school_year': '2026-2027'});

      final demoStudents = [
        ('2026-00001', 'Dela Cruz, Juan'),
        ('2026-00002', 'Reyes, Maria'),
        ('2026-00003', 'Santos, Pedro'),
      ];
      for (final (no, name) in demoStudents) {
        await txn.insert('students', {
          'student_no': no,
          'full_name': name,
          'section_id': sectionId,
        });
      }

      final examId = await txn.insert('exams', {
        'title': 'Demo Quiz',
        'subject': 'Math',
        'exam_type': 'quiz',
        'section_id': sectionId,
        'item_count': 10,
        'choice_count': 4,
        'bubble_style': 'circle',
        'total_points': 10,
      });
      for (var i = 1; i <= 10; i++) {
        await txn.insert('answer_keys', {
          'exam_id': examId,
          'item_no': i,
          'correct': i % 4,
          'points': 1,
        });
      }
    });
  }

  // ---- Sections -------------------------------------------------------------

  Future<List<Map<String, dynamic>>> listSections() =>
      _db.query('sections', orderBy: 'name ASC');

  Future<int> createSection(String name, {String? schoolYear}) =>
      _db.insert('sections', {'name': name, 'school_year': schoolYear});

  Future<void> updateSection(int id, String name, {String? schoolYear}) =>
      _db.update('sections',
          {'name': name, 'school_year': schoolYear},
          where: 'id = ?', whereArgs: [id]);

  Future<void> deleteSection(int id) =>
      _db.delete('sections', where: 'id = ?', whereArgs: [id]);

  // ---- Students -------------------------------------------------------------

  Future<List<Map<String, dynamic>>> listStudents({int? sectionId}) {
    if (sectionId == null) {
      return _db.rawQuery('''
        SELECT s.*, sec.name section_name
        FROM students s JOIN sections sec ON sec.id = s.section_id
        ORDER BY sec.name, s.full_name
      ''');
    }
    return _db.query('students',
        where: 'section_id = ?',
        whereArgs: [sectionId],
        orderBy: 'full_name ASC');
  }

  Future<int> createStudent({
    required String studentNo,
    required String fullName,
    required int sectionId,
  }) =>
      _db.insert('students', {
        'student_no': studentNo,
        'full_name': fullName,
        'section_id': sectionId,
      });

  Future<void> updateStudent(int id,
          {required String studentNo,
          required String fullName,
          required int sectionId}) =>
      _db.update(
          'students',
          {
            'student_no': studentNo,
            'full_name': fullName,
            'section_id': sectionId,
          },
          where: 'id = ?',
          whereArgs: [id]);

  Future<void> deleteStudent(int id) =>
      _db.delete('students', where: 'id = ?', whereArgs: [id]);

  /// Bulk import. Returns count inserted. Format per row: studentNo, fullName.
  Future<int> importStudentsCsv(int sectionId, String csv) async {
    var n = 0;
    await _db.transaction((txn) async {
      for (final line in csv.split('\n')) {
        final cells = line.split(',').map((c) => c.trim()).toList();
        if (cells.length < 2) continue;
        if (cells[0].isEmpty || cells[0].toLowerCase().startsWith('student')) {
          continue;
        }
        await txn.insert(
            'students',
            {
              'student_no': cells[0],
              'full_name': cells[1],
              'section_id': sectionId,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
        n++;
      }
    });
    return n;
  }

  // ---- Exams ----------------------------------------------------------------

  Future<List<Map<String, dynamic>>> listExams() => _db.rawQuery('''
        SELECT e.*, sec.name section_name
        FROM exams e JOIN sections sec ON sec.id = e.section_id
        ORDER BY e.created_at DESC
      ''');

  Future<int> createExam(Exam exam, List<AnswerKeyEntry> key) async {
    return _db.transaction<int>((txn) async {
      final id = await txn.insert('exams', exam.toJson()..remove('id'));
      for (final k in key) {
        await txn.insert('answer_keys', {'exam_id': id, ...k.toJson()});
      }
      return id;
    });
  }

  Future<void> updateExam(int id, Exam exam, List<AnswerKeyEntry> key) async {
    await _db.transaction((txn) async {
      await txn.update('exams', exam.toJson()..remove('id'),
          where: 'id = ?', whereArgs: [id]);
      await txn.delete('answer_keys', where: 'exam_id = ?', whereArgs: [id]);
      for (final k in key) {
        await txn.insert('answer_keys', {'exam_id': id, ...k.toJson()});
      }
    });
  }

  Future<void> deleteExam(int id) =>
      _db.delete('exams', where: 'id = ?', whereArgs: [id]);

  Future<Exam?> examById(int id) async {
    final rows = await _db.query('exams', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Exam.fromJson(rows.first);
  }

  Future<List<AnswerKeyEntry>> answerKey(int examId) async {
    final rows = await _db.query('answer_keys',
        where: 'exam_id = ?', whereArgs: [examId], orderBy: 'item_no ASC');
    return rows.map(AnswerKeyEntry.fromJson).toList();
  }

  Future<Map<String, dynamic>?> studentByNo(String studentNo) async {
    final rows = await _db
        .query('students', where: 'student_no = ?', whereArgs: [studentNo]);
    return rows.isEmpty ? null : rows.first;
  }

  // ---- Scans ----------------------------------------------------------------

  Future<Map<String, dynamic>> recordScan(ScanSubmission s) async {
    final student = await studentByNo(s.studentNo);
    if (student == null) {
      throw StateError('Unknown student_no ${s.studentNo}');
    }
    final exam = await examById(s.examId);
    if (exam == null) {
      throw StateError('Unknown exam_id ${s.examId}');
    }
    final key = await answerKey(s.examId);

    var score = 0;
    final keyByItem = {for (final k in key) k.itemNo: k};
    for (var i = 0; i < s.answers.length; i++) {
      final entry = keyByItem[i + 1];
      if (entry == null) continue;
      if (s.answers[i] == entry.correct) score += entry.points;
    }
    final total = key.fold<int>(0, (a, k) => a + k.points);

    await _db.insert(
      'scans',
      {
        'exam_id': s.examId,
        'student_id': student['id'],
        'device_id': s.deviceId,
        'raw_answers': jsonEncode(s.answers),
        'score': score,
        'total': total,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return {
      'exam_id': s.examId,
      'student_no': s.studentNo,
      'full_name': student['full_name'],
      'score': score,
      'total': total,
      'percentage': total == 0
          ? 0.0
          : double.parse((100 * score / total).toStringAsFixed(2)),
      'scanned_at': DateTime.now().toIso8601String(),
      'device_id': s.deviceId,
    };
  }

  Future<List<Map<String, dynamic>>> classRecord(int sectionId) {
    return _db.rawQuery('''
      SELECT st.id student_id, st.student_no, st.full_name,
             e.id exam_id, e.title exam_title, e.total_points exam_total,
             s.score, s.total,
             ROUND(100.0 * s.score / s.total, 2) percentage
      FROM students st
      LEFT JOIN exams e ON e.section_id = st.section_id
      LEFT JOIN scans s ON s.student_id = st.id AND s.exam_id = e.id
      WHERE st.section_id = ?
      ORDER BY st.full_name, e.id
    ''', [sectionId]);
  }
}
