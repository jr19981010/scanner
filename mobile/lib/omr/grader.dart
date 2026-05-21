/// OMR top-level entry point.
///
/// Stub: returns all-blank answers (-1). Wire the steps in [perspective.dart],
/// [fiducials.dart], and [bubble_grid.dart] to make this real.
///
/// Phase-3 implementation will:
///   1. Decode `imagePath` into bytes (File(imagePath).readAsBytes()).
///   2. perspective.warpPaper(bytes)
///   3. fiducials.locate(warped)
///   4. bubble_grid.readAnswers(warped, layout)
///   5. Return List<int> (length == itemCount; -1 if ambiguous/blank).
Future<List<int>> runOmrPipeline({
  required String imagePath,
  required int itemCount,
  required int choiceCount,
}) async {
  // ignore: avoid_print
  print('OMR stub: image=$imagePath items=$itemCount choices=$choiceCount');
  return List<int>.filled(itemCount, -1);
}
