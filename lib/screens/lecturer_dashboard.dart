import 'package:flutter/material.dart';

import '../services/services.dart';
import '../models/models.dart';
import '../widgets/course_card.dart';
import '../widgets/announcement_card.dart';
import '../widgets/file_list_item.dart';
import 'lecturer/lecturer_courses_screen.dart';
import 'lecturer/lecturer_files_screen.dart';
import 'lecturer/lecturer_chat_screen.dart';
import 'lecturer/lecturer_profile_screen.dart';
import 'lecturer/course_management_screen.dart';
import 'lecturer/file_upload_screen.dart';
import 'shared/create_announcement_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LecturerDashboard extends StatefulWidget {
  const LecturerDashboard({super.key});

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final FileService _fileService = FileService();

  List<Course> _courses = [];
  List<Announcement> _announcements = [];
  List<FileModel> _myFiles = [];
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
    final user = _authService.currentUser!;
    final userId = user.id;

    // Fetch lecturer's courses
    final coursesResponse = await http.get(
      Uri.parse('http://192.168.1.155:5000/api/lecturer/$userId/courses'),
    );
    if (coursesResponse.statusCode == 200) {
      final List<dynamic> coursesJson = jsonDecode(coursesResponse.body);
      _courses = coursesJson.map((c) => Course.fromJson(c)).toList();
    } else {
      _courses = [];
      debugPrint('❌ Failed to fetch courses: ${coursesResponse.statusCode}');
    }

    // Fetch announcements
    final announcementsResponse = await http.get(
      Uri.parse('http://192.168.1.155:5000/api/lecturer/$userId/announcements'),
    );
    if (announcementsResponse.statusCode == 200) {
      final List<dynamic> annJson = jsonDecode(announcementsResponse.body);
      _announcements = annJson.map((a) => Announcement.fromJson(a)).toList();
    } else {
      _announcements = [];
      debugPrint('❌ Failed to fetch announcements: ${announcementsResponse.statusCode}');
    }

    // Fetch lecturer's uploaded files
    final filesResponse = await http.get(
      Uri.parse('http://192.168.1.155:5000/api/lecturer/$userId/files'),
    );
    if (filesResponse.statusCode == 200) {
      final List<dynamic> filesJson = jsonDecode(filesResponse.body);
      _myFiles = filesJson.map((f) => FileModel.fromJson(f)).toList();
    } else {
      _myFiles = [];
      debugPrint('❌ Failed to fetch files: ${filesResponse.statusCode}');
    }

  } catch (e) {
    debugPrint('Error loading lecturer data: $e');
    _courses = [];
    _announcements = [];
    _myFiles = [];
  } finally {
    if (mounted) setState(() => _isLoading = false);
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
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.book), text: 'My Courses'),
              Tab(icon: Icon(Icons.upload_file), text: 'My Files'),
              Tab(icon: Icon(Icons.chat), text: 'Messages'),
              Tab(icon: Icon(Icons.announcement), text: 'Announcements'),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildCoursesTab(),
              _buildFilesTab(),
              _buildMessagesTab(),
              _buildAnnouncementsTab(),
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.deepPurple,
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
                                'Welcome, Dr. ${user.lastName}!',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                'Lecturer Dashboard',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'My Courses',
                    _courses.length.toString(),
                    Icons.book,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Uploaded Files',
                    _myFiles.length.toString(),
                    Icons.upload_file,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Announcements',
                    _announcements.length.toString(),
                    Icons.announcement,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick actions
            Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Upload File',
                    Icons.upload_file,
                    Colors.blue,
                    _uploadFile,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionCard(
                    'Create Announcement',
                    Icons.announcement,
                    Colors.orange,
                    _createAnnouncement,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent files
            if (_myFiles.isNotEmpty) ...[
              Text(
                'Recent Uploads',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(_myFiles
                  .take(5)
                  .map(
                    (file) => FileListItem(
                      file: file,
                      onTap: () => _openFile(file),
                      showActions: true,
                      onDelete: () => _deleteFile(file),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Add course button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addCourse,
                icon: const Icon(Icons.add),
                label: const Text('Add Course'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),

          // Courses list
          Expanded(
            child: _courses.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No courses assigned'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _courses.length,
                    itemBuilder: (context, index) {
                      return CourseCard(
                        course: _courses[index],
                        onTap: () => _manageCourse(_courses[index]),
                        showManageButton: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Upload file button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploadFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),

          // Files list
          Expanded(
            child: _myFiles.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No files uploaded'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _myFiles.length,
                    itemBuilder: (context, index) {
                      return FileListItem(
                        file: _myFiles[index],
                        onTap: () => _openFile(_myFiles[index]),
                        showActions: true,
                        onDelete: () => _deleteFile(_myFiles[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Create announcement button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createAnnouncement,
                icon: const Icon(Icons.add),
                label: const Text('Create Announcement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),

          // Announcements list
          Expanded(
            child: _announcements.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.announcement, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No announcements'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _announcements.length,
                    itemBuilder: (context, index) {
                      return AnnouncementCard(
                        announcement: _announcements[index],
                        showActions: true,
                      );
                    },
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
            Text(title, style: Theme.of(context).textTheme.bodySmall),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addCourse() {
    // Navigate to add course screen
    print('Add course');
  }

  void _manageCourse(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseManagementScreen(course: course),
      ),
    );
  }

  void _uploadFile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FileUploadScreen()),
    );
  }

  void _createAnnouncement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateAnnouncementScreen()),
    );
  }

  Future<void> _openFile(FileModel file) async {
    final success = await _fileService.openFile(file);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open file'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteFile(FileModel file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text(
          'Are you sure you want to delete "${file.originalName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _fileService.deleteFile(file);
      if (success) {
        _loadData(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File deleted successfully')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMessagesTab() {
    return const LecturerChatScreen();
  }
}
