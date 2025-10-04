import 'package:flutter/material.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import 'chat_room_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LecturerChatScreen extends StatefulWidget {
  const LecturerChatScreen({super.key});

  @override
  State<LecturerChatScreen> createState() => _LecturerChatScreenState();
}

class _LecturerChatScreenState extends State<LecturerChatScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final ChatService _chatService = ChatService();
  
  List<ChatRoom> _chatRooms = [];
  List<User> _lecturersAndAdmins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatData();
  }

Future<void> _loadChatData() async {
  setState(() => _isLoading = true);

  try {
    final user = _authService.currentUser!;

    // ✅ Fetch chat rooms for this lecturer/admin
    final chatRoomsResponse = await http.get(
      Uri.parse('http://192.168.1.155:5000/api/users/${user.id}/chat-rooms'),
    );

    if (chatRoomsResponse.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(chatRoomsResponse.body);
      _chatRooms = jsonList.map((c) => ChatRoom.fromJson(c)).toList();
    } else {
      debugPrint('❌ Failed to fetch chat rooms: ${chatRoomsResponse.body}');
      _chatRooms = [];
    }

    // ✅ Fetch all lecturers & admins
    final staffResponse = await http.get(
      Uri.parse('http://192.168.1.155:5000/api/users/staff'),
    );

    if (staffResponse.statusCode == 200) {
      final List<dynamic> staffJson = jsonDecode(staffResponse.body);
      _lecturersAndAdmins = staffJson.map((u) => User.fromJson(u)).toList();

      // Remove current user
      _lecturersAndAdmins.removeWhere((u) => u.id == user.id);
    } else {
      debugPrint('❌ Failed to fetch staff list: ${staffResponse.body}');
      _lecturersAndAdmins = [];
    }

  } catch (e) {
    debugPrint('⚠️ Error loading chat data: $e');
    _chatRooms = [];
    _lecturersAndAdmins = [];
  } finally {
    setState(() => _isLoading = false);
  }
}

  void _openChatRoom(ChatRoom chatRoom) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(chatRoom: chatRoom),
      ),
    ).then((_) => _loadChatData());
  }

  void _startDirectMessage(User user) async {
    try {
      final currentUser = _authService.currentUser!;
      
      // Check if a direct chat already exists
      final existingChat = await _chatService.getDirectChat(currentUser.id, user.id);
      
      if (existingChat != null) {
        _openChatRoom(existingChat);
      } else {
        // Create new direct chat
        final newChat = await _chatService.createDirectChat(currentUser.id, user.id);
        _openChatRoom(newChat);
      }
    } catch (e) {
      debugPrint('Error starting direct message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _createGroupChat() {
    showDialog(
      context: context,
      builder: (context) => _CreateGroupChatDialog(
        availableUsers: _lecturersAndAdmins,
        onCreateChat: (name, description, participantIds) async {
          try {
            final currentUser = _authService.currentUser!;
            participantIds.add(currentUser.id); // Add current user
            
            final chatRoom = await _chatService.createGroupChat(
              name: name,
              description: description,
              participantIds: participantIds,
              createdBy: currentUser.id,
            );
            
            await _loadChatData();
            _openChatRoom(chatRoom);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to create group chat: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _createGroupChat,
            tooltip: 'Create Group Chat',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChatData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Colors.deepPurple,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.deepPurple,
                    tabs: [
                      Tab(icon: Icon(Icons.chat), text: 'Chats'),
                      Tab(icon: Icon(Icons.people), text: 'Contacts'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildChatsTab(),
                        _buildContactsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildChatsTab() {
    if (_chatRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No chats yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation with colleagues',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _chatRooms.length,
      itemBuilder: (context, index) {
        final chatRoom = _chatRooms[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.shade100,
              child: Icon(
                chatRoom.participantIds.length > 2 ? Icons.group : Icons.person,
                color: Colors.deepPurple.shade700,
              ),
            ),
            title: Text(
              chatRoom.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              chatRoom.lastMessage?.displayContent ?? 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (chatRoom.lastActivity != null)
                  Text(
                    _formatTime(chatRoom.lastActivity!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${chatRoom.participantIds.length}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () => _openChatRoom(chatRoom),
          ),
        );
      },
    );
  }

  Widget _buildContactsTab() {
    if (_lecturersAndAdmins.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No contacts available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _lecturersAndAdmins.length,
      itemBuilder: (context, index) {
        final user = _lecturersAndAdmins[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                '${user.firstName[0]}${user.lastName[0]}',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text('${user.firstName} ${user.lastName}'),
            subtitle: Text(user.role?.name ?? 'Unknown Role'),
            trailing: IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () => _startDirectMessage(user),
              tooltip: 'Start Chat',
            ),
            onTap: () => _startDirectMessage(user),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}

class _CreateGroupChatDialog extends StatefulWidget {
  final List<User> availableUsers;
  final Function(String name, String description, List<String> participantIds) onCreateChat;

  const _CreateGroupChatDialog({
    required this.availableUsers,
    required this.onCreateChat,
  });

  @override
  State<_CreateGroupChatDialog> createState() => _CreateGroupChatDialogState();
}

class _CreateGroupChatDialogState extends State<_CreateGroupChatDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedUserIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Group Chat'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select Participants:'),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.availableUsers.length,
                itemBuilder: (context, index) {
                  final user = widget.availableUsers[index];
                  return CheckboxListTile(
                    title: Text('${user.firstName} ${user.lastName}'),
                    subtitle: Text(user.role?.name ?? 'Unknown Role'),
                    value: _selectedUserIds.contains(user.id),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedUserIds.add(user.id);
                        } else {
                          _selectedUserIds.remove(user.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _nameController.text.trim().isNotEmpty && _selectedUserIds.isNotEmpty
              ? () {
                  widget.onCreateChat(
                    _nameController.text.trim(),
                    _descriptionController.text.trim(),
                    _selectedUserIds.toList(),
                  );
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
