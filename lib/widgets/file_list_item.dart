import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class FileListItem extends StatelessWidget {
  final FileModel? file;
  final String? fileName;   // ✅ Added
  final int? fileSize;      // ✅ Added
  final VoidCallback? onTap;
  final bool showActions;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;
  final Widget? trailing;

  const FileListItem({
    super.key,
    this.file,
    this.fileName,   // ✅ New optional
    this.fileSize,   // ✅ New optional
    this.onTap,
    this.showActions = false,
    this.onDelete,
    this.onDownload,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = file?.originalName ?? fileName ?? "Unnamed File";
    final displaySize =
        file?.formattedSize ?? _formatSize(fileSize ?? 0);
    final createdAt = file?.createdAt ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getFileTypeColor(displayName),
          child: Icon(_getFileTypeIcon(displayName), color: Colors.white, size: 20),
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (file?.description != null && file!.description!.isNotEmpty)
              Text(
                file!.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  displaySize,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Text('•', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(width: 8),
                Text(
                  _formatDate(createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const Spacer(),
                if (file != null && !file!.isSynced)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Local',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: trailing ??
            (showActions
                ? PopupMenuButton<String>(
                    onSelected: (value) => _handleAction(context, value),
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
                      if (onDownload != null)
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
                        value: 'info',
                        child: Row(
                          children: [
                            Icon(Icons.info),
                            SizedBox(width: 8),
                            Text('Info'),
                          ],
                        ),
                      ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                : const Icon(Icons.arrow_forward_ios, size: 16)),
        onTap: onTap,
        isThreeLine: file?.description != null && file!.description!.isNotEmpty,
      ),
    );
  }

  // 🔹 Helpers now accept raw files too
  IconData _getFileTypeIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) return Icons.image;
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['doc', 'docx', 'txt', 'rtf'].contains(ext)) return Icons.description;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return Icons.table_chart;
    if (['ppt', 'pptx'].contains(ext)) return Icons.slideshow;
    return Icons.insert_drive_file;
  }

  Color _getFileTypeColor(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) return Colors.green;
    if (ext == 'pdf') return Colors.red;
    if (['doc', 'docx', 'txt', 'rtf'].contains(ext)) return Colors.blue;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return Colors.orange;
    if (['ppt', 'pptx'].contains(ext)) return Colors.purple;
    return Colors.grey;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'open':
        onTap?.call();
        break;
      case 'download':
        onDownload?.call();
        break;
      case 'info':
        _showFileInfo(context);
        break;
      case 'delete':
        _showDeleteDialog(context);
        break;
    }
  }

  void _showFileInfo(BuildContext context) {
    final displayName = file?.originalName ?? fileName ?? "Unnamed File";
    final displaySize = file?.formattedSize ?? _formatSize(fileSize ?? 0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Size', displaySize),
            if (file != null) ...[
              _buildInfoRow('Type', file!.mimeType),
              _buildInfoRow(
                'Uploaded',
                DateFormat('MMM d, y at h:mm a').format(file!.createdAt),
              ),
              if (file!.uploader != null)
                _buildInfoRow('Uploaded by', file!.uploader!.fullName),
              if (file!.course != null)
                _buildInfoRow('Course', file!.course!.fullName),
              _buildInfoRow('Status', file!.isSynced ? 'Synced' : 'Local only'),
              if (file!.description != null && file!.description!.isNotEmpty)
                _buildInfoRow('Description', file!.description!),
            ],
          ],
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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

  void _showDeleteDialog(BuildContext context) {
    final displayName = file?.originalName ?? fileName ?? "Unnamed File";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text(
          'Are you sure you want to delete "$displayName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete?.call();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ✅ Added helper for raw files
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
