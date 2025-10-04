import 'package:flutter/material.dart';
import '../services/services.dart';
import '../models/models.dart';
import '../widgets/course_card.dart';
import '../widgets/file_list_item.dart';
import 'student/student_downloads_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final FileService _fileService = FileService();

  List<Course> _courses = [];
  List<FileModel> _recentFiles = [];
  Map<String, List<FileModel>> _courseFilesMap = {};
  bool _isLoading = true;
  String? _errorMessage;
  String? _rawFilesResponse;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

      // Fetch enrolled courses
      final coursesResponse = await http.get(
        Uri.parse('http://192.168.1.155:5000/api/student/$userId/courses'),
      );

      if (coursesResponse.statusCode == 200) {
        final List<dynamic> coursesJson = jsonDecode(coursesResponse.body);
        _courses = coursesJson.map((c) => Course.fromJson(c)).toList();
      } else {
        _courses = [];
        debugPrint('❌ Failed to fetch courses: ${coursesResponse.statusCode}');
      }

      // Fetch all files
      final filesResponse = await http.get(
        Uri.parse('http://192.168.1.155:5000/api/files/all'),
      );

      _rawFilesResponse = filesResponse.body;

      if (filesResponse.statusCode == 200) {
        final List<dynamic> allFilesJson = jsonDecode(filesResponse.body);

        // Filter files for enrolled courses
        final enrolledCourseIds = _courses.map((c) => c.id.toString()).toSet();

        _recentFiles = allFilesJson.where((f) {
          final courseId = f['course_id']?.toString() ?? '';
          return enrolledCourseIds.contains(courseId);
        }).map((f) {
          return FileModel(
            id: f['id'] ?? 'unknown',
            name: f['name'] ?? 'unknown',
            path: f['file_path'] ?? '',
            uploadedBy: f['uploaded_by'] ?? 'system',
            size: f['file_size'] ?? 0,
            mimeType: f['mime_type'] ?? 'application/octet-stream',
            courseId: f['course_id']?.toString() ?? 'unknown',
          );
        }).toList();

        // Map files to courses
        _courseFilesMap.clear();
        for (var file in _recentFiles) {
         _courseFilesMap.putIfAbsent(file.courseId ?? 'unknown', () => []).add(file);
        }

        // Sort latest 10 files for overview
        _recentFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _recentFiles = _recentFiles.take(10).toList();
      } else {
        _recentFiles = [];
        debugPrint('❌ Failed to fetch files: ${filesResponse.statusCode}');
      }
    } catch (e) {
      _errorMessage = 'Error loading dashboard: $e';
      debugPrint(_errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFilesDebugDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Files API Debug Info'),
        content: SingleChildScrollView(
          child: Text(_rawFilesResponse ?? 'No response captured'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
              Tab(icon: Icon(Icons.book), text: 'Courses'),
              Tab(icon: Icon(Icons.download), text: 'Downloads'),
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
              _buildDownloadsTab(),
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
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Text(user.firstName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back, ${user.firstName}!',
                              style: Theme.of(context).textTheme.titleLarge),
                          if (user.level != null && user.year != null)
                            Text('${user.level!.name} - ${user.year!.name}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.bug_report),
                      onPressed: _showFilesDebugDialog,
                      tooltip: 'Show files API debug',
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
                    'Courses',
                    _courses.length.toString(),
                    Icons.book,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Files',
                    _recentFiles.length.toString(),
                    Icons.folder,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent files
            if (_recentFiles.isNotEmpty) ...[
              Text(
                'Recent Files',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(_recentFiles.take(5).map(
                (file) => FileListItem(
                  file: file,
                  onTap: () => _openFile(file),
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
      child: _courses.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No courses enrolled'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _courses.length,
              itemBuilder: (context, index) {
                final course = _courses[index];
                final courseFiles = _courseFilesMap[course.id.toString()] ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    title: Text(course.name),
                    subtitle: Text('${courseFiles.length} file(s)'),
                    children: courseFiles.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No files available for this course'),
                            )
                          ]
                        : courseFiles.map((file) {
                            return FileListItem(
                              file: file,
                              onTap: () => _openFile(file),
                            );
                          }).toList(),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDownloadsTab() {
    return const StudentDownloadsScreen();
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
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
}
