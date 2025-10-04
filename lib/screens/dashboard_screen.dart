import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/services.dart';
import '../models/models.dart';
import '../widgets/server_status_widget.dart';
import 'student_dashboard.dart';
import 'lecturer_dashboard.dart';
import 'admin_dashboard.dart';
import 'super_admin_dashboard.dart';
import 'login_screen.dart';
import 'student/student_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _connectivityService.initialize();
    _syncService.startAutoSync();
  }

  Widget _buildRoleBasedDashboard(User user) {
    switch (user.userRole) {
      case UserRole.student:
        return const StudentDashboard();
      case UserRole.lecturer:
        return const LecturerDashboard();
      case UserRole.admin:
        return const AdminDashboard();
      case UserRole.superAdmin:
        return const SuperAdminDashboard();
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _performSync() async {
    if (!_connectivityService.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot sync: No internet connection'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
    }
  }

  void _navigateToProfile() {
    final user = _authService.currentUser;
    if (user == null) return;

    switch (user.userRole) {
      case UserRole.student:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StudentProfileScreen()),
        );
        break;
      case UserRole.lecturer:
      case UserRole.admin:
      case UserRole.superAdmin:
        // For now, show a simple dialog. In a full implementation,
        // you would create profile screens for each role
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${user.role?.name} Profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: ${user.fullName}'),
                Text('Email: ${user.email}'),
                Text('Username: ${user.username}'),
                Text('Role: ${user.role?.name ?? 'Unknown'}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${user.firstName}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: ServerStatusWidget(),
        ),
        actions: [
          // Sync button
          Consumer<ConnectivityService>(
            builder: (context, connectivity, child) {
              return IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.sync),
                    if (_syncService.isSyncing)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: connectivity.isOnline ? _performSync : null,
                tooltip: connectivity.isOnline
                    ? 'Sync with server'
                    : 'Offline - Cannot sync',
              );
            },
          ),

          // Network status indicator
          Consumer<ConnectivityService>(
            builder: (context, connectivity, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(
                  connectivity.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: connectivity.isOnline ? Colors.green : Colors.orange,
                ),
              );
            },
          ),

          // User menu
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user.firstName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _navigateToProfile();
                  break;
                case 'settings':
                  // Navigate to settings screen
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person),
                    const SizedBox(width: 8),
                    Text('Profile (${user.role?.name ?? 'Unknown'})'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildRoleBasedDashboard(user),

      // Bottom status bar
      bottomNavigationBar: Consumer<ConnectivityService>(
        builder: (context, connectivity, child) {
          if (connectivity.isOnline) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.orange[100],
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Working offline - Changes will sync when connection is restored',
                    style: TextStyle(color: Colors.orange[700], fontSize: 12),
                  ),
                ),
                if (_syncService.lastSyncTime != null)
                  Text(
                    'Last sync: ${_formatLastSync(_syncService.lastSyncTime!)}',
                    style: TextStyle(color: Colors.orange[700], fontSize: 10),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
