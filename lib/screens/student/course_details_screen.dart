import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/file_list_item.dart';

class CourseDetailsScreen extends StatefulWidget {
  final Course course;

  const CourseDetailsScreen({super.key, required this.course});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  final FileService _fileService = FileService();

  List<FileModel> _files = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _rawApiResponse;

  @override
  void initState() {
    super.initState();
    _loadAllFiles();
  }

  Future<void> _loadAllFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _rawApiResponse = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.155:5000/api/files/all'),
      );

      _rawApiResponse = response.body;

      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);

        // Only keep files for the current course
        _files = decoded.where((f) {
          final courseId = f['course_id']?.toString() ?? '';
          return courseId == widget.course.id.toString();
        }).map((f) {
          return FileModel(
            id: f['id'] ?? 'unknown',
            name: f['name'] ?? 'unknown',
            path: f['file_path'] ?? '',
            uploadedBy: f['uploaded_by'] ?? 'system',
            size: f['file_size'] ?? 0,
            mimeType: f['mime_type'] ?? 'application/octet-stream',
            courseId: f['course_id']?.toString() ?? 'unknown',
          );
        }).toList();
      } else {
        _errorMessage = 'Failed to fetch files (${response.statusCode})';
      }
    } catch (e) {
      _errorMessage = 'Error loading files: $e';
      _files = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDebugDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Info'),
        content: SingleChildScrollView(
          child: Text(_rawApiResponse ?? 'No API response captured.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Show API Debug Info',
            onPressed: _showDebugDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllFiles,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.course.code,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Spacer(),
                                if (widget.course.lecturer != null)
                                  Chip(
                                    avatar: const Icon(Icons.person, size: 16),
                                    label: Text('Dr. ${widget.course.lecturer!.lastName}'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(widget.course.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            if (widget.course.description != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(widget.course.description!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.grey[600])),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Files section
                    Row(
                      children: [
                        Icon(Icons.folder, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text('Course Files (${_files.length})',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_errorMessage != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_errorMessage!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      )
                    else if (_files.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                const Text('No files available'),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _files.map((file) {
                          return FileListItem(
                            file: file,
                            onTap: () => _openFile(file),
                            onDownload: () => _downloadFile(file),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _openFile(FileModel file) async {
    final success = await _fileService.openFile(file);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadFile(FileModel file) async {
    final url = 'http://192.168.1.155:5000/api/files/${file.id}/download';
    final success = await _fileService.downloadFileFromUrl(url, file);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(success ? 'File downloaded successfully' : 'Download failed'),
            backgroundColor: success ? Colors.green : Colors.red),
      );
    }
  }
}
