import 'package:flutter/material.dart';

import '../services/services.dart';
import '../models/models.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final FileService _fileService = FileService();
  final SyncService _syncService = SyncService();
  final ConnectivityService _connectivityService = ConnectivityService();

  Map<String, dynamic> _systemStats = {};
  List<SyncMetadata> _pendingSyncItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

 Future<void> _loadData() async {
  setState(() => _isLoading = true);

  try {
    // ✅ Call backend API for system stats
    final response = await http.get(
      Uri.parse('http://192.168.1.155:5000/admin/stats'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> statsJson = jsonDecode(response.body);

      _systemStats = {
        'totalUsers': statsJson['totalUsers'] ?? 0,
        'activeUsers': statsJson['activeUsers'] ?? 0,
        'students': statsJson['students'] ?? 0,
        'lecturers': statsJson['lecturers'] ?? 0,
        'admins': statsJson['admins'] ?? 0,
        'totalCourses': statsJson['totalCourses'] ?? 0,
        'activeCourses': statsJson['activeCourses'] ?? 0,
        'totalAnnouncements': statsJson['totalAnnouncements'] ?? 0,
        'activeAnnouncements': statsJson['activeAnnouncements'] ?? 0,
        'totalFiles': statsJson['totalFiles'] ?? 0,
        'syncedFiles': statsJson['syncedFiles'] ?? 0,
        'storageUsage': statsJson['storageUsage'] ?? {},
        'connectionInfo': statsJson['connectionInfo'] ?? {},
      };

    } else {
      debugPrint('❌ Failed to fetch system stats: ${response.statusCode}');
      _systemStats = {};
    }

    // ✅ Load pending sync items separately
    _pendingSyncItems = await _databaseService.getPendingSyncItems();

  } catch (e) {
    debugPrint('Error loading super admin data: $e');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Tab bar
        Container(
          color: Colors.grey[100],
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.deepPurple,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
              Tab(icon: Icon(Icons.sync), text: 'Sync Status'),
              Tab(icon: Icon(Icons.storage), text: 'Storage'),
              Tab(icon: Icon(Icons.settings), text: 'System'),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildAnalyticsTab(),
              _buildSyncTab(),
              _buildStorageTab(),
              _buildSystemTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    final user = _authService.currentUser!;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Text(
                        user.firstName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Super Admin Dashboard',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Full System Access',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.red[600]),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.security, color: Colors.red[700], size: 32),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // System health indicators
            Text(
              'System Health',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildHealthCard(
                    'Network',
                    _systemStats['connectionInfo']['isOnline']
                        ? 'Online'
                        : 'Offline',
                    _systemStats['connectionInfo']['isOnline']
                        ? Icons.wifi
                        : Icons.wifi_off,
                    _systemStats['connectionInfo']['isOnline']
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildHealthCard(
                    'Sync',
                    _pendingSyncItems.isEmpty
                        ? 'Up to date'
                        : '${_pendingSyncItems.length} pending',
                    _pendingSyncItems.isEmpty
                        ? Icons.check_circle
                        : Icons.sync_problem,
                    _pendingSyncItems.isEmpty ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick stats grid
            Text(
              'System Statistics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Total Users',
                  _systemStats['totalUsers'].toString(),
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Active Courses',
                  _systemStats['activeCourses'].toString(),
                  Icons.book,
                  Colors.green,
                ),
                _buildStatCard(
                  'Total Files',
                  _systemStats['totalFiles'].toString(),
                  Icons.folder,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Storage Used',
                  _systemStats['storageUsage']['formattedSize'],
                  Icons.storage,
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Critical actions
            Text(
              'Critical Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                _buildCriticalActionCard(
                  'Force Sync All Data',
                  'Synchronize all pending changes with server',
                  Icons.sync,
                  Colors.blue,
                  _forceSyncAll,
                ),
                _buildCriticalActionCard(
                  'Clean Storage',
                  'Remove orphaned files and optimize storage',
                  Icons.cleaning_services,
                  Colors.green,
                  _cleanStorage,
                ),
                _buildCriticalActionCard(
                  'Reset Database',
                  'WARNING: This will reset all local data',
                  Icons.restore,
                  Colors.red,
                  _resetDatabase,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Analytics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Students',
                    _systemStats['students'].toString(),
                    Icons.school,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Lecturers',
                    _systemStats['lecturers'].toString(),
                    Icons.person,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Admins',
                    _systemStats['admins'].toString(),
                    Icons.admin_panel_settings,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Active Users',
                    _systemStats['activeUsers'].toString(),
                    Icons.people,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              'Content Analytics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Courses',
                    _systemStats['totalCourses'].toString(),
                    Icons.book,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Announcements',
                    _systemStats['totalAnnouncements'].toString(),
                    Icons.announcement,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Sync controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _forceSyncAll,
                    icon: const Icon(Icons.sync),
                    label: const Text('Force Sync All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Pending Items',
                        _pendingSyncItems.length.toString(),
                        Icons.sync_problem,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Synced Files',
                        _systemStats['syncedFiles'].toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Pending sync items
          Expanded(
            child: _pendingSyncItems.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 64, color: Colors.green),
                        SizedBox(height: 16),
                        Text('All data is synchronized'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _pendingSyncItems.length,
                    itemBuilder: (context, index) {
                      final item = _pendingSyncItems[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            _getSyncActionIcon(item.action),
                            color: _getSyncActionColor(item.action),
                          ),
                          title: Text(
                            '${item.tableName} - ${item.action.name}',
                          ),
                          subtitle: Text('Record ID: ${item.recordId}'),
                          trailing: Text(
                            _formatDate(item.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageTab() {
    final storageInfo = _systemStats['storageUsage'];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Information',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Size',
                    storageInfo['formattedSize'],
                    Icons.storage,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'File Count',
                    storageInfo['fileCount'].toString(),
                    Icons.folder,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cleanStorage,
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Clean Storage'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Management',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Server settings removed - automatic discovery handles this
          _buildCriticalActionCard(
            'Export Data',
            'Export all system data for backup',
            Icons.download,
            Colors.blue,
            _exportData,
          ),
          _buildCriticalActionCard(
            'Import Data',
            'Import data from backup file',
            Icons.upload,
            Colors.green,
            _importData,
          ),
          _buildCriticalActionCard(
            'Reset Database',
            'WARNING: This will delete all data',
            Icons.restore,
            Colors.red,
            _resetDatabase,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCard(
    String title,
    String status,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            Text(
              status,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalActionCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  IconData _getSyncActionIcon(SyncAction action) {
    switch (action) {
      case SyncAction.create:
        return Icons.add;
      case SyncAction.update:
        return Icons.edit;
      case SyncAction.delete:
        return Icons.delete;
    }
  }

  Color _getSyncActionColor(SyncAction action) {
    switch (action) {
      case SyncAction.create:
        return Colors.green;
      case SyncAction.update:
        return Colors.blue;
      case SyncAction.delete:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _forceSyncAll() async {
    final success = await _syncService.performSync();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Sync completed successfully' : 'Sync failed',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) _loadData();
    }
  }

  Future<void> _cleanStorage() async {
    await _fileService.cleanupOrphanedFiles();
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage cleaned successfully')),
      );
    }
  }

  void _resetDatabase() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Database'),
        content: const Text(
          'This will delete ALL data. This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _databaseService.resetDatabase();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Database reset successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadData(); // Reload data after reset
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error resetting database: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    debugPrint('Export data');
  }

  void _importData() {
    debugPrint('Import data');
  }
}
