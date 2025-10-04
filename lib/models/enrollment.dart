import 'base_model.dart';
import 'user.dart';
import 'course.dart';

class Enrollment extends BaseModel {
  String studentId;
  String courseId;
  DateTime enrollmentDate;
  EnrollmentStatus status;
  String? enrolledBy; // admin user ID who enrolled the student
  String? notes;
  double? grade;
  DateTime? completionDate;

  // Related objects
  User? student;
  Course? course;
  User? enrolledByUser;

  Enrollment({
    super.id,
    required this.studentId,
    required this.courseId,
    required this.enrollmentDate,
    this.status = EnrollmentStatus.active,
    this.enrolledBy,
    this.notes,
    this.grade,
    this.completionDate,
    super.createdAt,
    super.updatedAt,
    super.lastSync,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_sync': lastSync,
    };
    json.addAll({
      'student_id': studentId,
      'course_id': courseId,
      'enrollment_date': enrollmentDate.toIso8601String(),
      'status': status.name,
      'enrolled_by': enrolledBy,
      'notes': notes,
      'grade': grade,
      'completion_date': completionDate?.toIso8601String(),
    });
    return json;
  }

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    final enrollment = Enrollment(
      id: json['id'] ?? '',
      studentId: json['student_id'] ?? '',
      courseId: json['course_id'] ?? '',
      enrollmentDate: DateTime.parse(
        json['enrollment_date'] ?? DateTime.now().toIso8601String(),
      ),
      status: EnrollmentStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => EnrollmentStatus.active,
      ),
      enrolledBy: json['enrolled_by'],
      notes: json['notes'],
      grade: json['grade']?.toDouble(),
      completionDate: json['completion_date'] != null
          ? DateTime.parse(json['completion_date'])
          : null,
    );
    enrollment.baseFromJson(json);
    return enrollment;
  }

  bool get isActive => status == EnrollmentStatus.active;
  bool get isCompleted => status == EnrollmentStatus.completed;
  bool get isDropped => status == EnrollmentStatus.dropped;

  String get statusDisplay {
    switch (status) {
      case EnrollmentStatus.active:
        return 'Active';
      case EnrollmentStatus.completed:
        return 'Completed';
      case EnrollmentStatus.dropped:
        return 'Dropped';
      case EnrollmentStatus.suspended:
        return 'Suspended';
    }
  }

  @override
  String toString() {
    return 'Enrollment(id: $id, student: $studentId, course: $courseId, status: ${status.name})';
  }
}

enum EnrollmentStatus { active, completed, dropped, suspended }

class BulkEnrollment {
  String courseId;
  List<String> studentIds;
  String? departmentId;
  String? yearId;
  String? facultyId;
  String enrolledBy;
  String? notes;

  BulkEnrollment({
    required this.courseId,
    required this.studentIds,
    this.departmentId,
    this.yearId,
    this.facultyId,
    required this.enrolledBy,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'student_ids': studentIds,
      'department_id': departmentId,
      'year_id': yearId,
      'faculty_id': facultyId,
      'enrolled_by': enrolledBy,
      'notes': notes,
    };
  }

  factory BulkEnrollment.fromJson(Map<String, dynamic> json) {
    return BulkEnrollment(
      courseId: json['course_id'] ?? '',
      studentIds: List<String>.from(json['student_ids'] ?? []),
      departmentId: json['department_id'],
      yearId: json['year_id'],
      facultyId: json['faculty_id'],
      enrolledBy: json['enrolled_by'] ?? '',
      notes: json['notes'],
    );
  }

  @override
  String toString() {
    return 'BulkEnrollment(course: $courseId, students: ${studentIds.length})';
  }
}
