import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'database_service.dart';
import 'auth_service.dart';
import 'dart:convert';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  // Get the app's documents directory for storing files
  Future<Directory> get _appDocumentsDirectory async {
    final directory = await getApplicationDocumentsDirectory();
    final appDir = Directory(path.join(directory.path, 'velocityver_files'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  // Get course-specific directory
  Future<Directory> _getCourseDirectory(String courseId) async {
    final appDir = await _appDocumentsDirectory;
    final courseDir = Directory(path.join(appDir.path, courseId));
    if (!await courseDir.exists()) {
      await courseDir.create(recursive: true);
    }
    return courseDir;
  }

  // Pick files from device
  Future<List<PlatformFile>?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    try {
      // Request storage permission
      final permission = await Permission.storage.request();
      if (!permission.isGranted) {
        throw Exception('Storage permission denied');
      }

      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: true,
      );

      return result?.files;
    } catch (e) {
      print('Error picking files: $e');
      return null;
    }
  }
     

  // Upload file to course
Future<FileModel?> uploadFile({
  required PlatformFile platformFile,
  required String courseId,
  String? description,
}) async {
  try {
    final currentUser = AuthService().currentUser!;
    final request = http.MultipartRequest(
      'POST',
       Uri.parse('http://192.168.1.155:5000/api/files/uploads'), 
    );

    debugPrint('Uploading file: ${platformFile.name} to course $courseId by user ${currentUser.id}');

    request.fields['course_id'] = courseId;
    request.fields['uploaded_by'] = currentUser.id;
    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }

    // Attach file safely
    if (platformFile.path != null) {
      request.files.add(await http.MultipartFile.fromPath('file', platformFile.path!, filename: platformFile.name));
    } else if (platformFile.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes('file', platformFile.bytes!, filename: platformFile.name));
    } else {
      debugPrint('❌ File has no path or bytes!');
      return null;
    }

    final response = await request.send();

    debugPrint('HTTP status: ${response.statusCode}');
    final responseBody = await response.stream.bytesToString();
    debugPrint('Response body: $responseBody');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return FileModel.fromJson(jsonDecode(responseBody));
    }

    return null;
  } catch (e) {
    debugPrint('⚠️ Error uploading file: $e');
    return null;
  }
}


  // Get files for a course
  Future<List<FileModel>> getCourseFiles(String courseId) async {
    try {
      // Check if user can access this course
      final canAccess = await _authService.canAccessCourse(courseId);
      if (!canAccess) {
        throw Exception('Permission denied');
      }

      return await _databaseService.getFilesByCourse(courseId);
    } catch (e) {
      print('Error getting course files: $e');
      return [];
    }
  }

  // Download file (for students)
  Future<bool> downloadFile(FileModel file) async {
    try {
      // Check if user can access the file's course
      if (file.courseId != null) {
        final canAccess = await _authService.canAccessCourse(file.courseId!);
        if (!canAccess) {
          throw Exception('Permission denied');
        }
      }

      // If file is already local, no need to download
      if (file.localPath != null && await File(file.localPath!).exists()) {
        return true;
      }

      // For offline-first, files should already be local
      // In a real implementation, this would download from server
      // For now, we'll just check if the file exists locally
      if (await File(file.filePath).exists()) {
        // Update local path if needed
        if (file.localPath != file.filePath) {
          file.localPath = file.filePath;
          await _databaseService.updateFile(file);
        }
        return true;
      }

      return false;
    } catch (e) {
      print('Error downloading file: $e');
      return false;
    }
  }

  // Open/preview file
  Future<bool> openFile(FileModel file) async {
    try {
      // Ensure file is downloaded
      final downloaded = await downloadFile(file);
      if (!downloaded) {
        throw Exception('File not available');
      }

      final filePath = file.localPath ?? file.filePath;
      if (!await File(filePath).exists()) {
        throw Exception('File not found locally');
      }

      final result = await OpenFile.open(filePath);
      return result.type == ResultType.done;
    } catch (e) {
      print('Error opening file: $e');
      return false;
    }
  }

  // Delete file
  Future<bool> deleteFile(FileModel file) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check permissions
      bool canManage = false;
      if (file.courseId != null) {
        canManage = await _authService.canManageCourse(file.courseId!);
      }
      final isOwner = file.uploadedBy == currentUser.id;

      if (!canManage && !isOwner && !_authService.isSuperAdmin()) {
        throw Exception('Permission denied');
      }

      // Delete local file
      if (file.localPath != null && await File(file.localPath!).exists()) {
        await File(file.localPath!).delete();
      }
      if (await File(file.filePath).exists()) {
        await File(file.filePath).delete();
      }

      // Remove from database
      await _databaseService.deleteFile(file.id);

      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  // Get user's uploaded files
  Future<List<FileModel>> getUserFiles() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return [];

      return await _databaseService.getFilesByUploader(currentUser.id);
    } catch (e) {
      print('Error getting user files: $e');
      return [];
    }
  }

  // Get file info
  Future<Map<String, dynamic>> getFileInfo(FileModel file) async {
    final filePath = file.localPath ?? file.filePath;
    final fileExists = await File(filePath).exists();

    FileStat? stats;
    if (fileExists) {
      stats = await File(filePath).stat();
    }

    return {
      'exists': fileExists,
      'size': file.fileSize,
      'formattedSize': file.formattedSize,
      'extension': file.fileExtension,
      'mimeType': file.mimeType,
      'isImage': file.isImage,
      'isPdf': file.isPdf,
      'isDocument': file.isDocument,
      'lastModified': stats?.modified,
      'localPath': file.localPath,
      'serverPath': file.serverPath,
      'isSynced': file.isSynced,
    };
  }

  // Get storage usage
  Future<Map<String, dynamic>> getStorageUsage() async {
    try {
      final appDir = await _appDocumentsDirectory;
      int totalSize = 0;
      int fileCount = 0;

      await for (final entity in appDir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
          fileCount++;
        }
      }

      return {
        'totalSize': totalSize,
        'fileCount': fileCount,
        'formattedSize': _formatBytes(totalSize),
      };
    } catch (e) {
      print('Error getting storage usage: $e');
      return {'totalSize': 0, 'fileCount': 0, 'formattedSize': '0 B'};
    }
  }

  // Clean up orphaned files
  Future<void> cleanupOrphanedFiles() async {
    try {
      final appDir = await _appDocumentsDirectory;
      final allFiles = await _databaseService.getAllFiles();
      final validPaths = allFiles.map((f) => f.filePath).toSet();

      await for (final entity in appDir.list(recursive: true)) {
        if (entity is File && !validPaths.contains(entity.path)) {
          await entity.delete();
        }
      }
    } catch (e) {
      print('Error cleaning up orphaned files: $e');
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      case '.ppt':
      case '.pptx':
        return 'application/vnd.ms-powerpoint';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get files that have been downloaded by a specific user
  Future<List<FileModel>> getDownloadedFiles(String userId) async {
    try {
      final db = await _databaseService.database;

      // Get files that have been downloaded (have local_path set)
      final result = await db.query(
        'files',
        where: 'local_path IS NOT NULL AND local_path != ""',
        orderBy: 'updated_at DESC',
      );

      final files = <FileModel>[];
      for (final row in result) {
        final file = FileModel.fromJson(row);

        // Check if the local file still exists
        if (file.localPath != null) {
          final localFile = File(file.localPath!);
          if (await localFile.exists()) {
            files.add(file);
          } else {
            // File was deleted, update database
            await db.update(
              'files',
              {'local_path': null},
              where: 'id = ?',
              whereArgs: [file.id],
            );
          }
        }
      }

      return files;
    } catch (e) {
      debugPrint('Error getting downloaded files: $e');
      return [];
    }
  }

  /// Delete a downloaded file from local storage
  Future<void> deleteDownloadedFile(String fileId) async {
    try {
      final db = await _databaseService.database;

      // Get file info
      final result = await db.query(
        'files',
        where: 'id = ?',
        whereArgs: [fileId],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final file = FileModel.fromJson(result.first);

        // Delete local file if it exists
        if (file.localPath != null) {
          final localFile = File(file.localPath!);
          if (await localFile.exists()) {
            await localFile.delete();
          }
        }

        // Update database to remove local path
        await db.update(
          'files',
          {'local_path': null, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [fileId],
        );
      }
    } catch (e) {
      debugPrint('Error deleting downloaded file: $e');
      rethrow;
    }
  }

  /// Share a file using the system share dialog
  Future<void> shareFile(FileModel file) async {
    try {
      if (file.localPath != null) {
        final localFile = File(file.localPath!);
        if (await localFile.exists()) {
          // For now, just show a message since share functionality requires additional packages
          debugPrint('Sharing file: ${file.name}');
          // TODO: Implement actual sharing with share_plus package
        }
      }
    } catch (e) {
      debugPrint('Error sharing file: $e');
      rethrow;
    }
  }
  /// Downloads a file from a given API URL and saves it locally
  Future<bool> downloadFileFromUrl(String url, FileModel file) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Get app's document directory
        final dir = await getApplicationDocumentsDirectory();

        // Use the original name if available
        final filename = file.originalName ?? file.name;
        final localPath = '${dir.path}/$filename';

        // Write bytes to disk
        final localFile = File(localPath);
        await localFile.writeAsBytes(response.bodyBytes);

        return true;
      } else {
        print('❌ Failed to download file: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('⚠️ Error downloading file: $e');
      return false;
    }
  }
}

