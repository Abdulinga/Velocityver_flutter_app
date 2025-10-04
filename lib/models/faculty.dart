import 'base_model.dart';

class Faculty extends BaseModel {
  final String name;
  final String code;
  final String? description;
  final String? deanId;
  final bool isActive;

  Faculty({
    super.id,
    required this.name,
    required this.code,
    this.description,
    this.deanId,
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
      'description': description,
      'deanId': deanId,
      'isActive': isActive,
    });
    return json;
  }

  factory Faculty.fromJson(Map<String, dynamic> json) {
    return Faculty(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      description: json['description'],
      deanId: json['deanId'],
      isActive: json['isActive'] ?? true,
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

  Faculty copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    String? deanId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSync,
  }) {
    return Faculty(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      deanId: deanId ?? this.deanId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSync: lastSync ?? this.lastSync,
    );
  }

  @override
  String toString() {
    return 'Faculty(id: $id, name: $name, code: $code)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Faculty &&
        other.id == id &&
        other.name == name &&
        other.code == code &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, code, isActive);
  }
}
