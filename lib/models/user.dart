import 'base_model.dart';
import 'role.dart';
import 'level.dart';
import 'year.dart';
import 'department.dart';
import 'faculty.dart';

class User extends BaseModel {
  String username;
  String email;
  String passwordHash;
  String roleId;
  String firstName;
  String lastName;
  String? levelId;
  String? yearId;
  String? departmentId;
  String? facultyId;
  bool isActive;
  String? profilePicture; // Base64 encoded image or file path

  // Related objects (loaded separately)
  Role? role;
  Level? level;
  Year? year;
  Department? department;
  Faculty? faculty;

  User({
    super.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.roleId,
    required this.firstName,
    required this.lastName,
    this.levelId,
    this.yearId,
    this.departmentId,
    this.facultyId,
    this.isActive = true,
    this.profilePicture,
    super.createdAt,
    super.updatedAt,
    super.lastSync,
    this.role,
    this.level,
    this.year,
    this.department,
    this.faculty,
  });

  String get fullName => '$firstName $lastName';

  UserRole get userRole {
    if (role != null) {
      return UserRole.fromString(role!.name);
    }
    return UserRole.student;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = baseToJson();
    json.addAll({
      'username': username,
      'email': email,
      'password_hash': passwordHash,
      'role_id': roleId,
      'first_name': firstName,
      'last_name': lastName,
      'level_id': levelId,
      'year_id': yearId,
      'department_id': departmentId,
      'faculty_id': facultyId,
      'is_active': isActive ? 1 : 0,
      'profile_picture': profilePicture,
    });
    return json;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final user = User(
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      passwordHash: json['password_hash'] ?? '',
      roleId: json['role_id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      levelId: json['level_id'],
      yearId: json['year_id'],
      departmentId: json['department_id'],
      facultyId: json['faculty_id'],
      isActive: (json['is_active'] ?? 1) == 1,
      profilePicture: json['profile_picture'],
    );
    user.baseFromJson(json);
    return user;
  }

  User copyWith({
    String? username,
    String? email,
    String? passwordHash,
    String? roleId,
    String? firstName,
    String? lastName,
    String? levelId,
    String? yearId,
    String? departmentId,
    String? facultyId,
    bool? isActive,
    Role? role,
    Level? level,
    Year? year,
    Department? department,
    Faculty? faculty,
  }) {
    return User(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      roleId: roleId ?? this.roleId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      levelId: levelId ?? this.levelId,
      yearId: yearId ?? this.yearId,
      departmentId: departmentId ?? this.departmentId,
      facultyId: facultyId ?? this.facultyId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastSync: lastSync,
      role: role ?? this.role,
      level: level ?? this.level,
      year: year ?? this.year,
      department: department ?? this.department,
      faculty: faculty ?? this.faculty,
    );
  }
}
