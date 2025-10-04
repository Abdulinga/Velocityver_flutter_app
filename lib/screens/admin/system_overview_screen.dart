import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


class SystemOverviewScreen extends StatefulWidget {
  const SystemOverviewScreen({super.key});

  @override
  State<SystemOverviewScreen> createState() => _SystemOverviewScreenState();
}

class _SystemOverviewScreenState extends State<SystemOverviewScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();

  Map<String, dynamic> _systemStats = {};
  bool _isLoading = true;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadSystemData();
  }

  Future<void> _loadSystemData() async {
    setState(() => _isLoading = true);

    try {
      // Check connectivity
      _isOnline = _connectivityService.isOnline;

      // Load system statistics
      _systemStats = await _getDetailedSystemStats();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading system data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> _getDetailedSystemStats() async {
    try {
      final db = await _databaseService.database;

      // User statistics
      final totalUsers =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM users'),
          ) ??
          0;

      final activeUsers =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM users WHERE is_active = 1'),
          ) ??
          0;

      final students =
          Sqflite.firstIntValue(
            await db.rawQuery('''
          SELECT COUNT(*) FROM users u 
          INNER JOIN roles r ON u.role_id = r.id 
          WHERE r.name = 'student' AND u.is_active = 1
        '''),
          ) ??
          0;

      final lecturers =
          Sqflite.firstIntValue(
            await db.rawQuery('''
          SELECT COUNT(*) FROM users u 
          INNER JOIN roles r ON u.role_id = r.id 
          WHERE r.name = 'lecturer' AND u.is_active = 1
        '''),
          ) ??
          0;

      final admins =
          Sqflite.firstIntValue(
            await db.rawQuery('''
          SELECT COUNT(*) FROM users u 
          INNER JOIN roles r ON u.role_id = r.id 
          WHERE r.name IN ('admin', 'super_admin') AND u.is_active = 1
        '''),
          ) ??
          0;

      // Course statistics
      final totalCourses =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM courses'),
          ) ??
          0;

      final activeCourses =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM courses WHERE is_active = 1',
            ),
          ) ??
          0;

      // File statistics
      final totalFiles =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM files'),
          ) ??
          0;

      final totalFileSize =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT SUM(size) FROM files'),
          ) ??
          0;

      // Enrollment statistics
      final totalEnrollments =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM enrollments'),
          ) ??
          0;

      final activeEnrollments =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM enrollments WHERE status = "active"',
            ),
          ) ??
          0;

      // Chat statistics
      final totalChatRooms =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM chat_rooms WHERE is_active = 1',
            ),
          ) ??
          0;

      final totalMessages =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM messages'),
          ) ??
          0;

      return {
        'users': {
          'total': totalUsers,
          'active': activeUsers,
          'students': students,
          'lecturers': lecturers,
          'admins': admins,
        },
        'courses': {'total': totalCourses, 'active': activeCourses},
        'files': {'total': totalFiles, 'totalSize': totalFileSize},
        'enrollments': {'total': totalEnrollments, 'active': activeEnrollments},
        'chat': {'rooms': totalChatRooms, 'messages': totalMessages},
      };
    } catch (e) {
      debugPrint('Error getting detailed system stats: $e');
      return {};
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Overview'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSystemData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // System status
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'System Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                _isOnline ? Icons.cloud_done : Icons.cloud_off,
                                color: _isOnline ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  color: _isOnline ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Database: SQLite (Local)',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text(
                            'Last Updated: ${DateTime.now().toString().substring(0, 19)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User statistics
                  if (_systemStats['users'] != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'User Statistics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildStatGrid([
                              _StatItem(
                                'Total Users',
                                _systemStats['users']['total'].toString(),
                                Icons.people,
                              ),
                              _StatItem(
                                'Active Users',
                                _systemStats['users']['active'].toString(),
                                Icons.person,
                              ),
                              _StatItem(
                                'Students',
                                _systemStats['users']['students'].toString(),
                                Icons.school,
                              ),
                              _StatItem(
                                'Lecturers',
                                _systemStats['users']['lecturers'].toString(),
                                Icons.person_outline,
                              ),
                              _StatItem(
                                'Admins',
                                _systemStats['users']['admins'].toString(),
                                Icons.admin_panel_settings,
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Course statistics
                  if (_systemStats['courses'] != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Course Statistics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildStatGrid([
                              _StatItem(
                                'Total Courses',
                                _systemStats['courses']['total'].toString(),
                                Icons.book,
                              ),
                              _StatItem(
                                'Active Courses',
                                _systemStats['courses']['active'].toString(),
                                Icons.book_online,
                              ),
                              _StatItem(
                                'Total Enrollments',
                                _systemStats['enrollments']['total'].toString(),
                                Icons.assignment,
                              ),
                              _StatItem(
                                'Active Enrollments',
                                _systemStats['enrollments']['active']
                                    .toString(),
                                Icons.assignment_turned_in,
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // File statistics
                  if (_systemStats['files'] != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'File Statistics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildStatGrid([
                              _StatItem(
                                'Total Files',
                                _systemStats['files']['total'].toString(),
                                Icons.folder,
                              ),
                              _StatItem(
                                'Total Size',
                                _formatFileSize(
                                  _systemStats['files']['totalSize'],
                                ),
                                Icons.storage,
                              ),
                              _StatItem(
                                'Chat Rooms',
                                _systemStats['chat']['rooms'].toString(),
                                Icons.chat,
                              ),
                              _StatItem(
                                'Messages',
                                _systemStats['chat']['messages'].toString(),
                                Icons.message,
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Quick actions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildActionButton(
                                'Backup Database',
                                Icons.backup,
                                () {
                                  // TODO: Implement database backup
                                },
                              ),
                              _buildActionButton(
                                'Export Data',
                                Icons.download,
                                () {
                                  // TODO: Implement data export
                                },
                              ),
                              _buildActionButton(
                                'System Logs',
                                Icons.list_alt,
                                () {
                                  // TODO: Show system logs
                                },
                              ),
                              _buildActionButton(
                                'Clear Cache',
                                Icons.clear_all,
                                () {
                                  // TODO: Clear cache
                                },
                              ),
                            ],
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

  Widget _buildStatGrid(List<_StatItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: Colors.deepPurple),
              const SizedBox(height: 4),
              Text(
                item.value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                item.label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple.shade50,
        foregroundColor: Colors.deepPurple,
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;

  _StatItem(this.label, this.value, this.icon);
}
