import 'package:flutter/material.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../widgets/file_list_item.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StudentDownloadsScreen extends StatefulWidget {
  const StudentDownloadsScreen({super.key});

  @override
  State<StudentDownloadsScreen> createState() => _StudentDownloadsScreenState();
}

class _StudentDownloadsScreenState extends State<StudentDownloadsScreen> {
  final FileService _fileService = FileService();
  final AuthService _authService = AuthService();
  
  List<FileModel> _downloadedFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

Future<void> _loadDownloadedFiles() async {
  setState(() => _isLoading = true);

  try {
    final user = _authService.currentUser!;
    
    // Fetch downloaded files from API
    final response = await http.get(
      Uri.parse('http://192.168.1.155:5000/api/files/downloaded?user_id=${user.id}'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> filesJson = jsonDecode(response.body);

      setState(() {
        _downloadedFiles = filesJson.map((f) => FileModel.fromJson(f)).toList();
        _isLoading = false;
      });
    } else {
      debugPrint('❌ Failed to fetch downloaded files: ${response.body}');
      setState(() {
        _downloadedFiles = [];
        _isLoading = false;
      });
    }
  } catch (e) {
    debugPrint('⚠️ Error loading downloaded files: $e');
    setState(() => _isLoading = false);
  }
}

  List<FileModel> get _filteredFiles {
    if (_searchQuery.isEmpty) return _downloadedFiles;
    
    return _downloadedFiles.where((file) {
      return file.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             file.description?.toLowerCase().contains(_searchQuery.toLowerCase()) == true;
    }).toList();
  }

  Future<void> _deleteDownload(FileModel file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download'),
        content: Text('Are you sure you want to delete "${file.name}" from your downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _fileService.deleteDownloadedFile(file.id);
        await _loadDownloadedFiles();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${file.name} deleted from downloads'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete file: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Downloads'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDownloadedFiles,
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
                hintText: 'Search downloaded files...',
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
                              Icons.download_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty 
                                  ? 'No downloaded files yet'
                                  : 'No files match your search',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Files you download will appear here'
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
                              onTap: () => _fileService.openFile(file),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'open':
                                      _fileService.openFile(file);
                                      break;
                                    case 'share':
                                      _fileService.shareFile(file);
                                      break;
                                    case 'delete':
                                      _deleteDownload(file);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'open',
                                    child: Row(
                                      children: [
                                        Icon(Icons.open_in_new),
                                        SizedBox(width: 8),
                                        Text('Open'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'share',
                                    child: Row(
                                      children: [
                                        Icon(Icons.share),
                                        SizedBox(width: 8),
                                        Text('Share'),
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
