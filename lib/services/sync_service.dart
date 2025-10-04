import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'database_service.dart';
import 'auth_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  // Server configuration - hardcoded for testing
  static String baseUrl = 'http://192.168.1.155:5000'; // Your server IP
  static const Duration syncTimeout = Duration(seconds: 30);

  // Update server URL dynamically
  static void updateServerUrl(String newUrl) {
    baseUrl = newUrl;
  }

  // Initialize sync service with saved settings
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('server_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        baseUrl = savedUrl;
        debugPrint('✅ Loaded server URL: $baseUrl');
      } else {
        debugPrint('⚠️ No saved server URL found, using default: $baseUrl');
      }
    } catch (e) {
      debugPrint('❌ Failed to load server settings: $e');
    }
  }

  // Test connection to server
  static Future<bool> testConnection(String serverUrl) async {
    try {
      final response = await http
          .get(
            Uri.parse('$serverUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(syncTimeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }

  // Test all API endpoints
  static Future<Map<String, bool>> testAllEndpoints(String serverUrl) async {
    final endpoints = [
      '/health',
      '/api/users',
      '/api/roles',
      '/api/faculties',
      '/api/departments',
      '/api/levels',
      '/api/years',
      '/api/courses',
      '/api/files',
      '/api/announcements',
      '/api/user-courses',
    ];

    final results = <String, bool>{};

    for (final endpoint in endpoints) {
      try {
        final response = await http
            .get(
              Uri.parse('$serverUrl$endpoint'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 10));

        results[endpoint] = response.statusCode == 200;
        debugPrint('✅ $endpoint: ${response.statusCode}');
      } catch (e) {
        results[endpoint] = false;
        debugPrint('❌ $endpoint: $e');
      }
    }

    return results;
  }

  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Check network connectivity
  Future<bool> isConnected() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }

      // Test actual connectivity to server
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Connectivity check failed: $e');
      return false;
    }
  }

  // Perform full sync
  Future<bool> performSync() async {
    if (_isSyncing) {
      print('Sync already in progress');
      return false;
    }

    if (!await isConnected()) {
      print('No network connection available');
      return false;
    }

    _isSyncing = true;
    try {
      print('Starting sync...');

      // 1. Sync pending local changes to server
      await _syncLocalChangesToServer();

      // 2. Fetch updates from server
      await _syncServerChangesToLocal();

      // 3. Sync files
      await _syncFiles();

      _lastSyncTime = DateTime.now();
      print('Sync completed successfully');
      return true;
    } catch (e) {
      print('Sync failed: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  // Sync local changes to server
  Future<void> _syncLocalChangesToServer() async {
    final pendingItems = await _databaseService.getPendingSyncItems();

    for (final item in pendingItems) {
      try {
        await _syncItemToServer(item);
        await _databaseService.markSyncComplete(item.id);
      } catch (e) {
        print('Failed to sync item ${item.id}: $e');
        // Continue with other items
      }
    }
  }

  // Sync individual item to server
  Future<void> _syncItemToServer(SyncMetadata item) async {
    final endpoint = _getEndpointForTable(item.tableName);
    final url = '$baseUrl$endpoint';

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${_getAuthToken()}',
    };

    http.Response response;

    switch (item.action) {
      case SyncAction.create:
        response = await http
            .post(Uri.parse(url), headers: headers, body: jsonEncode(item.data))
            .timeout(syncTimeout);
        break;

      case SyncAction.update:
        response = await http
            .put(
              Uri.parse('$url/${item.recordId}'),
              headers: headers,
              body: jsonEncode(item.data),
            )
            .timeout(syncTimeout);
        break;

      case SyncAction.delete:
        response = await http
            .delete(Uri.parse('$url/${item.recordId}'), headers: headers)
            .timeout(syncTimeout);
        break;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Server error: ${response.statusCode} ${response.body}');
    }
  }

  // Sync server changes to local
  Future<void> _syncServerChangesToLocal() async {
    final lastSync = _lastSyncTime?.toIso8601String() ?? '';

    // Sync each table
    await _syncTableFromServer('users', lastSync);
    await _syncTableFromServer('roles', lastSync);
    await _syncTableFromServer('faculties', lastSync);
    await _syncTableFromServer('departments', lastSync);
    await _syncTableFromServer('levels', lastSync);
    await _syncTableFromServer('years', lastSync);
    await _syncTableFromServer('courses', lastSync);
    await _syncTableFromServer('files', lastSync);
    await _syncTableFromServer('announcements', lastSync);
    await _syncTableFromServer('user_courses', lastSync);
  }

  // Sync specific table from server
  Future<void> _syncTableFromServer(String tableName, String lastSync) async {
    try {
      final endpoint = _getEndpointForTable(tableName);
      final url = '$baseUrl$endpoint?since=$lastSync';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getAuthToken()}',
            },
          )
          .timeout(syncTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List;

        for (final item in items) {
          await _updateLocalRecord(tableName, item);
        }
      }
    } catch (e) {
      print('Failed to sync table $tableName: $e');
    }
  }

  // Update local record from server data
  Future<void> _updateLocalRecord(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    // This would need to be implemented based on the specific table
    // For now, we'll just print the data
    print('Updating local record in $tableName: ${data['id']}');
  }

  // Sync files between local and server
  Future<void> _syncFiles() async {
    // Upload local files that haven't been synced
    await _uploadLocalFiles();

    // Download files from server that aren't local
    await _downloadServerFiles();
  }

  // Upload local files to server
  Future<void> _uploadLocalFiles() async {
    final localFiles = await _databaseService.getAllFiles();
    final unsyncedFiles = localFiles.where((f) => !f.isSynced).toList();

    for (final file in unsyncedFiles) {
      try {
        await _uploadFileToServer(file);

        // Mark as synced
        file.isSynced = true;
        file.markSynced();
        await _databaseService.updateFile(file);
      } catch (e) {
        print('Failed to upload file ${file.id}: $e');
      }
    }
  }

  // Upload individual file to server
  Future<void> _uploadFileToServer(FileModel file) async {
    final fileData = File(file.filePath);
    if (!await fileData.exists()) {
      throw Exception('Local file not found: ${file.filePath}');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/files/upload'),
    );

    request.headers['Authorization'] = 'Bearer ${_getAuthToken()}';
    request.fields['file_id'] = file.id;
    request.fields['course_id'] = file.courseId ?? '';
    request.fields['description'] = file.description ?? '';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.filePath,
        filename: file.originalName,
      ),
    );

    final response = await request.send().timeout(syncTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final responseBody = await response.stream.bytesToString();
      throw Exception('Upload failed: ${response.statusCode} $responseBody');
    }
  }

  // Download files from server
  Future<void> _downloadServerFiles() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/files'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getAuthToken()}',
            },
          )
          .timeout(syncTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverFiles = data['files'] as List;

        for (final fileData in serverFiles) {
          await _downloadFileFromServer(fileData);
        }
      }
    } catch (e) {
      print('Failed to download server files: $e');
    }
  }

  // Download individual file from server
  Future<void> _downloadFileFromServer(Map<String, dynamic> fileData) async {
    final fileId = fileData['id'];
    final localFile = await _databaseService.getFileById(fileId);

    // Skip if file already exists locally
    if (localFile != null && localFile.localPath != null) {
      if (await File(localFile.localPath!).exists()) {
        return;
      }
    }

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/files/$fileId/download'),
            headers: {'Authorization': 'Bearer ${_getAuthToken()}'},
          )
          .timeout(syncTimeout);

      if (response.statusCode == 200) {
        // Save file locally and update database
        // Implementation would depend on file storage structure
        print('Downloaded file: $fileId');
      }
    } catch (e) {
      print('Failed to download file $fileId: $e');
    }
  }

  // Get API endpoint for table
  String _getEndpointForTable(String tableName) {
    switch (tableName) {
      case 'users':
        return '/api/users';
      case 'roles':
        return '/api/roles';
      case 'faculties':
        return '/api/faculties';
      case 'departments':
        return '/api/departments';
      case 'levels':
        return '/api/levels';
      case 'years':
        return '/api/years';
      case 'courses':
        return '/api/courses';
      case 'files':
        return '/api/files';
      case 'announcements':
        return '/api/announcements';
      case 'user_courses':
        return '/api/user-courses';
      default:
        return '/api/$tableName';
    }
  }

  // Get authentication token
  String _getAuthToken() {
    // For now, use a simple token based on user ID
    // In production, this should be a proper JWT token
    final user = _authService.currentUser;
    if (user != null) {
      return 'user_${user.id}';
    }
    return '';
  }

  // Auto-sync when network becomes available
  void startAutoSync() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      if (result != ConnectivityResult.none) {
        // Delay to ensure connection is stable
        Future.delayed(const Duration(seconds: 2), () {
          performSync();
        });
      }
    });
  }

  // Manual sync trigger
  Future<bool> triggerSync() async {
    return await performSync();
  }
}
