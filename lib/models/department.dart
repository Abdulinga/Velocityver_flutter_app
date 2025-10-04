import 'base_model.dart';
import 'faculty.dart';

class Department extends BaseModel {
  final String name;
  final String code;
  final String facultyId;
  final String? description;
  final String? hodId; // Head of Department
  final bool isActive;

  // Related objects (mutable for compatibility)
  Faculty? faculty;

  Department({
    super.id,
    required this.name,
    required this.code,
    required this.facultyId,
    this.description,
    this.hodId,
    this.isActive = true,
    super.createdAt,
    super.updatedAt,
    super.lastSync,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = baseToJson();
    json.addAll({
      'name': name,
      'code': code,
      'faculty_id': facultyId,
      'description': description,
      'hodId': hodId,
      'isActive': isActive ? 1 : 0,
    });
    return json;
  }

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      facultyId: json['faculty_id'] ?? json['facultyId'],
      description: json['description'],
      hodId: json['hodId'],
      isActive: (json['isActive'] ?? json['is_active'] ?? 1) == 1,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      lastSync: json['lastSync'] != null
          ? DateTime.parse(json['lastSync'])
          : null,
    );
  }

  Department copyWith({
    String? id,
    String? name,
    String? code,
    String? facultyId,
    String? description,
    String? hodId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSync,
  }) {
    return Department(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      facultyId: facultyId ?? this.facultyId,
      description: description ?? this.description,
      hodId: hodId ?? this.hodId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSync: lastSync ?? this.lastSync,
    );
  }

  @override
  String toString() {
    return 'Department(id: $id, name: $name, code: $code, facultyId: $facultyId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Department &&
        other.id == id &&
        other.name == name &&
        other.code == code &&
        other.facultyId == facultyId &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, code, facultyId, isActive);
  }
}
