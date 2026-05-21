import 'dart:typed_data';

import 'package:excel/excel.dart';

class ClassRecordRow {
  final String studentNo;
  final String fullName;
  final Map<String, ExamCell> byExam; // examTitle -> cell

  const ClassRecordRow({
    required this.studentNo,
    required this.fullName,
    required this.byExam,
  });
}

class ExamCell {
  final int score;
  final int total;
  const ExamCell(this.score, this.total);
}

/// Returns bytes of an .xlsx file containing students × exams plus totals,
/// average %, and rank.
Uint8List exportClassRecordXlsx({
  required String sheetName,
  required List<String> examTitles,
  required List<ClassRecordRow> rows,
}) {
  final book = Excel.createExcel();
  final sheet = book[sheetName];
  if (book.getDefaultSheet() != null && book.getDefaultSheet() != sheetName) {
    book.delete(book.getDefaultSheet()!);
  }

  sheet.appendRow([
    TextCellValue('Student #'),
    TextCellValue('Name'),
    for (final t in examTitles) TextCellValue(t),
    TextCellValue('Total'),
    TextCellValue('Average %'),
    TextCellValue('Rank'),
  ]);

  // Pre-compute averages for ranking.
  final averages = <String, double>{};
  for (final r in rows) {
    var sumScore = 0, sumTotal = 0;
    for (final t in examTitles) {
      final c = r.byExam[t];
      if (c != null) {
        sumScore += c.score;
        sumTotal += c.total;
      }
    }
    averages[r.studentNo] =
        sumTotal == 0 ? 0.0 : 100 * sumScore / sumTotal;
  }
  final sortedNos = averages.keys.toList()
    ..sort((a, b) => averages[b]!.compareTo(averages[a]!));
  final rankByNo = <String, int>{
    for (var i = 0; i < sortedNos.length; i++) sortedNos[i]: i + 1,
  };

  for (final r in rows) {
    var sumScore = 0, sumTotal = 0;
    final cells = <CellValue?>[
      TextCellValue(r.studentNo),
      TextCellValue(r.fullName),
    ];
    for (final t in examTitles) {
      final c = r.byExam[t];
      if (c == null) {
        cells.add(TextCellValue('—'));
      } else {
        cells.add(TextCellValue('${c.score}/${c.total}'));
        sumScore += c.score;
        sumTotal += c.total;
      }
    }
    final avg = sumTotal == 0 ? 0.0 : 100 * sumScore / sumTotal;
    cells.add(IntCellValue(sumScore));
    cells.add(DoubleCellValue(double.parse(avg.toStringAsFixed(2))));
    cells.add(IntCellValue(rankByNo[r.studentNo] ?? 0));
    sheet.appendRow(cells);
  }

  final saved = book.save();
  return Uint8List.fromList(saved ?? const []);
}
