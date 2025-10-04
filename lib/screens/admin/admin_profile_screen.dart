import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

 Future<void> _loadUserData() async {
  setState(() => _isLoading = true);

  try {
    // Get the currently logged in user ID from AuthService
    final userId = _authService.currentUser?.id;
    if (userId == null) {
      debugPrint("⚠️ No logged-in user found");
      setState(() => _isLoading = false);
      return;
    }

    // Fetch the latest user data from server
    final response = await http.get(
      Uri.parse('http://192.168.1.155:5000/api/users/$userId'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      setState(() {
        _currentUser = User.fromJson(data); // ✅ refresh with API response
        _isLoading = false;
      });
    } else {
      debugPrint('❌ Failed to fetch user: ${response.statusCode}');
      setState(() => _isLoading = false);
    }
  } catch (e) {
    debugPrint('Error loading admin user data: $e');
    setState(() => _isLoading = false);
  }
}
  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPasswordController.text ==
                      confirmPasswordController.text &&
                  newPasswordController.text.length >= 6) {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Passwords do not match or are too short'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _authService.changePassword(
          currentPasswordController.text,
          newPasswordController.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password changed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to change password: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Profile'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
          ? const Center(child: Text('No user data available'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile picture
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.deepPurple.shade100,
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 50,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Administrator Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'Name',
                            '${_currentUser!.firstName} ${_currentUser!.lastName}',
                          ),
                          _buildInfoRow('Username', _currentUser!.username),
                          _buildInfoRow('Email', _currentUser!.email),
                          _buildInfoRow(
                            'Role',
                            _currentUser!.role?.name ?? 'Unknown',
                          ),
                          if (_currentUser!.faculty != null)
                            _buildInfoRow(
                              'Faculty',
                              _currentUser!.faculty!.name,
                            ),
                          if (_currentUser!.department != null)
                            _buildInfoRow(
                              'Department',
                              _currentUser!.department!.name,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // System statistics
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'System Overview',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<Map<String, int>>(
                            future: _getSystemStats(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final stats = snapshot.data!;
                                return Column(
                                  children: [
                                    _buildStatRow(
                                      'Total Users',
                                      stats['users']?.toString() ?? '0',
                                    ),
                                    _buildStatRow(
                                      'Total Courses',
                                      stats['courses']?.toString() ?? '0',
                                    ),
                                    _buildStatRow(
                                      'Total Files',
                                      stats['files']?.toString() ?? '0',
                                    ),
                                    _buildStatRow(
                                      'Active Enrollments',
                                      stats['enrollments']?.toString() ?? '0',
                                    ),
                                  ],
                                );
                              }
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Actions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Actions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            leading: const Icon(Icons.lock),
                            title: const Text('Change Password'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: _changePassword,
                          ),
                          ListTile(
                            leading: const Icon(Icons.settings),
                            title: const Text('System Settings'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              // TODO: Navigate to system settings
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.backup),
                            title: const Text('Database Backup'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              // TODO: Implement database backup
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.logout),
                            title: const Text('Logout'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () async {
                              await _authService.logout();
                              if (mounted) {
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed('/login');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Future<Map<String, int>> _getSystemStats() async {
    try {
      final db = await _databaseService.database;

      final userCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM users WHERE is_active = 1'),
          ) ??
          0;

      final courseCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM courses WHERE is_active = 1',
            ),
          ) ??
          0;

      final fileCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM files'),
          ) ??
          0;

      final enrollmentCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM enrollments WHERE status = "active"',
            ),
          ) ??
          0;

      return {
        'users': userCount,
        'courses': courseCount,
        'files': fileCount,
        'enrollments': enrollmentCount,
      };
    } catch (e) {
      debugPrint('Error getting system stats: $e');
      return {'users': 0, 'courses': 0, 'files': 0, 'enrollments': 0};
    }
  }
}
