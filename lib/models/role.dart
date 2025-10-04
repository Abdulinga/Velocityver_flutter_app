import 'base_model.dart';

class Role extends BaseModel {
  final String name;
  final String description;
  final List<String> permissions;
  final bool isActive;

  Role({
    super.id,
    required this.name,
    this.description = '',
    this.permissions = const [],
    this.isActive = true,
    super.createdAt,
    super.updatedAt,
    super.lastSync,
  });

  bool hasPermission(String permission) {
    return permissions.contains(permission) ||
        permissions.contains('full_access');
  }

  @override
  Map<String, dynamic> toJson() {
    final json = baseToJson();
    json.addAll({
      'name': name,
      'description': description,
      'permissions': permissions.join(','),
      'is_active': isActive ? 1 : 0,
    });
    return json;
  }

  factory Role.fromJson(Map<String, dynamic> json) {
    // Handle permissions - could be string or list
    List<String> permissionsList;
    if (json['permissions'] is String) {
      permissionsList = (json['permissions'] as String)
          .split(',')
          .where((String s) => s.trim().isNotEmpty)
          .map((String s) => s.trim())
          .toList();
    } else {
      permissionsList = List<String>.from(json['permissions'] ?? []);
    }

    return Role(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      permissions: permissionsList,
      isActive: (json['is_active'] ?? 1) == 1,
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

  Role copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? permissions,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSync,
  }) {
    return Role(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSync: lastSync ?? this.lastSync,
    );
  }

  @override
  String toString() {
    return 'Role(id: $id, name: $name, permissions: ${permissions.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Role &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, description, isActive);
  }
}
