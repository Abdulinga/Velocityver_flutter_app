import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/services.dart';
import '../../services/database_service.dart';


class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final DatabaseService _databaseService = DatabaseService();
  
  List<User> _users = [];
  List<Role> _roles = [];
  List<Faculty> _faculties = [];
  List<Department> _departments = [];
  
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
  setState(() => _isLoading = true);

  try {
    final futures = await Future.wait([
      _databaseService.getAllUsers(),
      _databaseService.getAllRoles(),
      _databaseService.getAllFaculties(),
      _databaseService.getAllDepartments(),
    ]);

    _users = futures[0] as List<User>;
    _roles = futures[1] as List<Role>;
    _faculties = futures[2] as List<Faculty>;
    _departments = futures[3] as List<Department>;

    debugPrint("✅ Loaded ${_users.length} users");
    for (final u in _users) {
      debugPrint("👤 ${u.id} | ${u.fullName} | ${u.username}");
    }
  } catch (e) {
    debugPrint('Error loading data: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load users: ${e.toString()}'),
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

  String _getRoleName(String? roleId) {
    if (roleId == null) return 'Unknown';
    final role = _roles.firstWhere(
      (r) => r.id == roleId,
      orElse: () => Role(id: '', name: 'Unknown'),
    );
    return role.name;
  }

String _getFacultyName(String? facultyId) {
  if (facultyId == null) return '';
  final faculty = _faculties.firstWhere(
    (f) => f.id == facultyId,
    orElse: () => Faculty(
      id: '',
      name: '',
      code: '',  
    ),
  );
  return faculty.name;
}

  String _getDepartmentName(String? departmentId) {
  if (departmentId == null) return '';
  final department = _departments.firstWhere(
    (d) => d.id == departmentId,
    orElse: () => Department(
      id: '',
      name: '',
      code: '',   
      facultyId: '',
    ),
  );
  return department.name;
}


  List<User> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    
    return _users.where((user) {
      final fullName = '${user.firstName} ${user.lastName}'.toLowerCase();
      final username = user.username.toLowerCase();
      final email = user.email.toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return fullName.contains(query) ||
             username.contains(query) ||
             email.contains(query);
    }).toList();
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete "${user.firstName} ${user.lastName}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseService.deleteUser(user.id!);
        await _loadData(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete user: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _navigateToAddEditUser([User? user]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddEditUserScreen(user: user),
      ),
    );

    if (result == true) {
      await _loadData(); // Refresh the list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                hintStyle: const TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No users found'
                            : 'No users match your search',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Tap the + button to add your first user',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final roleName = _getRoleName(user.roleId);
                      final facultyName = _getFacultyName(user.facultyId);
                      final departmentName = _getDepartmentName(user.departmentId);
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepPurple.withOpacity(0.1),
                            child: Text(
                              '${user.firstName[0]}${user.lastName[0]}',
                              style: const TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            '${user.firstName} ${user.lastName}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@${user.username} • ${user.email}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(roleName).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      roleName,
                                      style: TextStyle(
                                        color: _getRoleColor(roleName),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (facultyName.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      facultyName,
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (departmentName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  departmentName,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  _navigateToAddEditUser(user);
                                  break;
                                case 'delete':
                                  _deleteUser(user);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit, size: 20),
                                  title: Text('Edit'),
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
                          onTap: () => _navigateToAddEditUser(user),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditUser(),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getRoleColor(String roleName) {
    switch (roleName.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'teacher':
      case 'lecturer':
        return Colors.blue;
      case 'student':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

// Updated AddEditUserScreen with better integration
class AddEditUserScreen extends StatefulWidget {
  final User? user;

  const AddEditUserScreen({
    super.key,
    this.user,
  });

  @override
  State<AddEditUserScreen> createState() => _AddEditUserScreenState();
}

class _AddEditUserScreenState extends State<AddEditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  final DatabaseService _databaseService = DatabaseService();
  
  List<Role> _roles = [];
  List<Faculty> _faculties = [];
  List<Department> _departments = [];
  List<Level> _levels = [];
  List<Year> _years = [];
  
  String? _selectedRoleId;
  String? _selectedFacultyId;
  String? _selectedDepartmentId;
  String? _selectedLevelId;
  String? _selectedYearId;
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.user != null;
    _loadData();
    _populateFields();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _populateFields() {
    if (widget.user != null) {
      _usernameController.text = widget.user!.username;
      _emailController.text = widget.user!.email;
      _firstNameController.text = widget.user!.firstName;
      _lastNameController.text = widget.user!.lastName;
      _selectedRoleId = widget.user!.roleId;
      _selectedFacultyId = widget.user!.facultyId;
      _selectedDepartmentId = widget.user!.departmentId;
      _selectedLevelId = widget.user!.levelId;
      _selectedYearId = widget.user!.yearId;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _roles = await _databaseService.getAllRoles();
      _faculties = await _databaseService.getAllFaculties();
      _levels = await _databaseService.getAllLevels();
      _years = await _databaseService.getAllYears();
      
      if (_selectedFacultyId != null) {
        _departments = await _databaseService.getDepartmentsByFaculty(_selectedFacultyId!);
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDepartments(String facultyId) async {
    try {
      _departments = await _databaseService.getDepartmentsByFaculty(facultyId);
      setState(() {
        _selectedDepartmentId = null; // Reset department selection
      });
    } catch (e) {
      debugPrint('Error loading departments: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit User' : 'Add User'),
        backgroundColor: Colors.deepPurple,
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
                    // Basic Information
                    Text(
                      'Basic Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter first name';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter last name';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter username';
                        }
                        if (value.length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    if (!_isEditing)
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (!_isEditing && (value == null || value.length < 6)) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    if (!_isEditing) const SizedBox(height: 24),
                    
                    // Role Selection
                    Text(
                      'Role & Permissions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedRoleId,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: _roles.map((role) {
                        return DropdownMenuItem(
                          value: role.id,
                          child: Text(role.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRoleId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a role';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Academic Information (for students)
                    if (_selectedRoleId == 'role_student') ...[
                      Text(
                        'Academic Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedLevelId,
                              decoration: const InputDecoration(
                                labelText: 'Level',
                                border: OutlineInputBorder(),
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
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedYearId,
                              decoration: const InputDecoration(
                                labelText: 'Year',
                                border: OutlineInputBorder(),
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
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: _selectedFacultyId,
                        decoration: const InputDecoration(
                          labelText: 'Faculty',
                          border: OutlineInputBorder(),
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
                            if (value != null) {
                              _loadDepartments(value);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: _selectedDepartmentId,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                        items: _departments.map((department) {
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
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
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
                                  Text('Saving...'),
                                ],
                              )
                            : Text(
                                _isEditing ? 'Update User' : 'Create User',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        // Update existing user
        final updatedUser = widget.user!.copyWith(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          roleId: _selectedRoleId!,
          levelId: _selectedLevelId,
          yearId: _selectedYearId,
          departmentId: _selectedDepartmentId,
          facultyId: _selectedFacultyId,
        );
        
        await _databaseService.updateUser(updatedUser);
      } else {
        // Create new user
        final newUser = User(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          passwordHash: _passwordController.text, // This should be hashed in a real implementation
          roleId: _selectedRoleId!,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          levelId: _selectedLevelId,
          yearId: _selectedYearId,
          departmentId: _selectedDepartmentId,
          facultyId: _selectedFacultyId,
        );
        
        await _databaseService.insertUser(newUser);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'User updated successfully' : 'User created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save user: ${e.toString()}'),
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