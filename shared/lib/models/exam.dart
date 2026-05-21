enum BubbleStyle { circle, box }

BubbleStyle bubbleStyleFromString(String s) =>
    s == 'box' ? BubbleStyle.box : BubbleStyle.circle;

String bubbleStyleToString(BubbleStyle s) =>
    s == BubbleStyle.box ? 'box' : 'circle';

class Exam {
  final int? id;
  final String title;
  final String subject;
  final String examType;
  final int sectionId;
  final int itemCount;
  final int choiceCount;
  final BubbleStyle bubbleStyle;
  final int totalPoints;

  const Exam({
    this.id,
    required this.title,
    required this.subject,
    required this.examType,
    required this.sectionId,
    required this.itemCount,
    required this.choiceCount,
    required this.bubbleStyle,
    required this.totalPoints,
  });

  factory Exam.fromJson(Map<String, dynamic> j) => Exam(
        id: j['id'] as int?,
        title: j['title'] as String,
        subject: j['subject'] as String,
        examType: j['exam_type'] as String,
        sectionId: j['section_id'] as int,
        itemCount: j['item_count'] as int,
        choiceCount: j['choice_count'] as int,
        bubbleStyle: bubbleStyleFromString(j['bubble_style'] as String),
        totalPoints: j['total_points'] as int,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'title': title,
        'subject': subject,
        'exam_type': examType,
        'section_id': sectionId,
        'item_count': itemCount,
        'choice_count': choiceCount,
        'bubble_style': bubbleStyleToString(bubbleStyle),
        'total_points': totalPoints,
      };
}

class AnswerKeyEntry {
  final int itemNo;
  final int correct; // 0-indexed
  final int points;
  const AnswerKeyEntry({
    required this.itemNo,
    required this.correct,
    this.points = 1,
  });

  factory AnswerKeyEntry.fromJson(Map<String, dynamic> j) => AnswerKeyEntry(
        itemNo: j['item_no'] as int,
        correct: j['correct'] as int,
        points: j['points'] as int? ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'item_no': itemNo,
        'correct': correct,
        'points': points,
      };
}
