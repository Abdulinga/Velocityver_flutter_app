import 'package:uuid/uuid.dart';

abstract class BaseModel {
  String id;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? lastSync;

  BaseModel({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastSync,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson();
  
  void updateTimestamp() {
    updatedAt = DateTime.now();
  }

  void markSynced() {
    lastSync = DateTime.now();
  }

  Map<String, dynamic> baseToJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_sync': lastSync?.toIso8601String(),
    };
  }

  void baseFromJson(Map<String, dynamic> json) {
    id = json['id'] ?? const Uuid().v4();
    createdAt = json['created_at'] != null 
        ? DateTime.parse(json['created_at']) 
        : DateTime.now();
    updatedAt = json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']) 
        : DateTime.now();
    lastSync = json['last_sync'] != null 
        ? DateTime.parse(json['last_sync']) 
        : null;
  }
}

enum UserRole {
  student('Student'),
  lecturer('Lecturer'),
  admin('Admin'),
  superAdmin('Super Admin');

  const UserRole(this.displayName);
  final String displayName;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return UserRole.student;
      case 'lecturer':
        return UserRole.lecturer;
      case 'admin':
        return UserRole.admin;
      case 'super admin':
      case 'superadmin':
        return UserRole.superAdmin;
      default:
        return UserRole.student;
    }
  }
}

enum SyncAction {
  create,
  update,
  delete;

  static SyncAction fromString(String action) {
    switch (action.toLowerCase()) {
      case 'create':
        return SyncAction.create;
      case 'update':
        return SyncAction.update;
      case 'delete':
        return SyncAction.delete;
      default:
        return SyncAction.create;
    }
  }
}
