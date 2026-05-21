class Student {
  final int? id;
  final String studentNo;
  final String fullName;
  final int sectionId;

  const Student({
    this.id,
    required this.studentNo,
    required this.fullName,
    required this.sectionId,
  });

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'] as int?,
        studentNo: j['student_no'] as String,
        fullName: j['full_name'] as String,
        sectionId: j['section_id'] as int,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'student_no': studentNo,
        'full_name': fullName,
        'section_id': sectionId,
      };
}
