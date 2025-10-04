import 'package:flutter/material.dart';
import 'dart:convert';
import '../../models/models.dart';
import '../../services/services.dart';
import 'package:http/http.dart' as http;

class CourseManagementScreen extends StatefulWidget {
  const CourseManagementScreen({super.key});

  @override
  State<CourseManagementScreen> createState() => _CourseManagementScreenState();
}

class _CourseManagementScreenState extends State<CourseManagementScreen> {
  final DatabaseService _databaseService = DatabaseService();
  
  List<Course> _courses = [];
  List<Course> _filteredCourses = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

Future<void> _loadCourses() async {
  setState(() => _isLoading = true);

  try {
    // Fetch from server first
    final response = await http.get(Uri.parse('http://192.168.1.155:5000/api/courses'));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      // Handle API returning a list OR wrapped in {"items": []}
      final List<dynamic> items = body is List ? body : (body['items'] ?? []);

      _courses = items.map((c) => Course.fromJson(c)).toList();
      

      // Save to local DB for offline support
      for (final c in _courses) {
        await _databaseService.insertCourse(c);
      }

      debugPrint("✅ Loaded ${_courses.length} courses from server");
    } else {
      debugPrint("❌ Failed to fetch courses: ${response.body}");
      // fallback to local
      _courses = await _databaseService.getAllCourses();
    }
  } catch (e) {
    debugPrint("⚠️ Server unavailable, using local DB: $e");
    _courses = await _databaseService.getAllCourses();
  } finally {
    _filterCourses();
    if (mounted) setState(() => _isLoading = false);
  }
}
  void _filterCourses() {
    _filteredCourses = _courses.where((course) {
      return course.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          course.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (course.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Management'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search courses by name, code, or description...',
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _filterCourses();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                hintStyle: const TextStyle(color: Colors.white70),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterCourses();
                });
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text('Loading courses...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _filteredCourses.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadCourses,
                  color: Colors.green,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _filteredCourses.length,
                    itemBuilder: (context, index) {
                      final course = _filteredCourses[index];
                      return _buildCourseCard(course);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCourse,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Course'),
        elevation: 4,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty ? Icons.book_outlined : Icons.search_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isEmpty
                  ? 'No courses available'
                  : 'No courses match your search',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty
                  ? 'Get started by adding your first course'
                  : 'Try adjusting your search terms',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _addCourse,
                icon: const Icon(Icons.add),
                label: const Text('Add First Course'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(Course course) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _viewCourseDetails(course),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: course.isActive 
                        ? Colors.green.withOpacity(0.2) 
                        : Colors.grey.withOpacity(0.2),
                    radius: 24,
                    child: Text(
                      course.code.length >= 2 
                          ? course.code.substring(0, 2).toUpperCase()
                          : course.code.toUpperCase(),
                      style: TextStyle(
                        color: course.isActive ? Colors.green : Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          course.code,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleCourseAction(value, course),
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: ListTile(
                          leading: Icon(Icons.visibility, size: 20),
                          title: Text('View Details'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit, size: 20),
                          title: Text('Edit Course'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'manage_students',
                        child: ListTile(
                          leading: Icon(Icons.people, size: 20),
                          title: Text('Manage Students'),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: course.isActive ? 'deactivate' : 'activate',
                        child: ListTile(
                          leading: Icon(
                            course.isActive ? Icons.block : Icons.check_circle,
                            size: 20,
                            color: course.isActive ? Colors.orange : Colors.green,
                          ),
                          title: Text(
                            course.isActive ? 'Deactivate' : 'Activate',
                            style: TextStyle(
                              color: course.isActive ? Colors.orange : Colors.green,
                            ),
                          ),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, size: 20, color: Colors.red),
                          title: Text('Delete', style: TextStyle(color: Colors.red)),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (course.description != null && course.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  course.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: course.isActive 
                          ? Colors.green.withOpacity(0.1) 
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: course.isActive ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      course.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: course.isActive ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Updated: ${_formatDate(course.updatedAt)}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Create new course
  Future<void> _addCourse() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditCourseScreen(),
      ),
    );

    if (result == true) {
      await _loadCourses();
    }
  }

  Future<void> _handleCourseAction(String action, Course course) async {
    switch (action) {
      case 'view':
        _viewCourseDetails(course);
        break;
      case 'edit':
        _editCourse(course);
        break;
      case 'manage_students':
        _manageStudents(course);
        break;
      case 'activate':
      case 'deactivate':
        await _toggleCourseStatus(course);
        break;
      case 'delete':
        await _deleteCourse(course);
        break;
    }
  }

  // View course details
  void _viewCourseDetails(Course course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: course.isActive 
                  ? Colors.green.withOpacity(0.2) 
                  : Colors.grey.withOpacity(0.2),
              radius: 20,
              child: Text(
                course.code.length >= 2 
                    ? course.code.substring(0, 2).toUpperCase()
                    : course.code.toUpperCase(),
                style: TextStyle(
                  color: course.isActive ? Colors.green : Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                course.name,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Course Code', course.code),
              _buildDetailRow('Course Name', course.name),
              if (course.description != null && course.description!.isNotEmpty)
                _buildDetailRow('Description', course.description!),
              _buildDetailRow('Status', course.isActive ? 'Active' : 'Inactive'),
              _buildDetailRow('Level ID', course.levelId ?? 'Not specified'),
              _buildDetailRow('Year ID', course.yearId ?? 'Not specified'),
              _buildDetailRow('Department ID', course.departmentId ?? 'Not specified'),
              _buildDetailRow('Faculty ID', course.facultyId ?? 'Not specified'),
              _buildDetailRow('Created', _formatDate(course.createdAt)),
              _buildDetailRow('Last Updated', _formatDate(course.updatedAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _editCourse(course);
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // Edit existing course
  Future<void> _editCourse(Course course) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCourseScreen(course: course),
      ),
    );

    if (result == true) {
      await _loadCourses();
    }
  }

  void _manageStudents(Course course) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Text('Student management for "${course.name}" coming soon'),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Delete course with confirmation
  Future<void> _deleteCourse(Course course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[700]),
            const SizedBox(width: 8),
            const Text('Delete Course'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  const TextSpan(text: 'Are you sure you want to delete '),
                  TextSpan(
                    text: '"${course.name}"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                 TextSpan(text: ' (${course.code})?'), 
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This action will permanently remove:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Course information and details'),
                  Text('• Associated student enrollments'),
                  Text('• Course materials and assignments'),
                  Text('• All related academic records'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete Course'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseService.deleteCourse(course.id!);
        await _loadCourses(); // Refresh the list
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Course "${course.name}" deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Failed to delete course: ${e.toString()}'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleCourseStatus(Course course) async {
    final action = course.isActive ? 'deactivate' : 'activate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action.capitalize()} Course'),
        content: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              TextSpan(text: '${action.capitalize()} '),
              TextSpan(
                text: '"${course.name}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: course.isActive ? Colors.orange : Colors.green,
            ),
            child: Text(action.capitalize()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final updatedCourse = course.copyWith(isActive: !course.isActive);
        await _databaseService.updateCourse(updatedCourse);
        await _loadCourses(); // Refresh the list
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Course ${action}d successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Failed to $action course: ${e.toString()}'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class AddEditCourseScreen extends StatefulWidget {
  final Course? course;

  const AddEditCourseScreen({super.key, this.course});

  @override
  State<AddEditCourseScreen> createState() => _AddEditCourseScreenState();
}

class _AddEditCourseScreenState extends State<AddEditCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final DatabaseService _databaseService = DatabaseService();
  
  List<Level> _levels = [];
  List<Year> _years = [];
  List<Department> _departments = [];
  List<Faculty> _faculties = [];
  List<User> _lecturers = [];
  String? _selectedLecturerId;

  
  String? _selectedLevelId;
  String? _selectedYearId;
  String? _selectedDepartmentId;
  String? _selectedFacultyId;
  
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.course != null;
    _loadData();
    _populateFields();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _populateFields() {
    if (widget.course != null) {
      _nameController.text = widget.course!.name;
      _codeController.text = widget.course!.code;
      _descriptionController.text = widget.course!.description ?? '';
      _selectedLevelId = widget.course!.levelId;
      _selectedYearId = widget.course!.yearId;
      _selectedDepartmentId = widget.course!.departmentId;
      _selectedFacultyId = widget.course!.facultyId;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final futures = await Future.wait([
        _databaseService.getAllLevels(),
        _databaseService.getAllYears(),
        _databaseService.getAllDepartments(),
        _databaseService.getAllFaculties(),
        _databaseService.getAllLecturers(), // You need this method
      ]);

      _levels = futures[0] as List<Level>;
      _years = futures[1] as List<Year>;
      _departments = futures[2] as List<Department>;
      _faculties = futures[3] as List<Faculty>;
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load form data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Course' : 'Create New Course'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: () => _viewCourseDetails(),
              icon: const Icon(Icons.visibility),
              tooltip: 'View Details',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text('Loading form data...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    if (_isEditing) ...[
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Editing: ${widget.course!.name} (${widget.course!.code})',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Basic Information Section
                    _buildSectionHeader('Course Information', Icons.book),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Course Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.book),
                        hintText: 'Enter full course name',
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter course name';
                        }
                        if (value.trim().length < 3) {
                          return 'Course name must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Course Code *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                        hintText: 'e.g., CS101, MATH201, ENG102',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter course code';
                        }
                        if (value.trim().length < 2) {
                          return 'Course code must be at least 2 characters';
                        }
                        // Check for valid format (letters followed by numbers)
                        final regex = RegExp(r'^[A-Z]+\d+$');
                        if (!regex.hasMatch(value.trim().toUpperCase())) {
                          return 'Invalid format. Use format like CS101, MATH201';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Course Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                        hintText: 'Brief description of the course content and objectives',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 32),
                    
                    // Academic Information Section
                    _buildSectionHeader('Academic Information', Icons.school),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedLevelId,
                            decoration: const InputDecoration(
                              labelText: 'Academic Level *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.school),
                            ),
                            items: _levels.map((level) {
                              return DropdownMenuItem(
                                value: level.id,
                                child: Text(level.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedLevelId = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a level';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedYearId,
                            decoration: const InputDecoration(
                              labelText: 'Academic Year *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            items: _years.map((year) {
                              return DropdownMenuItem(
                                value: year.id,
                                child: Text(year.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedYearId = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a year';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedFacultyId,
                      decoration: const InputDecoration(
                        labelText: 'Faculty *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                      items: _faculties.map((faculty) {
                        return DropdownMenuItem(
                          value: faculty.id,
                          child: Text(faculty.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFacultyId = value;
                          _selectedDepartmentId = null; // Reset department when faculty changes
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a faculty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedDepartmentId,
                      decoration: const InputDecoration(
                        labelText: 'Department *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      items: _departments
                          .where((dept) => dept.facultyId == _selectedFacultyId)
                          .map((department) {
                        return DropdownMenuItem(
                          value: department.id,
                          child: Text(department.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartmentId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a department';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedLecturerId,
                        decoration: const InputDecoration(
                          labelText: 'Assign Lecturer',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: _lecturers.map((lecturer) {
                          return DropdownMenuItem(
                            value: lecturer.id,
                            child: Text('${lecturer.firstName} ${lecturer.lastName}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLecturerId = value;
                          });
                        },
                      ),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.cancel),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveCourse,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(_isEditing ? Icons.update : Icons.save),
                            label: Text(_isSaving
                                ? 'Saving...'
                                : (_isEditing ? 'Update Course' : 'Create Course')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.only(left: 16),
            color: Colors.green.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  void _viewCourseDetails() {
    if (widget.course == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.visibility, color: Colors.green[700]),
            const SizedBox(width: 8),
            const Text('Current Course Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCurrentDetailRow('Course Name', widget.course!.name),
              _buildCurrentDetailRow('Course Code', widget.course!.code),
              _buildCurrentDetailRow('Lecturer',widget.course!.lecturer?.fullName ?? 'Not assigned',),
              if (widget.course!.description != null && widget.course!.description!.isNotEmpty)
                _buildCurrentDetailRow('Description', widget.course!.description!),
              _buildCurrentDetailRow('Status', widget.course!.isActive ? 'Active' : 'Inactive'),
              _buildCurrentDetailRow('Created', _formatDate(widget.course!.createdAt)),
              _buildCurrentDetailRow('Last Updated', _formatDate(widget.course!.updatedAt)),
            ],
          ),
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

  Widget _buildCurrentDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
              if (_isEditing) {
          final updatedCourse = widget.course!.copyWith(
            name: _nameController.text.trim(),
            code: _codeController.text.trim().toUpperCase(),
            description: _descriptionController.text.trim().isEmpty 
                ? null 
                : _descriptionController.text.trim(),
            levelId: _selectedLevelId!,
            yearId: _selectedYearId!,
            departmentId: _selectedDepartmentId!,
            facultyId: _selectedFacultyId!,
            lecturerId: _selectedLecturerId,   // ✅ Added
          );
          await _databaseService.updateCourse(updatedCourse);
        } else {
          final newCourse = Course(
            name: _nameController.text.trim(),
            code: _codeController.text.trim().toUpperCase(),
            description: _descriptionController.text.trim().isEmpty 
                ? null 
                : _descriptionController.text.trim(),
            levelId: _selectedLevelId!,
            yearId: _selectedYearId!,
            departmentId: _selectedDepartmentId!,
            facultyId: _selectedFacultyId!,
            lecturerId: _selectedLecturerId,   // ✅ Added
          );
          await _databaseService.insertCourse(newCourse);
        }
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(_isEditing 
                  ? 'Course updated successfully' 
                  : 'Course created successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Return to previous screen with success flag
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to save course: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}