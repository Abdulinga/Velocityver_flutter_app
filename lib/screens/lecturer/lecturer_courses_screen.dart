import 'package:flutter/material.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../widgets/course_card.dart';
import 'course_management_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LecturerCoursesScreen extends StatefulWidget {
  const LecturerCoursesScreen({super.key});

  @override
  State<LecturerCoursesScreen> createState() => _LecturerCoursesScreenState();
}

class _LecturerCoursesScreenState extends State<LecturerCoursesScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  List<Course> _assignedCourses = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAssignedCourses();
  }

  Future<void> _loadAssignedCourses() async {
  setState(() => _isLoading = true);

  try {
    final user = _authService.currentUser!;

    // ✅ Fetch courses assigned to this lecturer
    final response = await http.get(
      Uri.parse('http://192.168.1.155:5000/api/lecturers/${user.id}/courses'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      _assignedCourses = jsonList.map((c) => Course.fromJson(c)).toList();
    } else {
      debugPrint('❌ Failed to fetch lecturer courses: ${response.body}');
      _assignedCourses = [];
    }
  } catch (e) {
    debugPrint('⚠️ Error loading assigned courses: $e');
    _assignedCourses = [];
  } finally {
    setState(() => _isLoading = false);
  }
}

  List<Course> get _filteredCourses {
    if (_searchQuery.isEmpty) return _assignedCourses;

    return _assignedCourses.where((course) {
      return course.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          course.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          course.description?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ==
              true;
    }).toList();
  }

  void _manageCourse(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseManagementScreen(course: course),
      ),
    ).then((_) => _loadAssignedCourses());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAssignedCourses,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search courses...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Course statistics
          if (!_isLoading && _assignedCourses.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Total Courses',
                    _assignedCourses.length.toString(),
                    Icons.school,
                    Colors.deepPurple,
                  ),
                  _buildStatItem(
                    'Active',
                    _assignedCourses.where((c) => c.isActive).length.toString(),
                    Icons.play_circle,
                    Colors.green,
                  ),
                  _buildStatItem(
                    'Students',
                    '0', // TODO: Calculate total enrolled students
                    Icons.people,
                    Colors.blue,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Courses list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCourses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No courses assigned yet'
                              : 'No courses match your search',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Contact admin to get courses assigned'
                              : 'Try a different search term',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredCourses.length,
                    itemBuilder: (context, index) {
                      final course = _filteredCourses[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: CourseCard(
                          course: course,
                          onTap: () => _manageCourse(course),
                          trailing: IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () => _manageCourse(course),
                            tooltip: 'Manage Course',
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

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
