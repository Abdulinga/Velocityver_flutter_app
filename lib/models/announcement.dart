import 'base_model.dart';
import 'user.dart';

class Announcement extends BaseModel {
  String title;
  String content;
  String authorId;
  List<String> targetRoles;
  List<String> targetCourses;
  bool isActive;

  // Related objects
  User? author;

  Announcement({
    super.id,
    required this.title,
    required this.content,
    required this.authorId,
    this.targetRoles = const [],
    this.targetCourses = const [],
    this.isActive = true,
    super.createdAt,
    super.updatedAt,
    super.lastSync,
    this.author,
  });

  bool isTargetedToUser(User user) {
    // If no specific targets, show to everyone
    if (targetRoles.isEmpty && targetCourses.isEmpty) {
      return true;
    }

    // Check if user's role is targeted
    if (targetRoles.isNotEmpty && user.role != null) {
      if (targetRoles.contains(user.role!.id) || 
          targetRoles.contains(user.role!.name.toLowerCase())) {
        return true;
      }
    }

    // Check if any of user's courses are targeted
    if (targetCourses.isNotEmpty) {
      // This would need to be checked against user's enrolled courses
      // Implementation depends on how we load user's courses
      return false; // Placeholder
    }

    return false;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = baseToJson();
    json.addAll({
      'title': title,
      'content': content,
      'author_id': authorId,
      'target_roles': targetRoles.join(','),
      'target_courses': targetCourses.join(','),
      'is_active': isActive ? 1 : 0,
    });
    return json;
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final announcement = Announcement(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      authorId: json['author_id'] ?? '',
      targetRoles: json['target_roles'] != null && json['target_roles'].toString().isNotEmpty
          ? json['target_roles'].toString().split(',')
          : [],
      targetCourses: json['target_courses'] != null && json['target_courses'].toString().isNotEmpty
          ? json['target_courses'].toString().split(',')
          : [],
      isActive: (json['is_active'] ?? 1) == 1,
    );
    announcement.baseFromJson(json);
    return announcement;
  }

  Announcement copyWith({
    String? title,
    String? content,
    String? authorId,
    List<String>? targetRoles,
    List<String>? targetCourses,
    bool? isActive,
    User? author,
  }) {
    return Announcement(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      targetRoles: targetRoles ?? this.targetRoles,
      targetCourses: targetCourses ?? this.targetCourses,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastSync: lastSync,
      author: author ?? this.author,
    );
  }
}

class SyncMetadata extends BaseModel {
  String tableName;
  String recordId;
  SyncAction action;
  Map<String, dynamic>? data;
  DateTime? syncedAt;
  bool isSynced;

  SyncMetadata({
    super.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    this.data,
    this.syncedAt,
    this.isSynced = false,
    super.createdAt,
    super.updatedAt,
    super.lastSync,
  });

  void markSyncComplete() {
    isSynced = true;
    syncedAt = DateTime.now();
    updateTimestamp();
  }

  @override
  Map<String, dynamic> toJson() {
    final json = baseToJson();
    json.addAll({
      'table_name': tableName,
      'record_id': recordId,
      'action': action.name,
      'data': data != null ? data.toString() : null,
      'synced_at': syncedAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    });
    return json;
  }

  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    final syncMetadata = SyncMetadata(
      tableName: json['table_name'] ?? '',
      recordId: json['record_id'] ?? '',
      action: SyncAction.fromString(json['action'] ?? 'create'),
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      syncedAt: json['synced_at'] != null 
          ? DateTime.parse(json['synced_at'])
          : null,
      isSynced: (json['is_synced'] ?? 0) == 1,
    );
    syncMetadata.baseFromJson(json);
    return syncMetadata;
  }
}
