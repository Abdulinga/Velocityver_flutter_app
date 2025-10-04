import 'package:flutter/material.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


class EnrollmentManagementScreen extends StatefulWidget {
  const EnrollmentManagementScreen({super.key});

  @override
  State<EnrollmentManagementScreen> createState() => _EnrollmentManagementScreenState();
}

class _EnrollmentManagementScreenState extends State<EnrollmentManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  
  List<Course> _courses = [];
  List<Faculty> _faculties = [];
  List<Department> _departments = [];
  List<Year> _years = [];
  List<User> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    // --- Courses ---
    try {
      final response =
          await http.get(Uri.parse('http://192.168.1.155:5000/api/courses'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> items =
            body is List ? body : (body['items'] ?? []);
        _courses = items.map((c) => Course.fromJson(c)).toList();

        for (final c in _courses) {
          await _databaseService.insertCourse(c);
        }
      } else {
        _courses = await _databaseService.getAllCourses();
      }
    } catch (_) {
      _courses = await _databaseService.getAllCourses();
    }

    // --- Faculties ---
    try {
      final response =
          await http.get(Uri.parse('http://192.168.1.155:5000/api/faculties'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> items =
            body is List ? body : (body['items'] ?? []);
        _faculties = items.map((f) => Faculty.fromJson(f)).toList();

        for (final f in _faculties) {
          await _databaseService.insertFaculty(f);
        }
      } else {
        _faculties = await _databaseService.getAllFaculties();
      }
    } catch (_) {
      _faculties = await _databaseService.getAllFaculties();
    }

    // --- Departments ---
    try {
      final response = await http
          .get(Uri.parse('http://192.168.1.155:5000/api/departments'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> items =
            body is List ? body : (body['items'] ?? []);
        _departments = items.map((d) => Department.fromJson(d)).toList();

        for (final d in _departments) {
          await _databaseService.insertDepartment(d);
        }
      } else {
        _departments = await _databaseService.getAllDepartments();
      }
    } catch (_) {
      _departments = await _databaseService.getAllDepartments();
    }

    // --- Years ---
    try {
      final response =
          await http.get(Uri.parse('http://192.168.1.155:5000/api/years'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> items =
            body is List ? body : (body['items'] ?? []);
        _years = items.map((y) => Year.fromJson(y)).toList();

        for (final y in _years) {
          await _databaseService.insertYear(y);
        }
      } else {
        _years = await _databaseService.getAllYears();
      }
    } catch (_) {
      _years = await _databaseService.getAllYears();
    }

    // --- Students ---
    try {
      final response = await http
          .get(Uri.parse('http://192.168.1.155:5000/api/users?role=student'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> items =
            body is List ? body : (body['items'] ?? []);
        _students = items.map((s) => User.fromJson(s)).toList();

        for (final s in _students) {
          await _databaseService.insertUser(s);
        }
      } else {
        _students = await _databaseService.getStudents();
      }
    } catch (_) {
      _students = await _databaseService.getStudents();
    }

    debugPrint(
        "✅ Loaded ${_courses.length} courses, ${_faculties.length} faculties, ${_departments.length} departments, ${_years.length} years, ${_students.length} students");
  } catch (e) {
    debugPrint('❌ Error loading enrollment data: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enrollment Management'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.group_add), text: 'Bulk Enroll'),
            Tab(icon: Icon(Icons.person_add), text: 'Individual'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBulkEnrollmentTab(),
                _buildIndividualEnrollmentTab(),
              ],
            ),
    );
  }

  Widget _buildBulkEnrollmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bulk Enrollment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enroll all students from a specific department and year into a course',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBulkEnrollmentForm(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkEnrollmentForm() {
    String? selectedCourseId;
    String? selectedFacultyId;
    String? selectedDepartmentId;
    String? selectedYearId;

    return StatefulBuilder(
      builder: (context, setState) {
        final filteredDepartments = selectedFacultyId != null
            ? _departments.where((d) => d.facultyId == selectedFacultyId).toList()
            : <Department>[];

        return Column(
          children: [
            // Course selection
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Course',
                border: OutlineInputBorder(),
              ),
              value: selectedCourseId,
              items: _courses.map((course) {
                return DropdownMenuItem(
                  value: course.id,
                  child: Text('${course.code} - ${course.name}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCourseId = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Faculty selection
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Faculty',
                border: OutlineInputBorder(),
              ),
              value: selectedFacultyId,
              items: _faculties.map((faculty) {
                return DropdownMenuItem(
                  value: faculty.id,
                  child: Text(faculty.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedFacultyId = value;
                  selectedDepartmentId = null; // Reset department
                });
              },
            ),
            const SizedBox(height: 16),

            // Department selection
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Department',
                border: OutlineInputBorder(),
              ),
              value: selectedDepartmentId,
              items: filteredDepartments.map((department) {
                return DropdownMenuItem(
                  value: department.id,
                  child: Text(department.name),
                );
              }).toList(),
              onChanged: selectedFacultyId == null ? null : (value) {
                setState(() {
                  selectedDepartmentId = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Year selection
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Year',
                border: OutlineInputBorder(),
              ),
              value: selectedYearId,
              items: _years.map((year) {
                return DropdownMenuItem(
                  value: year.id,
                  child: Text(year.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedYearId = value;
                });
              },
            ),
            const SizedBox(height: 24),

            // Preview and enroll button
            if (selectedCourseId != null && selectedDepartmentId != null && selectedYearId != null)
              Column(
                children: [
                  FutureBuilder<List<User>>(
                    future: _getStudentsForBulkEnrollment(selectedDepartmentId!, selectedYearId!),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final students = snapshot.data!;
                        return Card(
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  'Preview: ${students.length} students will be enrolled',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (students.isNotEmpty)
                                  Text(
                                    students.take(3).map((s) => '${s.firstName} ${s.lastName}').join(', ') +
                                        (students.length > 3 ? '...' : ''),
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _performBulkEnrollment(
                        selectedCourseId!,
                        selectedDepartmentId!,
                        selectedYearId!,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Enroll All Students',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildIndividualEnrollmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Individual Enrollment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search and enroll specific students into courses',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildIndividualEnrollmentForm(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualEnrollmentForm() {
    String searchQuery = '';
    String? selectedCourseId;
    List<User> selectedStudents = [];

    return StatefulBuilder(
      builder: (context, setState) {
        final filteredStudents = _students.where((student) {
          if (searchQuery.isEmpty) return false;
          return student.firstName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                 student.lastName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                 student.username.toLowerCase().contains(searchQuery.toLowerCase());
        }).toList();

        return Column(
          children: [
            // Course selection
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Course',
                border: OutlineInputBorder(),
              ),
              value: selectedCourseId,
              items: _courses.map((course) {
                return DropdownMenuItem(
                  value: course.id,
                  child: Text('${course.code} - ${course.name}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCourseId = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Student search
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search Students',
                hintText: 'Enter name or username...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Student selection
            if (filteredStudents.isNotEmpty)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    final isSelected = selectedStudents.contains(student);
                    
                    return CheckboxListTile(
                      title: Text('${student.firstName} ${student.lastName}'),
                      subtitle: Text('${student.username} • ${student.faculty?.name ?? 'No Faculty'}'),
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            selectedStudents.add(student);
                          } else {
                            selectedStudents.remove(student);
                          }
                        });
                      },
                    );
                  },
                ),
              ),

            if (selectedStudents.isNotEmpty && selectedCourseId != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${selectedStudents.length} students selected for enrollment',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _performIndividualEnrollment(selectedCourseId!, selectedStudents),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Enroll ${selectedStudents.length} Students',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<List<User>> _getStudentsForBulkEnrollment(String departmentId, String yearId) async {
    return _students.where((student) {
      return student.departmentId == departmentId && student.yearId == yearId;
    }).toList();
  }

  Future<void> _performBulkEnrollment(String courseId, String departmentId, String yearId) async {
    try {
      final students = await _getStudentsForBulkEnrollment(departmentId, yearId);
      final currentUser = _authService.currentUser!;
      
      int enrolledCount = 0;
      for (final student in students) {
        final enrollment = Enrollment(
          studentId: student.id,
          courseId: courseId,
          enrollmentDate: DateTime.now(),
          status: EnrollmentStatus.active,
          enrolledBy: currentUser.id,
          notes: 'Bulk enrollment by admin',
        );
        
        await _databaseService.createEnrollment(enrollment);
        enrolledCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully enrolled $enrolledCount students'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error performing bulk enrollment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to enroll students: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performIndividualEnrollment(String courseId, List<User> students) async {
    try {
      final currentUser = _authService.currentUser!;
      
      for (final student in students) {
        final enrollment = Enrollment(
          studentId: student.id,
          courseId: courseId,
          enrollmentDate: DateTime.now(),
          status: EnrollmentStatus.active,
          enrolledBy: currentUser.id,
          notes: 'Individual enrollment by admin',
        );
        
        await _databaseService.createEnrollment(enrollment);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully enrolled ${students.length} students'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error performing individual enrollment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to enroll students: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
