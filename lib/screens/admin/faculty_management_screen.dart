import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/services.dart';
import 'department_management_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FacultyManagementScreen extends StatefulWidget {
  const FacultyManagementScreen({super.key});

  @override
  State<FacultyManagementScreen> createState() => _FacultyManagementScreenState();
}

class _FacultyManagementScreenState extends State<FacultyManagementScreen> {
  final DatabaseService _databaseService = DatabaseService();
  
  List<Faculty> _faculties = [];
  List<Faculty> _filteredFaculties = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFaculties();
  }

 Future<void> _loadFaculties() async {
  setState(() => _isLoading = true);

  try {
    // Fetch from server
    final response = await http.get(
      Uri.parse('http://192.168.1.155:5000/api/faculties'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonBody = jsonDecode(response.body);
      final List<dynamic> items = jsonBody['items'] ?? [];

      _faculties = items.map((f) => Faculty.fromJson(f)).toList();

      // ✅ optional offline sync (if you’ve added insertFaculty to DatabaseService)
      for (final f in _faculties) {
        await _databaseService.insertFaculty(f);
      }
    } else {
      // If server fails, load from local DB
      _faculties = await _databaseService.getAllFaculties();
    }
  } catch (e) {
    debugPrint('Error loading faculties: $e');
    // fallback to local DB
    _faculties = await _databaseService.getAllFaculties();
  } finally {
    _filterFaculties();
    setState(() => _isLoading = false);
  }
}
  void _filterFaculties() {
    _filteredFaculties = _faculties.where((faculty) {
      return faculty.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faculty.code.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Management'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFaculties,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search faculties...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _filterFaculties();
                      });
                    },
                  ),
                ),

                // Faculties list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadFaculties,
                    child: _filteredFaculties.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No faculties found'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredFaculties.length,
                            itemBuilder: (context, index) {
                              final faculty = _filteredFaculties[index];
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: faculty.isActive ? Colors.indigo : Colors.grey,
                                    child: Text(
                                      faculty.code.substring(0, 2).toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(faculty.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Code: ${faculty.code}'),
                                      if (faculty.description != null && faculty.description!.isNotEmpty)
                                        Text(
                                          faculty.description!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                      Row(
                                        children: [
                                          if (!faculty.isActive)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
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
                                    onSelected: (value) => _handleFacultyAction(value, faculty),
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
                                      const PopupMenuItem(
                                        value: 'departments',
                                        child: Row(
                                          children: [
                                            Icon(Icons.business),
                                            SizedBox(width: 8),
                                            Text('Manage Departments'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: faculty.isActive ? 'deactivate' : 'activate',
                                        child: Row(
                                          children: [
                                            Icon(faculty.isActive ? Icons.block : Icons.check_circle),
                                            const SizedBox(width: 8),
                                            Text(faculty.isActive ? 'Deactivate' : 'Activate'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  isThreeLine: faculty.description != null && faculty.description!.isNotEmpty,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFaculty,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('Add Faculty'),
      ),
    );
  }

  void _addFaculty() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditFacultyScreen(),
      ),
    ).then((result) {
      if (result == true) {
        _loadFaculties();
      }
    });
  }

  Future<void> _handleFacultyAction(String action, Faculty faculty) async {
    switch (action) {
      case 'view':
        _viewFacultyDetails(faculty);
        break;
      case 'edit':
        _editFaculty(faculty);
        break;
      case 'departments':
        _manageDepartments(faculty);
        break;
      case 'activate':
      case 'deactivate':
        _toggleFacultyStatus(faculty);
        break;
      case 'delete':
        _deleteFaculty(faculty);
        break;
    }
  }

  void _viewFacultyDetails(Faculty faculty) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(faculty.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Code', faculty.code),
              _buildDetailRow('Name', faculty.name),
              if (faculty.description != null && faculty.description!.isNotEmpty)
                _buildDetailRow('Description', faculty.description!),
              _buildDetailRow('Status', faculty.isActive ? 'Active' : 'Inactive'),
              _buildDetailRow('Created', _formatDate(faculty.createdAt)),
              _buildDetailRow('Last Updated', _formatDate(faculty.updatedAt)),
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

  Future<void> _editFaculty(Faculty faculty) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditFacultyScreen(faculty: faculty),
      ),
    );

    if (result == true) {
      _loadFaculties();
    }
  }

  void _manageDepartments(Faculty faculty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DepartmentManagementScreen(faculty: faculty),
      ),
    );
  }

  Future<void> _toggleFacultyStatus(Faculty faculty) async {
    final action = faculty.isActive ? 'deactivate' : 'activate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action.capitalize()} Faculty'),
        content: Text('${action.capitalize()} "${faculty.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action.capitalize()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final updatedFaculty = faculty.copyWith(isActive: !faculty.isActive);
        await _databaseService.updateFaculty(updatedFaculty);
        _loadFaculties();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Faculty ${action}d successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to $action faculty: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteFaculty(Faculty faculty) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Faculty'),
        content: Text('Permanently delete "${faculty.name}"? This action cannot be undone and will also delete all associated departments.'),
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
        await _databaseService.deleteFaculty(faculty.id);
        _loadFaculties();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${faculty.name} deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete faculty: ${e.toString()}'),
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

class AddEditFacultyScreen extends StatefulWidget {
  final Faculty? faculty;

  const AddEditFacultyScreen({super.key, this.faculty});

  @override
  State<AddEditFacultyScreen> createState() => _AddEditFacultyScreenState();
}

class _AddEditFacultyScreenState extends State<AddEditFacultyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.faculty != null;
    if (_isEditing) {
      _nameController.text = widget.faculty!.name;
      _codeController.text = widget.faculty!.code;
      _descriptionController.text = widget.faculty!.description ?? '';
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
        title: Text(_isEditing ? 'Edit Faculty' : 'Add Faculty'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Faculty Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter faculty name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Faculty Code',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter faculty code';
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
                  onPressed: _isSaving ? null : _saveFaculty,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isEditing ? 'Update Faculty' : 'Create Faculty'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveFaculty() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        final updatedFaculty = widget.faculty!.copyWith(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
        );
        await DatabaseService().updateFaculty(updatedFaculty);
      } else {
        final newFaculty = Faculty(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
        );
        await DatabaseService().insertFaculty(newFaculty);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Faculty updated successfully' : 'Faculty created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save faculty: ${e.toString()}'),
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
