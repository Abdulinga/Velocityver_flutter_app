import 'base_model.dart';
import 'course.dart';
import 'user.dart';

class FileModel extends BaseModel {
  String name;
  String path; // maps to file_path
  String? description;
  int size; // maps to file_size
  String mimeType;
  String uploadedBy;
  String? courseId;
  List<String> targetRoles;
  bool isPublic;
  int downloadCount;
  String? profilePicture; // For file thumbnails
  final String? message;

  // Compatibility properties for existing code
  String get originalName => name;
  String get filePath => path;
  int get fileSize => size;

  // Mutable properties for compatibility
  bool isSynced = true;
  String? localPath;
  String? serverPath;

  // Related objects (mutable for compatibility)
  Course? course;
  User? uploader;

  // File type detection methods
  String get fileExtension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  bool get isImage =>
      ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(fileExtension);
  bool get isPdf => fileExtension == 'pdf';
  bool get isDocument => ['doc', 'docx', 'txt', 'rtf'].contains(fileExtension);
  bool get isSpreadsheet => ['xls', 'xlsx', 'csv'].contains(fileExtension);
  bool get isPresentation => ['ppt', 'pptx'].contains(fileExtension);

  FileModel({
    super.id,
    required this.name,
    required this.path,
    this.description,
    required this.size,
    required this.mimeType,
    required this.uploadedBy,
    this.courseId,
    this.targetRoles = const [],
    this.isPublic = false,
    this.downloadCount = 0,
    this.profilePicture,
    this.message,
    super.createdAt,
    super.updatedAt,
    super.lastSync,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = baseToJson();
    json.addAll({
      'id': id,
      'name': name,
      'original_name': name,
      'file_path': path,
      'description': description,
      'file_size': size,
      'mime_type': mimeType,
      'uploaded_by': uploadedBy,
      'course_id': courseId,
      'target_roles': targetRoles,
      'is_public': isPublic,
      'download_count': downloadCount,
      'profile_picture': profilePicture,
      'message': message,
      'local_path': localPath ?? path,
      'server_path': serverPath,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'lastSync': lastSync?.toIso8601String(),
    });
    return json;
  }

  factory FileModel.fromJson(Map<String, dynamic> json) {
  return FileModel(
    id: json['id']?.toString(),
    name: json['name'] ?? json['original_name'] ?? 'Unknown',
    path: json['file_path'] ?? '',
    description: json['description'],
    size: json['file_size'] ?? 0,
    mimeType: (json['mime_type'] ?? 'application/octet-stream').toString(),
    uploadedBy: json['uploaded_by']?.toString() ?? 'system',
    courseId: json['course_id']?.toString(),
    targetRoles: [],
    isPublic: json['is_public'] ?? false,
    downloadCount: json['download_count'] ?? 0,
    profilePicture: json['profile_picture'],
    message: json['message'],
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString())
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'].toString())
        : null,
    lastSync: json['lastSync'] != null
        ? DateTime.tryParse(json['lastSync'].toString())
        : null,
  );
}
  FileModel copyWith({
    String? id,
    String? name,
    String? path,
    String? description,
    int? size,
    String? mimeType,
    String? uploadedBy,
    String? courseId,
    List<String>? targetRoles,
    bool? isPublic,
    int? downloadCount,
    String? profilePicture,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSync,
  }) {
    return FileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      description: description ?? this.description,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      courseId: courseId ?? this.courseId,
      targetRoles: targetRoles ?? this.targetRoles,
      isPublic: isPublic ?? this.isPublic,
      downloadCount: downloadCount ?? this.downloadCount,
      profilePicture: profilePicture ?? this.profilePicture,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSync: lastSync ?? this.lastSync,
    );
  }

  String get formattedSize {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  @override
  String toString() =>
      'FileModel(id: $id, name: $name, size: $formattedSize, path: $path, message: $message)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileModel &&
        other.id == id &&
        other.name == name &&
        other.path == path &&
        other.size == size &&
        other.mimeType == mimeType;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, path, size, mimeType);
}
