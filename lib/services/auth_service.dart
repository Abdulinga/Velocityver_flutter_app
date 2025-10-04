import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/models.dart';
import 'database_service.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Dependencies
  final DatabaseService _databaseService = DatabaseService();

  // State
  User? _currentUser;

  // Constants
  static const String _currentUserKey = 'current_user';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _defaultServerUrl = 'http://192.168.1.155:5000';
  static const Duration _serverTimeout = Duration(seconds: 10);

  // Public getters
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Initialize the auth service by loading any saved user data
  Future<void> initialize() async {
    await _loadCurrentUser();
  }

  /// Authenticate user with hybrid online/offline approach
  /// 
  /// Attempts server login first, falls back to local database if server unavailable
  Future<bool> login(String username, String password) async {
    try {
      debugPrint('🔐 AuthService: Starting login for $username');

      // Attempt server login first (prioritize online authentication)
      final serverUser = await _attemptServerLogin(username, password);
      if (serverUser != null) {
        await _completeLogin(serverUser);
        await _syncUserToLocal(serverUser);
        debugPrint('✅ Server login completed successfully');
        return true;
      }

      // Fallback to local database authentication
      debugPrint('🔍 Attempting local database authentication');
      final localUser = await _attemptLocalLogin(username, password);
      if (localUser != null) {
        await _completeLogin(localUser);
        debugPrint('✅ Local login completed successfully');
        return true;
      }

      debugPrint('❌ All login attempts failed');
      return false;
    } catch (e) {
      debugPrint('❌ Login error: $e');
      return false;
    }
  }

  /// Log out the current user and clear stored data
  Future<void> logout() async {
    debugPrint('🚪 Logging out user: ${_currentUser?.username ?? 'unknown'}');
    _currentUser = null;
    await _clearStoredUserData();
  }

  /// Change the current user's password
  /// 
  /// Verifies current password before allowing change
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (_currentUser == null) {
      debugPrint('❌ Cannot change password: no user logged in');
      return false;
    }

    try {
      // Verify current password
      final authenticatedUser = await _databaseService.authenticateUser(
        _currentUser!.username,
        currentPassword,
      );
      
      if (authenticatedUser == null) {
        debugPrint('❌ Current password verification failed');
        return false;
      }

      // Update password in database
      final updatedUser = _currentUser!.copyWith(
        passwordHash: _hashPassword(newPassword),
      );

      await _databaseService.updateUser(updatedUser);
      _currentUser = updatedUser;
      await _saveCurrentUser();

      debugPrint('✅ Password changed successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Change password error: $e');
      return false;
    }
  }

  /// Refresh current user data from database
  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;

    try {
      final freshUser = await _databaseService.getUserById(_currentUser!.id);
      if (freshUser != null) {
        _currentUser = freshUser;
        await _saveCurrentUser();
        debugPrint('✅ Current user refreshed');
      } else {
        debugPrint('⚠️ User no longer exists, logging out');
        await logout();
      }
    } catch (e) {
      debugPrint('❌ Error refreshing current user: $e');
    }
  }

  // Permission checking methods
  bool hasPermission(String permission) {
    if (_currentUser?.role == null) return false;
    return _currentUser!.role!.hasPermission(permission);
  }

  bool canAccessAdminFeatures() {
    return hasPermission('manage_users') || hasPermission('full_access');
  }

  bool canManageCourses() {
    return hasPermission('manage_courses') || hasPermission('full_access');
  }

  bool canUploadFiles() {
    return hasPermission('upload_files') ||
        hasPermission('manage_course_files') ||
        hasPermission('full_access');
  }

  bool canManageAnnouncements() {
    return hasPermission('manage_announcements') ||
        hasPermission('full_access');
  }

  bool canViewAllFiles() {
    return hasPermission('view_all_files') || hasPermission('full_access');
  }

  // Role checking methods
  bool isStudent() {
    return _currentUser?.userRole == UserRole.student;
  }

  bool isLecturer() {
    return _currentUser?.userRole == UserRole.lecturer;
  }

  bool isAdmin() {
    return _currentUser?.userRole == UserRole.admin;
  }

  bool isSuperAdmin() {
    return _currentUser?.userRole == UserRole.superAdmin;
  }

  /// Get courses accessible to the current user based on their role
  Future<List<Course>> getUserCourses() async {
    if (_currentUser == null) return [];

    try {
      switch (_currentUser!.userRole) {
        case UserRole.student:
          return await _databaseService.getCoursesByStudent(_currentUser!.id);
        case UserRole.lecturer:
          return await _databaseService.getCoursesByLecturer(_currentUser!.id);
        case UserRole.admin:
        case UserRole.superAdmin:
          return await _databaseService.getAllCourses();
      }
    } catch (e) {
      debugPrint('❌ Error getting user courses: $e');
      return [];
    }
  }

  /// Check if current user can access a specific course
  Future<bool> canAccessCourse(String courseId) async {
    if (_currentUser == null) return false;

    // Super admin and admin can access all courses
    if (isSuperAdmin() || isAdmin()) return true;

    try {
      // Get user's accessible courses
      final userCourses = await getUserCourses();
      return userCourses.any((course) => course.id == courseId);
    } catch (e) {
      debugPrint('❌ Error checking course access: $e');
      return false;
    }
  }

  /// Check if current user can manage a specific course
  Future<bool> canManageCourse(String courseId) async {
    if (_currentUser == null) return false;

    // Super admin and admin can manage all courses
    if (isSuperAdmin() || isAdmin()) return true;

    // Lecturers can only manage their assigned courses
    if (isLecturer()) {
      try {
        final course = await _databaseService.getCourseById(courseId);
        return course?.lecturerId == _currentUser!.id;
      } catch (e) {
        debugPrint('❌ Error checking course management rights: $e');
        return false;
      }
    }

    return false;
  }

  // Private helper methods

  /// Complete the login process by setting current user and saving to storage
  Future<void> _completeLogin(User user) async {
    _currentUser = user;
    await _saveCurrentUser();
  }

  /// Attempt to authenticate with server
  Future<User?> _attemptServerLogin(String username, String password) async {
    try {
      debugPrint('🌐 Attempting server login for $username');
      return await _loginWithServer(username, password);
    } catch (e) {
      debugPrint('❌ Server login failed: $e');
      return null;
    }
  }

  /// Attempt to authenticate with local database
  Future<User?> _attemptLocalLogin(String username, String password) async {
    try {
      return await _databaseService.authenticateUser(username, password);
    } catch (e) {
      debugPrint('❌ Local login failed: $e');
      return null;
    }
  }

  /// Authenticate with remote server
  Future<User?> _loginWithServer(String username, String password) async {
    try {
      final serverUrl = await _getServerUrl();
      final response = await http
          .post(
            Uri.parse('$serverUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(_serverTimeout);

      debugPrint('📡 Server login response: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ Server authentication successful');
        return _createUserFromServerResponse(username, response);
      } else {
        debugPrint('❌ Server login failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Server login error: $e');
      return null;
    }
  }

  /// Create user object from server response
  /// 
  /// This creates a basic user structure based on the username
  /// In a real implementation, the server would return complete user data
  User _createUserFromServerResponse(String username, http.Response response) {
    final userRole = _determineUserRole(username);
    final role = _createRoleFromUserRole(userRole);

    return User(
      id: 'user_$username',
      username: username,
      email: '$username@velocityver.com',
      passwordHash: '', // Server handles password, local hash not needed
      roleId: role.id,
      firstName: _capitalizeFirstLetter(username),
      lastName: 'User',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      role: role,
    );
  }

  /// Determine user role based on username (temporary implementation)
  /// 
  /// In production, this would come from server response
  UserRole _determineUserRole(String username) {
    switch (username.toLowerCase()) {
      case 'superadmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'lecturer':
        return UserRole.lecturer;
      default:
        return UserRole.student;
    }
  }

  /// Create role object from user role enum
  Role _createRoleFromUserRole(UserRole userRole) {
    switch (userRole) {
      case UserRole.superAdmin:
        return Role(
          id: 'role_super_admin',
          name: 'Super Admin',
          description: 'Full system access',
          permissions: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      case UserRole.admin:
        return Role(
          id: 'role_admin',
          name: 'Admin',
          description: 'Administrative access',
          permissions: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      case UserRole.lecturer:
        return Role(
          id: 'role_lecturer',
          name: 'Lecturer',
          description: 'Course management access',
          permissions: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      case UserRole.student:
        return Role(
          id: 'role_student',
          name: 'Student',
          description: 'Course access',
          permissions: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
    }
  }

  /// Sync user data to local database for offline access
  Future<void> _syncUserToLocal(User user) async {
    try {
      debugPrint('💾 Syncing user to local database: ${user.username}');

      final existingUser = await _databaseService.getUserById(user.id);

      if (existingUser == null) {
        await _databaseService.insertUser(user);
        debugPrint('✅ User created in local database');
      } else {
        await _databaseService.updateUser(user);
        debugPrint('✅ User updated in local database');
      }
    } catch (e) {
      debugPrint('❌ Error syncing user to local database: $e');
    }
  }

  /// Save current user to persistent storage
  Future<void> _saveCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        await prefs.setString(
          _currentUserKey,
          jsonEncode(_currentUser!.toJson()),
        );
        await prefs.setBool(_isLoggedInKey, true);
      }
    } catch (e) {
      debugPrint('❌ Error saving current user: $e');
    }
  }

  /// Load current user from persistent storage
  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

      if (isLoggedIn) {
        final userJson = prefs.getString(_currentUserKey);
        if (userJson != null) {
          final userData = jsonDecode(userJson);
          _currentUser = User.fromJson(userData);

          // Refresh user data from database to ensure it's current
          await _refreshUserFromDatabase();
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading current user: $e');
      await logout(); // Clear invalid data
    }
  }

  /// Refresh current user data from database
  Future<void> _refreshUserFromDatabase() async {
    if (_currentUser == null) return;

    try {
      final freshUser = await _databaseService.getUserById(_currentUser!.id);
      if (freshUser != null) {
        _currentUser = freshUser;
        await _saveCurrentUser();
      } else {
        debugPrint('⚠️ User no longer exists in database, logging out');
        await logout();
      }
    } catch (e) {
      debugPrint('❌ Error refreshing user from database: $e');
    }
  }

  /// Clear all stored user data
  Future<void> _clearStoredUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);
      await prefs.setBool(_isLoggedInKey, false);
    } catch (e) {
      debugPrint('❌ Error clearing stored user data: $e');
    }
  }

  /// Get server URL from preferences
  Future<String> _getServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('server_url') ?? _defaultServerUrl;
    } catch (e) {
      debugPrint('❌ Error getting server URL: $e');
      return _defaultServerUrl;
    }
  }

  /// Hash password using SHA256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Capitalize first letter of a string
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text.substring(0, 1).toUpperCase() + text.substring(1);
  }
}