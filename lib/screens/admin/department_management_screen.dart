import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


class DepartmentManagementScreen extends StatefulWidget {
  final Faculty? faculty;

  const DepartmentManagementScreen({super.key, this.faculty});

  @override
  State<DepartmentManagementScreen> createState() =>
      _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState
    extends State<DepartmentManagementScreen> {
  final DatabaseService _databaseService = DatabaseService();

  List<Department> _departments = [];
  List<Department> _filteredDepartments = [];
  List<Faculty> _faculties = [];
  String _searchQuery = '';
  String? _selectedFacultyId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedFacultyId = widget.faculty?.id;
    _loadData();
  }

 Future<void> _loadData() async {
  setState(() => _isLoading = true);

  try {
    // Fetch faculties from API
    final facultyResponse =
        await http.get(Uri.parse('http://192.168.1.155:5000/api/faculties'));
    if (facultyResponse.statusCode == 200) {
      final body = jsonDecode(facultyResponse.body);
      final List<dynamic> items =
          body is List ? body : (body['items'] ?? []);
      _faculties = items.map((f) => Faculty.fromJson(f)).toList();

      // Save to local DB
      for (final f in _faculties) {
        await _databaseService.insertFaculty(f);
      }
    } else {
      debugPrint("❌ Failed to fetch faculties: ${facultyResponse.body}");
      _faculties = await _databaseService.getAllFaculties();
    }

    // Fetch departments
    final departmentResponse =
        await http.get(Uri.parse('http://192.168.1.155:5000/api/departments'));
    if (departmentResponse.statusCode == 200) {
      final body = jsonDecode(departmentResponse.body);
      final List<dynamic> items =
          body is List ? body : (body['items'] ?? []);
      _departments = items.map((d) => Department.fromJson(d)).toList();

      // Save to local DB
      for (final d in _departments) {
        await _databaseService.insertDepartment(d);
      }
    } else {
      debugPrint("❌ Failed to fetch departments: ${departmentResponse.body}");
      _departments = await _databaseService.getAllDepartments();
    }

    // Apply faculty filter if needed
    if (_selectedFacultyId != null) {
      _departments = _departments
          .where((d) => d.facultyId == _selectedFacultyId)
          .toList();
    }

    _filterDepartments();
    debugPrint("✅ Loaded ${_faculties.length} faculties and ${_departments.length} departments");
  } catch (e) {
    debugPrint('⚠️ Server unavailable, loading from local DB: $e');
    _faculties = await _databaseService.getAllFaculties();
    _departments = _selectedFacultyId != null
        ? await _databaseService.getDepartmentsByFaculty(_selectedFacultyId!)
        : await _databaseService.getAllDepartments();
    _filterDepartments();
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _filterDepartments() {
    _filteredDepartments = _departments.where((department) {
      final matchesSearch =
          department.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          department.code.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesFaculty =
          _selectedFacultyId == null ||
          department.facultyId == _selectedFacultyId;

      return matchesSearch && matchesFaculty;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.faculty != null
              ? '${widget.faculty!.name} Departments'
              : 'Department Management',
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search and filter section
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      // Search bar
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search departments...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                            _filterDepartments();
                          });
                        },
                      ),

                      if (widget.faculty == null) ...[
                        const SizedBox(height: 12),
                        // Faculty filter
                        Row(
                          children: [
                            const Text('Filter by faculty: '),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String?>(
                                value: _selectedFacultyId,
                                isExpanded: true,
                                hint: const Text('All faculties'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All faculties'),
                                  ),
                                  ..._faculties.map(
                                    (faculty) => DropdownMenuItem<String?>(
                                      value: faculty.id,
                                      child: Text(faculty.name),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedFacultyId = value;
                                    _loadData();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Departments list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: _filteredDepartments.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.business,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text('No departments found'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredDepartments.length,
                            itemBuilder: (context, index) {
                              final department = _filteredDepartments[index];
                              final faculty = _faculties.firstWhere(
                                (f) => f.id == department.facultyId,
                                orElse: () =>
                                    Faculty(name: 'Unknown', code: 'UNK'),
                              );

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: department.isActive
                                        ? Colors.teal
                                        : Colors.grey,
                                    child: Text(
                                      department.code
                                          .substring(0, 2)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(department.name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Code: ${department.code}'),
                                      Text('Faculty: ${faculty.name}'),
                                      if (department.description != null &&
                                          department.description!.isNotEmpty)
                                        Text(
                                          department.description!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      Row(
                                        children: [
                                          if (!department.isActive)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Inactive',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) =>
                                        _handleDepartmentAction(
                                          value,
                                          department,
                                        ),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'view',
                                        child: Row(
                                          children: [
                                            Icon(Icons.visibility),
                                            SizedBox(width: 8),
                                            Text('View Details'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: department.isActive
                                            ? 'deactivate'
                                            : 'activate',
                                        child: Row(
                                          children: [
                                            Icon(
                                              department.isActive
                                                  ? Icons.block
                                                  : Icons.check_circle,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              department.isActive
                                                  ? 'Deactivate'
                                                  : 'Activate',
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDepartment,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add),
        label: const Text('Add Department'),
      ),
    );
  }

  void _addDepartment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditDepartmentScreen(
          faculties: _faculties,
          selectedFacultyId: _selectedFacultyId,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  Future<void> _handleDepartmentAction(
    String action,
    Department department,
  ) async {
    switch (action) {
      case 'view':
        _viewDepartmentDetails(department);
        break;
      case 'edit':
        _editDepartment(department);
        break;
      case 'activate':
      case 'deactivate':
        _toggleDepartmentStatus(department);
        break;
      case 'delete':
        _deleteDepartment(department);
        break;
    }
  }

  void _viewDepartmentDetails(Department department) {
    final faculty = _faculties.firstWhere(
      (f) => f.id == department.facultyId,
      orElse: () => Faculty(name: 'Unknown', code: 'UNK'),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(department.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Code', department.code),
              _buildDetailRow('Name', department.name),
              _buildDetailRow('Faculty', faculty.name),
              if (department.description != null &&
                  department.description!.isNotEmpty)
                _buildDetailRow('Description', department.description!),
              _buildDetailRow(
                'Status',
                department.isActive ? 'Active' : 'Inactive',
              ),
              _buildDetailRow('Created', _formatDate(department.createdAt)),
              _buildDetailRow(
                'Last Updated',
                _formatDate(department.updatedAt),
              ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _editDepartment(Department department) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditDepartmentScreen(
          department: department,
          faculties: _faculties,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _toggleDepartmentStatus(Department department) async {
    final action = department.isActive ? 'deactivate' : 'activate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${action[0].toUpperCase()}${action.substring(1)} Department',
        ),
        content: Text(
          '${action[0].toUpperCase()}${action.substring(1)} "${department.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('${action[0].toUpperCase()}${action.substring(1)}'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final updatedDepartment = department.copyWith(
          isActive: !department.isActive,
        );
        await _databaseService.updateDepartment(updatedDepartment);
        _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Department ${action}d successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to $action department: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteDepartment(Department department) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Department'),
        content: Text(
          'Permanently delete "${department.name}"? This action cannot be undone.',
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
      try {
        await _databaseService.deleteDepartment(department.id);
        _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${department.name} deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete department: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class AddEditDepartmentScreen extends StatefulWidget {
  final Department? department;
  final List<Faculty> faculties;
  final String? selectedFacultyId;

  const AddEditDepartmentScreen({
    super.key,
    this.department,
    required this.faculties,
    this.selectedFacultyId,
  });

  @override
  State<AddEditDepartmentScreen> createState() =>
      _AddEditDepartmentScreenState();
}

class _AddEditDepartmentScreenState extends State<AddEditDepartmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedFacultyId;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.department != null;
    _selectedFacultyId = widget.selectedFacultyId;

    if (_isEditing) {
      _nameController.text = widget.department!.name;
      _codeController.text = widget.department!.code;
      _descriptionController.text = widget.department!.description ?? '';
      _selectedFacultyId = widget.department!.facultyId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Department' : 'Add Department'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedFacultyId,
                decoration: const InputDecoration(
                  labelText: 'Faculty',
                  border: OutlineInputBorder(),
                ),
                items: widget.faculties.map((faculty) {
                  return DropdownMenuItem(
                    value: faculty.id,
                    child: Text(faculty.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFacultyId = value;
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

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Department Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter department name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Department Code',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter department code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveDepartment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isEditing
                              ? 'Update Department'
                              : 'Create Department',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveDepartment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        final updatedDepartment = widget.department!.copyWith(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          facultyId: _selectedFacultyId!,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
        await DatabaseService().updateDepartment(updatedDepartment);
      } else {
        final newDepartment = Department(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          facultyId: _selectedFacultyId!,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
        await DatabaseService().insertDepartment(newDepartment);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Department updated successfully'
                  : 'Department created successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save department: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
