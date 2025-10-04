import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class FileUploadScreen extends StatefulWidget {
  final Course? selectedCourse;

  const FileUploadScreen({super.key, this.selectedCourse});

  @override
  State<FileUploadScreen> createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final FileService _fileService = FileService();

  List<Course> _courses = [];
  Course? _selectedCourse;
  List<PlatformFile> _selectedFiles = [];
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedCourse = widget.selectedCourse;
    _loadCourses();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser!;
      _courses = await _databaseService.getLecturerCourses(user.id);
    } catch (e) {
      debugPrint("Error loading courses: $e");
      _courses = [];
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadFiles() async {
  if (!_formKey.currentState!.validate()) return;
  if (_selectedCourse == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a course'), backgroundColor: Colors.red),
    );
    return;
  }
  if (_selectedFiles.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select files to upload'), backgroundColor: Colors.red),
    );
    return;
  }

  setState(() => _isUploading = true);
  int successCount = 0;

  try {
    for (final file in _selectedFiles) {
      final uploadedFile = await _fileService.uploadFile(
        platformFile: file,
        courseId: _selectedCourse!.id,
        description: _descriptionController.text.trim(),
      );

      if (uploadedFile != null) {
        successCount++;
        // Show server returned message for each uploaded file
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File "${file.name}" uploaded: ${uploadedFile.message}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File "${file.name}" failed to upload'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount of ${_selectedFiles.length} files uploaded successfully'),
          backgroundColor: Colors.blue,
        ),
      );

      if (successCount > 0) Navigator.of(context).pop(true);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) setState(() => _isUploading = false);
  }
}

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Files'), backgroundColor: Colors.green),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<Course>(
                      value: _selectedCourse,
                      items: _courses
                          .map((course) => DropdownMenuItem(
                                value: course,
                                child: Text('${course.code} - ${course.name}'),
                              ))
                          .toList(),
                      onChanged: (course) => setState(() => _selectedCourse = course),
                      decoration: const InputDecoration(
                        labelText: 'Select Course',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null ? 'Please select a course' : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Choose Files'),
                    ),
                    if (_selectedFiles.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('${_selectedFiles.length} file(s) selected'),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _uploadFiles,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: _isUploading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Upload Files'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
