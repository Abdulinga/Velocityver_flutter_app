import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/services.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  
  List<Role> _roles = [];
  List<Course> _courses = [];
  List<String> _selectedRoles = [];
  List<String> _selectedCourses = [];
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _targetAllUsers = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _roles = await _databaseService.getAllRoles();
      _courses = await _authService.getUserCourses();
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Announcement'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                        hintText: 'Enter announcement title...',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Content field
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        border: OutlineInputBorder(),
                        hintText: 'Enter announcement content...',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 6,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter content';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Target audience section
                    Text(
                      'Target Audience',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // All users option
                    CheckboxListTile(
                      title: const Text('All Users'),
                      subtitle: const Text('Send to everyone in the system'),
                      value: _targetAllUsers,
                      onChanged: (value) {
                        setState(() {
                          _targetAllUsers = value ?? false;
                          if (_targetAllUsers) {
                            _selectedRoles.clear();
                            _selectedCourses.clear();
                          }
                        });
                      },
                    ),

                    if (!_targetAllUsers) ...[
                      const SizedBox(height: 16),
                      
                      // Role targeting
                      Text(
                        'Target by Role',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      Wrap(
                        spacing: 8,
                        children: _roles.map((role) {
                          final isSelected = _selectedRoles.contains(role.id);
                          return FilterChip(
                            label: Text(role.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedRoles.add(role.id);
                                } else {
                                  _selectedRoles.remove(role.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Course targeting (for lecturers)
                      if (_courses.isNotEmpty) ...[
                        Text(
                          'Target by Course',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        Wrap(
                          spacing: 8,
                          children: _courses.map((course) {
                            final isSelected = _selectedCourses.contains(course.id);
                            return FilterChip(
                              label: Text(course.code),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCourses.add(course.id);
                                  } else {
                                    _selectedCourses.remove(course.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],

                    const SizedBox(height: 32),

                    // Create button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _createAnnouncement,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Creating...'),
                                ],
                              )
                            : const Text(
                                'Create Announcement',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _createAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final announcement = Announcement(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        authorId: currentUser.id,
        targetRoles: _targetAllUsers ? [] : _selectedRoles,
        targetCourses: _targetAllUsers ? [] : _selectedCourses,
      );

      await _databaseService.insertAnnouncement(announcement);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create announcement: ${e.toString()}'),
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
