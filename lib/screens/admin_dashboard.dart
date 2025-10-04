import 'package:flutter/material.dart';

import '../services/services.dart';
import '../models/models.dart';
import 'admin/user_management_screen.dart';
import 'admin/course_management_screen.dart';
import 'admin/faculty_management_screen.dart';
import 'admin/course_registration_screen.dart';
import 'admin/enrollment_management_screen.dart';
import 'admin/admin_chat_screen.dart';
import 'admin/admin_profile_screen.dart';
import 'admin/system_overview_screen.dart';
import 'shared/create_announcement_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  // Data state
  Map<String, dynamic> _stats = {};
  List<User> _users = [];
  List<Course> _courses = [];
  List<Announcement> _announcements = [];
  List<Faculty> _faculties = [];
  List<Department> _departments = [];
  List<Level> _levels = [];
  List<Year> _years = [];

  // Loading and error state
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasLoadError = false;
      _errorMessage = null;
    });

    try {
      // Load all data concurrently for better performance
      final results = await Future.wait([
        _databaseService.getAdminStats(),
        _databaseService.getAllUsers(),
        _databaseService.getAllCourses(),
        _databaseService.getAllAnnouncements(),
        _databaseService.getAllFaculties(),
        _databaseService.getAllDepartments(),
        _databaseService.getAllLevels(),
        _databaseService.getAllYears(),
      ]);

      if (!mounted) return;

      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _users = results[1] as List<User>;
        _courses = results[2] as List<Course>;
        _announcements = results[3] as List<Announcement>;
        _faculties = results[4] as List<Faculty>;
        _departments = results[5] as List<Department>;
        _levels = results[6] as List<Level>;
        _years = results[7] as List<Year>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading admin data: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasLoadError = true;
        _errorMessage = 'Failed to load data: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabBar(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.grey[100],
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.deepPurple,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Colors.deepPurple,
        isScrollable: false,
        tabs: const [
          Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
          Tab(icon: Icon(Icons.people), text: 'Users'),
          Tab(icon: Icon(Icons.book), text: 'Courses'),
          Tab(icon: Icon(Icons.school), text: 'Academic'),
          Tab(icon: Icon(Icons.chat), text: 'Messages'),
          Tab(icon: Icon(Icons.announcement), text: 'Announcements'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasLoadError) {
      return _buildErrorState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildUsersTab(),
        _buildCoursesTab(),
        _buildAcademicTab(),
        _buildMessagesTab(),
        _buildAnnouncementsTab(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading admin dashboard...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error Loading Dashboard',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unexpected error occurred',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final user = _authService.currentUser;
    if (user == null) {
      return const Center(child: Text('User not authenticated'));
    }

    final statistics = _stats;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(user),
            const SizedBox(height: 16),
            _buildSystemStatistics(statistics),
            const SizedBox(height: 24),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(User user) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.deepPurple,
              radius: 24,
              child: Text(
                user.firstName.isNotEmpty
                    ? user.firstName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Dashboard',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'System Administration',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome, ${user.firstName} ${user.lastName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatistics(Map<String, dynamic> statistics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'System Statistics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _debugDatabase,
              icon: const Icon(Icons.bug_report),
              label: const Text('Debug DB'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatisticsGrid(statistics),
      ],
    );
  }

  Widget _buildStatisticsGrid(Map<String, dynamic> statistics) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          'Total Users',
          statistics['total_users']?.toString() ?? '0',
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'Faculties',
          statistics['total_faculties']?.toString() ?? '0',
          Icons.business,
          Colors.teal,
        ),
        _buildStatCard(
          'Departments',
          statistics['total_departments']?.toString() ?? '0',
          Icons.apartment,
          Colors.indigo,
        ),
        _buildStatCard(
          'Courses',
          statistics['total_courses']?.toString() ?? '0',
          Icons.book,
          Colors.purple,
        ),
        _buildStatCard(
          'Announcements',
          statistics['total_announcements']?.toString() ?? '0',
          Icons.announcement,
          Colors.orange,
        ),
        _buildStatCard(
          'Files',
          statistics['total_files']?.toString() ?? '0',
          Icons.insert_drive_file,
          Colors.red,
        ),
        _buildStatCard(
          'Levels',
          statistics['total_levels']?.toString() ?? '0',
          Icons.stairs,
          Colors.deepPurple,
        ),
        _buildStatCard(
          'Years',
          statistics['total_years']?.toString() ?? '0',
          Icons.calendar_today,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2,
          children: [
            _buildActionCard(
              'Manage Users',
              Icons.people,
              Colors.blue,
              _addUser,
            ),
            _buildActionCard(
              'Manage Courses',
              Icons.book,
              Colors.green,
              _addCourse,
            ),
            _buildActionCard(
              'Manage Faculties',
              Icons.account_balance,
              Colors.indigo,
              _manageFaculties,
            ),
            _buildActionCard(
              'Course Registration',
              Icons.app_registration,
              Colors.purple,
              _courseRegistration,
            ),
            _buildActionCard(
              'Create Announcement',
              Icons.announcement,
              Colors.orange,
              _createAnnouncement,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          _buildSectionHeader(
            title: 'User Management',
            buttonText: 'Add User',
            buttonIcon: Icons.person_add,
            onPressed: _addUser,
            buttonColor: Colors.deepPurple,
          ),
          Expanded(child: _buildUsersList()),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    if (_users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: user.isActive ? Colors.green : Colors.grey,
              child: Text(
                user.firstName.isNotEmpty
                    ? user.firstName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text('${user.firstName} ${user.lastName}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor(user.userRole).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getRoleColor(user.userRole).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        user.role?.name ?? 'Unknown Role',
                        style: TextStyle(
                          color: _getRoleColor(user.userRole),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!user.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: const Text(
                          'Inactive',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleUserAction(value, user),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset_password',
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset, size: 18),
                      SizedBox(width: 8),
                      Text('Reset Password'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: user.isActive ? 'deactivate' : 'activate',
                  child: Row(
                    children: [
                      Icon(
                        user.isActive ? Icons.block : Icons.check_circle,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(user.isActive ? 'Deactivate' : 'Activate'),
                    ],
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildCoursesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          _buildSectionHeader(
            title: 'Course Management',
            buttonText: 'Add Course',
            buttonIcon: Icons.add,
            onPressed: _addCourse,
            buttonColor: Colors.green,
          ),
          Expanded(child: _buildCoursesList()),
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    if (_courses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No courses found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: course.isActive ? Colors.blue : Colors.grey,
              child: Text(
                course.code.length >= 2
                    ? course.code.substring(0, 2).toUpperCase()
                    : course.code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              course.fullName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Code: ${course.code}'),
                const SizedBox(height: 2),
                Text(
                  course.description ?? 'No description',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!course.isActive) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Inactive',
                      style: TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleCourseAction(value, course),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'manage_students',
                  child: Row(
                    children: [
                      Icon(Icons.people, size: 18),
                      SizedBox(width: 8),
                      Text('Manage Students'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: course.isActive ? 'deactivate' : 'activate',
                  child: Row(
                    children: [
                      Icon(
                        course.isActive ? Icons.block : Icons.check_circle,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(course.isActive ? 'Deactivate' : 'Activate'),
                    ],
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          _buildSectionHeader(
            title: 'Announcements',
            buttonText: 'Create Announcement',
            buttonIcon: Icons.add,
            onPressed: _createAnnouncement,
            buttonColor: Colors.orange,
          ),
          Expanded(child: _buildAnnouncementsList()),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    if (_announcements.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.announcement_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No announcements found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _announcements.length,
      itemBuilder: (context, index) {
        final announcement = _announcements[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: announcement.isActive
                  ? Colors.orange
                  : Colors.grey,
              child: const Icon(Icons.announcement, color: Colors.white),
            ),
            title: Text(
              announcement.title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!announcement.isActive) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Inactive',
                      style: TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) =>
                  _handleAnnouncementAction(value, announcement),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: announcement.isActive ? 'deactivate' : 'activate',
                  child: Row(
                    children: [
                      Icon(
                        announcement.isActive
                            ? Icons.block
                            : Icons.check_circle,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(announcement.isActive ? 'Deactivate' : 'Activate'),
                    ],
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String buttonText,
    required IconData buttonIcon,
    required VoidCallback onPressed,
    required Color buttonColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(buttonIcon),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
            ),
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
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Utility methods
  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Colors.blue;
      case UserRole.lecturer:
        return Colors.green;
      case UserRole.admin:
        return Colors.orange;
      case UserRole.superAdmin:
        return Colors.red;
    }
  }

  Future<void> _debugDatabase() async {
    try {
      await _databaseService.debugDatabaseContents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debug info printed to console'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Navigation methods (preserved as required)
  void _addUser() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserManagementScreen()),
    );
  }

  void _addCourse() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CourseManagementScreen()),
    );
  }

  void _createAnnouncement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateAnnouncementScreen()),
    );
  }

  void _manageFaculties() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FacultyManagementScreen()),
    );
  }

  void _courseRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CourseRegistrationScreen()),
    );
  }

  // Action handlers (preserved as required)
  void _handleUserAction(String action, User user) {
    debugPrint('User action: $action for ${user.username}');
    // TODO: Implement user actions
  }

  void _handleCourseAction(String action, Course course) {
    debugPrint('Course action: $action for ${course.code}');
    // TODO: Implement course actions
  }

  void _handleAnnouncementAction(String action, Announcement announcement) {
    debugPrint('Announcement action: $action for ${announcement.title}');
    // TODO: Implement announcement actions
  }

  // Academic tab and related methods (preserved as required)
  Widget _buildAcademicTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey[50],
            child: const TabBar(
              labelColor: Colors.deepPurple,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.deepPurple,
              tabs: [
                Tab(icon: Icon(Icons.account_balance), text: 'Faculties'),
                Tab(icon: Icon(Icons.business), text: 'Departments'),
                Tab(icon: Icon(Icons.stairs), text: 'Levels & Years'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFacultiesSubTab(),
                _buildDepartmentsSubTab(),
                _buildLevelsSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    return const AdminChatScreen();
  }

  Widget _buildFacultiesSubTab() {
    return Column(
      children: [
        _buildSubSectionHeader(
          title: 'Faculties',
          buttonText: 'Add Faculty',
          onPressed: _showCreateFacultyDialog,
        ),
        Expanded(child: _buildFacultiesList()),
      ],
    );
  }

  Widget _buildFacultiesList() {
    if (_faculties.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No faculties found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _faculties.length,
      itemBuilder: (context, index) {
        final faculty = _faculties[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: Text(
                faculty.code.isNotEmpty ? faculty.code : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            title: Text(
              faculty.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              faculty.description ?? 'No description',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleFacultyAction(value, faculty.id),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDepartmentsSubTab() {
    return Column(
      children: [
        _buildSubSectionHeader(
          title: 'Departments',
          buttonText: 'Add Department',
          onPressed: _showCreateDepartmentDialog,
        ),
        Expanded(child: _buildDepartmentsList()),
      ],
    );
  }

  Widget _buildDepartmentsList() {
    if (_departments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No departments found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _departments.length,
      itemBuilder: (context, index) {
        final department = _departments[index];
        final faculty = _faculties.firstWhere(
          (f) => f.id == department.facultyId,
          orElse: () => Faculty(
            id: '',
            name: 'Unknown Faculty',
            code: 'UNK',
            description: '',
          ),
        );
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Text(
                department.code.isNotEmpty ? department.code : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            title: Text(
              department.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text('Faculty: ${faculty.name}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) =>
                  _handleDepartmentAction(value, department.id),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLevelsSubTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.grey[50],
            child: const TabBar(
              labelColor: Colors.deepPurple,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'Levels'),
                Tab(text: 'Years'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [_buildLevelsManagement(), _buildYearsManagement()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelsManagement() {
    return Column(
      children: [
        _buildSubSectionHeader(
          title: 'Academic Levels',
          buttonText: 'Add Level',
          onPressed: _showCreateLevelDialog,
        ),
        Expanded(
          child: _levels.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stairs_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No levels found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _levels.length,
                  itemBuilder: (context, index) {
                    final level = _levels[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Icon(Icons.stairs, color: Colors.white),
                        ),
                        title: Text(
                          level.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(level.description ?? 'No description'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) =>
                              _handleLevelAction(value, level.id),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildYearsManagement() {
    return Column(
      children: [
        _buildSubSectionHeader(
          title: 'Academic Years',
          buttonText: 'Add Year',
          onPressed: _showCreateYearDialog,
        ),
        Expanded(
          child: _years.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No years found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _years.length,
                  itemBuilder: (context, index) {
                    final year = _years[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          year.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(year.description ?? 'No description'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) =>
                              _handleYearAction(value, year.id),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSubSectionHeader({
    required String title,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[25],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Dialog methods (preserved as required)
  void _showCreateFacultyDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Faculty'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Faculty Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Faculty Code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement faculty creation
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateDepartmentDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedFacultyId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Department'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Department Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Department Code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedFacultyId,
                decoration: const InputDecoration(
                  labelText: 'Faculty',
                  border: OutlineInputBorder(),
                ),
                items: _faculties.map((faculty) {
                  return DropdownMenuItem(
                    value: faculty.id,
                    child: Text(faculty.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedFacultyId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement department creation
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateLevelDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Level'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Level Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement level creation
              Navigator.pop(context);
            },
            child: const Text('Create'), // ✅ required child argument
          ),
        ],
      ),
    );
  }

  void _showCreateYearDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Year'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Year Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement year creation
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // Action handlers (preserved as required)
  void _handleFacultyAction(String action, String facultyId) {
    debugPrint('Faculty action: $action for faculty $facultyId');
    // TODO: Implement faculty actions (edit, delete)
  }

  void _handleDepartmentAction(String action, String departmentId) {
    debugPrint('Department action: $action for department $departmentId');
    // TODO: Implement department actions (edit, delete)
  }

  void _handleLevelAction(String action, String levelId) {
    debugPrint('Level action: $action for level $levelId');
    // TODO: Implement level actions (edit, delete)
  }

  void _handleYearAction(String action, String yearId) {
    debugPrint('Year action: $action for year $yearId');
    // TODO: Implement year actions (edit, delete)
  }
}
