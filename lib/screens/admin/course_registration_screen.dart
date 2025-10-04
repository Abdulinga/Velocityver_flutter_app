import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CourseRegistrationScreen extends StatefulWidget {
  const CourseRegistrationScreen({super.key});

  @override
  State<CourseRegistrationScreen> createState() => _CourseRegistrationScreenState();
}

class _CourseRegistrationScreenState extends State<CourseRegistrationScreen> {
  final DatabaseService _databaseService = DatabaseService();

  List<Course> _courses = [];
  List<User> _students = [];
  String? _selectedCourseId;

  bool _isLoading = true;
  bool _isRegistering = false;
  List<String> _selectedStudentIds = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('http://192.168.1.155:5000/api/courses')),
        http.get(Uri.parse('http://192.168.1.155:5000/api/users')),
      ]);

      if (responses[0].statusCode == 200) {
        final data = jsonDecode(responses[0].body);
        final List<dynamic> items = data['items'] ?? [];
        _courses = items.map((c) => Course.fromJson(c)).toList();
      }

      if (responses[1].statusCode == 200) {
        final data = jsonDecode(responses[1].body);
        final List<dynamic> items = data['items'] ?? [];
        final allUsers = items.map((u) => User.fromJson(u)).toList();
        _students = allUsers.where((u) => u.userRole == UserRole.student).toList();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _canRegister() {
    return _selectedCourseId != null && _selectedStudentIds.isNotEmpty && !_isRegistering;
  }

  void _selectAllStudents() {
    setState(() {
      _selectedStudentIds = _students.map((s) => s.id).toList();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedStudentIds.clear();
    });
  }

  Future<void> _registerStudents() async {
    if (!_canRegister()) return;

    setState(() => _isRegistering = true);

    try {
      int successCount = 0;
      int errorCount = 0;

      for (String studentId in _selectedStudentIds) {
        try {
          await _databaseService.enrollUserInCourse(studentId, _selectedCourseId!);
          successCount++;
        } catch (e) {
          errorCount++;
          debugPrint('Error enrolling student $studentId: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Registration completed: $successCount successful, $errorCount failed',
            ),
            backgroundColor: errorCount == 0 ? Colors.green : Colors.orange,
          ),
        );
        setState(() => _selectedStudentIds.clear());
      }
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Registration'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course selection
                  Text(
                    'Select Course',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCourseId,
                    decoration: const InputDecoration(
                      labelText: 'Course',
                      border: OutlineInputBorder(),
                    ),
                    items: _courses.map((course) {
                      return DropdownMenuItem(
                        value: course.id,
                        child: Text('${course.code} - ${course.name}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCourseId = value);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Student list
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Students (${_students.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _selectAllStudents,
                            child: const Text('Select All'),
                          ),
                          TextButton(
                            onPressed: _clearSelection,
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _students.isEmpty
                        ? const Center(
                            child: Text('No students found'),
                          )
                        : ListView.builder(
                            itemCount: _students.length,
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              final isSelected = _selectedStudentIds.contains(student.id);

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedStudentIds.add(student.id);
                                    } else {
                                      _selectedStudentIds.remove(student.id);
                                    }
                                  });
                                },
                                title: Text(student.fullName),
                                subtitle: Text(student.email),
                                secondary: CircleAvatar(
                                  backgroundColor: Colors.purple,
                                  child: Text(
                                    student.firstName[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Register button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canRegister() ? _registerStudents : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isRegistering
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Register ${_selectedStudentIds.length} Students',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
