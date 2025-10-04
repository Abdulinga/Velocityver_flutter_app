import 'base_model.dart';
import 'user.dart';
import 'file_model.dart';
import 'level.dart';
import 'year.dart';
import 'department.dart';
import 'faculty.dart';

class Course extends BaseModel {
  String name;
  String code;
  String? description;
  String levelId;
  String yearId;
  String departmentId;
  String facultyId;
  String? lecturerId;
  bool isActive;

  // Related objects (loaded separately)
  Level? level;
  Year? year;
  Department? department;
  Faculty? faculty;
  User? lecturer;
  List<FileModel>? files;
  List<User>? enrolledStudents;

  Course({
    super.id,
    required this.name,
    required this.code,
    this.description,
    required this.levelId,
    required this.yearId,
    required this.departmentId,
    required this.facultyId,
    this.lecturerId,
    this.isActive = true,
    super.createdAt,
    super.updatedAt,
    super.lastSync,
    this.level,
    this.year,
    this.department,
    this.faculty,
    this.lecturer,
    this.files,
    this.enrolledStudents,
  });

  String get fullName => '$code - $name';

  @override
  Map<String, dynamic> toJson() {
    final json = baseToJson();
    json.addAll({
      'name': name,
      'code': code,
      'description': description,
      'level_id': levelId,
      'year_id': yearId,
      'department_id': departmentId,
      'faculty_id': facultyId,
      'lecturer_id': lecturerId,
      'is_active': isActive ? 1 : 0,
    });
    return json;
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    final course = Course(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      description: json['description'],
      levelId: json['level_id'] ?? '',
      yearId: json['year_id'] ?? '',
      departmentId: json['department_id'] ?? '',
      facultyId: json['faculty_id'] ?? '',
      lecturerId: json['lecturer_id'],
      isActive: (json['is_active'] ?? 1) == 1,
    );
    course.baseFromJson(json);
    return course;
  }

  Course copyWith({
    String? name,
    String? code,
    String? description,
    String? levelId,
    String? yearId,
    String? departmentId,
    String? facultyId,
    String? lecturerId,
    bool? isActive,
    Level? level,
    Year? year,
    Department? department,
    Faculty? faculty,
    User? lecturer,
    List<FileModel>? files,
    List<User>? enrolledStudents,
  }) {
    return Course(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      levelId: levelId ?? this.levelId,
      yearId: yearId ?? this.yearId,
      departmentId: departmentId ?? this.departmentId,
      facultyId: facultyId ?? this.facultyId,
      lecturerId: lecturerId ?? this.lecturerId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastSync: lastSync,
      level: level ?? this.level,
      year: year ?? this.year,
      department: department ?? this.department,
      faculty: faculty ?? this.faculty,
      lecturer: lecturer ?? this.lecturer,
      files: files ?? this.files,
      enrolledStudents: enrolledStudents ?? this.enrolledStudents,
    );
  }
}

class UserCourse extends BaseModel {
  String userId;
  String courseId;
  DateTime enrolledAt;

  // Related objects
  User? user;
  Course? course;

  UserCourse({
    super.id,
    required this.userId,
    required this.courseId,
    DateTime? enrolledAt,
    super.createdAt,
    super.updatedAt,
    super.lastSync,
    this.user,
    this.course,
  }) : enrolledAt = enrolledAt ?? DateTime.now();

  @override
  Map<String, dynamic> toJson() {
    final json = baseToJson();
    json.addAll({
      'user_id': userId,
      'course_id': courseId,
      'enrolled_at': enrolledAt.toIso8601String(),
    });
    return json;
  }

  factory UserCourse.fromJson(Map<String, dynamic> json) {
    final userCourse = UserCourse(
      userId: json['user_id'] ?? '',
      courseId: json['course_id'] ?? '',
      enrolledAt: json['enrolled_at'] != null
          ? DateTime.parse(json['enrolled_at'])
          : DateTime.now(),
    );
    userCourse.baseFromJson(json);
    return userCourse;
  }
}
