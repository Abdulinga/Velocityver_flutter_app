import 'package:flutter/material.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../widgets/file_list_item.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LecturerFilesScreen extends StatefulWidget {
  const LecturerFilesScreen({super.key});

  @override
  State<LecturerFilesScreen> createState() => _LecturerFilesScreenState();
}

class _LecturerFilesScreenState extends State<LecturerFilesScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  
  List<FileModel> _uploadedFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();
  }

 Future<void> _loadUploadedFiles() async {
  setState(() => _isLoading = true);

  try {
    final user = _authService.currentUser!;

    // ✅ Fetch files uploaded by this lecturer from the server
    final response = await http.get(
      Uri.parse('http://192.168.1.155:5000/api/files/uploaded_by/${user.id}'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> filesJson = jsonDecode(response.body);
      _uploadedFiles = filesJson.map((f) => FileModel.fromJson(f)).toList();
    } else {
      debugPrint('❌ Failed to fetch uploaded files: ${response.body}');
      _uploadedFiles = [];
    }
  } catch (e) {
    debugPrint('⚠️ Error loading uploaded files: $e');
    _uploadedFiles = [];
  } finally {
    setState(() => _isLoading = false);
  }
}

  List<FileModel> get _filteredFiles {
    if (_searchQuery.isEmpty) return _uploadedFiles;
    
    return _uploadedFiles.where((file) {
      return file.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             file.description?.toLowerCase().contains(_searchQuery.toLowerCase()) == true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Files'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUploadedFiles,
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
                hintText: 'Search files...',
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

          // Files list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty 
                                  ? 'No files uploaded yet'
                                  : 'No files match your search',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Upload files through course management'
                                  : 'Try a different search term',
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredFiles.length,
                        itemBuilder: (context, index) {
                          final file = _filteredFiles[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: FileListItem(
                              file: file,
                              onTap: () {
                                // Open file
                              },
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit':
                                      // Edit file details
                                      break;
                                    case 'download':
                                      // Download file
                                      break;
                                    case 'delete':
                                      // Delete file
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
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
                                    value: 'download',
                                    child: Row(
                                      children: [
                                        Icon(Icons.download),
                                        SizedBox(width: 8),
                                        Text('Download'),
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
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
