import 'base_model.dart';

class Level extends BaseModel {
  final String name;
  final String code;
  final String? description;
  final int order;
  final bool isActive;

  Level({
    super.id,
    required this.name,
    required this.code,
    this.description,
    required this.order,
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
      'order_num': order,
      'isActive': isActive,
    });
    return json;
  }

  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      description: json['description'],
      order: json['order_num'] ?? json['order'] ?? 1,
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

  Level copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    int? order,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSync,
  }) {
    return Level(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSync: lastSync ?? this.lastSync,
    );
  }

  @override
  String toString() {
    return 'Level(id: $id, name: $name, code: $code, order: $order)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Level &&
        other.id == id &&
        other.name == name &&
        other.code == code &&
        other.order == order &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, code, order, isActive);
  }
}
