import 'dart:typed_data';

import 'package:omr_shared/omr_shared.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart' as bc;

typedef SheetStudent = ({String studentNo, String fullName});

/// Single-student preview.
Future<Uint8List> buildAnswerSheetPdf({
  required Exam exam,
  required String studentNo,
  required String fullName,
  required String sectionName,
  required PdfPageFormat pageFormat,
}) =>
    buildBatchAnswerSheetPdf(
      exam: exam,
      students: [(studentNo: studentNo, fullName: fullName)],
      sectionName: sectionName,
      pageFormat: pageFormat,
    );

/// Whole-section batch — one page per student in a single PDF.
Future<Uint8List> buildBatchAnswerSheetPdf({
  required Exam exam,
  required List<SheetStudent> students,
  required String sectionName,
  required PdfPageFormat pageFormat,
}) async {
  final doc = pw.Document();
  for (final s in students) {
    final qr = QrPayload(
      studentNo: s.studentNo,
      examId: exam.id ?? 0,
      itemCount: exam.itemCount,
      choiceCount: exam.choiceCount,
    ).encode();

    doc.addPage(pw.Page(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Stack(children: [
        _fiducial(top: 0, left: 0),
        _fiducial(top: 0, right: 0),
        _fiducial(bottom: 0, left: 0),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(exam.title,
                          style: pw.TextStyle(
                              fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text('${exam.subject} · ${exam.examType}'),
                      pw.SizedBox(height: 6),
                      pw.Text('Name: ${s.fullName}'),
                      pw.Text('Student #: ${s.studentNo}'),
                      pw.Text('Section: $sectionName'),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: bc.Barcode.qrCode(),
                    data: qr,
                    width: 90,
                    height: 90,
                  ),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Divider(),
              pw.SizedBox(height: 12),
              _bubbleGrid(exam),
            ],
          ),
        ),
      ]),
    ));
  }
  return doc.save();
}

pw.Widget _fiducial({double? top, double? left, double? right, double? bottom}) {
  return pw.Positioned(
    top: top,
    left: left,
    right: right,
    bottom: bottom,
    child: pw.Container(width: 22, height: 22, color: PdfColors.black),
  );
}

pw.Widget _bubbleGrid(Exam exam) {
  const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
  return pw.Wrap(
    spacing: 24,
    runSpacing: 8,
    children: List.generate(exam.itemCount, (i) {
      return pw.Container(
        width: 140,
        child: pw.Row(children: [
          pw.SizedBox(
              width: 22,
              child: pw.Text('${i + 1}.',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(width: 4),
          for (var c = 0; c < exam.choiceCount; c++) ...[
            _bubble(exam.bubbleStyle,
                exam.choiceCount == 2 ? (c == 0 ? 'T' : 'F') : letters[c]),
            pw.SizedBox(width: 4),
          ],
        ]),
      );
    }),
  );
}

pw.Widget _bubble(BubbleStyle style, String letter) {
  final border = pw.Border.all(color: PdfColors.black, width: 0.8);
  final inner = pw.Center(
      child: pw.Text(letter,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)));
  if (style == BubbleStyle.box) {
    return pw.Container(
        width: 18,
        height: 18,
        decoration: pw.BoxDecoration(border: border),
        child: inner);
  }
  return pw.Container(
    width: 18,
    height: 18,
    decoration: pw.BoxDecoration(border: border, shape: pw.BoxShape.circle),
    child: inner,
  );
}
