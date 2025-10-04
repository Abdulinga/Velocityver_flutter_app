import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/file_list_item.dart';
import 'file_upload_screen.dart';

class CourseManagementScreen extends StatefulWidget {
  final Course course;

  const CourseManagementScreen({super.key, required this.course});

  @override
  State<CourseManagementScreen> createState() => _CourseManagementScreenState();
}

class _CourseManagementScreenState extends State<CourseManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FileService _fileService = FileService();
  final DatabaseService _databaseService = DatabaseService();

  List<Map<String, dynamic>> _files = []; // ✅ raw JSON objects instead of FileModel
  List<User> _enrolledStudents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCourseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourseData() async {
    setState(() => _isLoading = true);

    try {
      final courseId = widget.course.id;

      // ✅ Fetch files directly from folder
      final filesResponse = await http.get(
        Uri.parse(
            'http://192.168.1.155:5000/api/courses/$courseId/folder-files'),
      );

      if (filesResponse.statusCode == 200) {
        final List<dynamic> filesJson = jsonDecode(filesResponse.body);
        _files = filesJson.cast<Map<String, dynamic>>();
      } else {
        debugPrint('❌ Failed to fetch course files: ${filesResponse.body}');
        _files = [];
      }

      // Fetch enrolled students (kept as is)
      final studentsResponse = await http.get(
        Uri.parse('http://192.168.1.155:5000/api/courses/$courseId/students'),
      );

      if (studentsResponse.statusCode == 200) {
        final List<dynamic> studentsJson = jsonDecode(studentsResponse.body);
        _enrolledStudents = studentsJson.map((s) => User.fromJson(s)).toList();
      } else {
        debugPrint(
            '❌ Failed to fetch enrolled students: ${studentsResponse.body}');
        _enrolledStudents = [];
      }
    } catch (e) {
      debugPrint('⚠️ Error loading course data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Overview'),
            Tab(icon: Icon(Icons.folder), text: 'Files'),
            Tab(icon: Icon(Icons.people), text: 'Students'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildFilesTab(),
                _buildStudentsTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _uploadFiles,
              backgroundColor: Colors.green,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Files'),
            )
          : null,
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadCourseData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.course.code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          widget.course.isActive
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: widget.course.isActive
                              ? Colors.green
                              : Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.course.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (widget.course.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.course.description!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quick stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Files',
                    _files.length.toString(),
                    Icons.folder,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Students',
                    _enrolledStudents.length.toString(),
                    Icons.people,
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

  Widget _buildFilesTab() {
    return RefreshIndicator(
      onRefresh: _loadCourseData,
      child: _files.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No files in course folder'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                return FileListItem(
                  fileName: file['name'], // ✅ pass plain filename
                  fileSize: file['file_size'],
                  onTap: () =>
                      _downloadFile(file), // download on tap for simplicity
                );
              },
            ),
    );
  }

  Widget _buildStudentsTab() {
    return RefreshIndicator(
      onRefresh: _loadCourseData,
      child: _enrolledStudents.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No students enrolled'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _enrolledStudents.length,
              itemBuilder: (context, index) {
                final student = _enrolledStudents[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        student.firstName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(student.fullName),
                    subtitle: Text(student.email),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
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

  Future<void> _uploadFiles() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileUploadScreen(selectedCourse: widget.course),
      ),
    );
    _loadCourseData(); // Refresh
  }

  Future<void> _downloadFile(Map<String, dynamic> file) async {
    final url = "http://192.168.1.155:5000${file['download_url']}";
    final success = await _fileService.downloadFileFromUrl(url, file['name']);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'File downloaded: ${file['name']}'
              : 'Download failed'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
