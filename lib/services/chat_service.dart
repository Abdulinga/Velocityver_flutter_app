import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'database_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final Uuid _uuid = const Uuid();

  /// Get all chat rooms for a user
  Future<List<ChatRoom>> getUserChatRooms(String userId) async {
    try {
      final db = await _databaseService.database;

      final result = await db.query(
        'chat_rooms',
        where: 'participant_ids LIKE ? AND is_active = 1',
        whereArgs: ['%$userId%'],
        orderBy: 'last_activity DESC',
      );

      final chatRooms = <ChatRoom>[];
      for (final row in result) {
        final chatRoom = ChatRoom.fromJson(row);

        // Load last message if exists
        if (chatRoom.lastMessageId != null) {
          final messageResult = await db.query(
            'messages',
            where: 'id = ?',
            whereArgs: [chatRoom.lastMessageId],
            limit: 1,
          );

          if (messageResult.isNotEmpty) {
            chatRoom.lastMessage = Message.fromJson(messageResult.first);
          }
        }

        chatRooms.add(chatRoom);
      }

      return chatRooms;
    } catch (e) {
      debugPrint('Error getting user chat rooms: $e');
      return [];
    }
  }

  /// Get messages for a chat room
  Future<List<Message>> getChatMessages(String chatRoomId) async {
    try {
      final db = await _databaseService.database;

      final result = await db.query(
        'messages',
        where: 'chat_room_id = ?',
        whereArgs: [chatRoomId],
        orderBy: 'created_at ASC',
      );

      final messages = <Message>[];
      for (final row in result) {
        final message = Message.fromJson(row);

        // Load sender info
        final senderResult = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [message.senderId],
          limit: 1,
        );

        if (senderResult.isNotEmpty) {
          message.sender = User.fromJson(senderResult.first);
        }

        messages.add(message);
      }

      return messages;
    } catch (e) {
      debugPrint('Error getting chat messages: $e');
      return [];
    }
  }

  /// Send a message
  Future<Message> sendMessage(Message message) async {
    try {
      final db = await _databaseService.database;

      // Generate ID if not provided
      if (message.id.isEmpty) {
        message.id = _uuid.v4();
      }

      // Set timestamps
      final now = DateTime.now();
      message.createdAt = now;
      message.updatedAt = now;
      message.deliveredAt = DateTime.now();
      message.isDelivered = true;

      // Insert message
      await db.insert('messages', message.toJson());

      // Update chat room's last message and activity
      await db.update(
        'chat_rooms',
        {
          'last_message_id': message.id,
          'last_activity': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [message.chatRoomId],
      );

      debugPrint('✅ Message sent: ${message.id}');
      return message;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId, String userId) async {
    try {
      final db = await _databaseService.database;
      final now = DateTime.now().toIso8601String();

      await db.update(
        'messages',
        {'is_read': 1, 'read_at': now, 'updated_at': now},
        where: 'chat_room_id = ? AND sender_id != ? AND is_read = 0',
        whereArgs: [chatRoomId, userId],
      );
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Get or create direct chat between two users
  Future<ChatRoom?> getDirectChat(String userId1, String userId2) async {
    try {
      final db = await _databaseService.database;

      // Look for existing direct chat
      final result = await db.query(
        'chat_rooms',
        where: '''
          (participant_ids = ? OR participant_ids = ?) 
          AND is_active = 1
        ''',
        whereArgs: ['$userId1,$userId2', '$userId2,$userId1'],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return ChatRoom.fromJson(result.first);
      }

      return null;
    } catch (e) {
      debugPrint('Error getting direct chat: $e');
      return null;
    }
  }

  /// Create direct chat between two users
  Future<ChatRoom> createDirectChat(String userId1, String userId2) async {
    try {
      final db = await _databaseService.database;

      // Get user names for chat room name
      final user1Result = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId1],
        limit: 1,
      );
      final user2Result = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId2],
        limit: 1,
      );

      final user1 = user1Result.isNotEmpty
          ? User.fromJson(user1Result.first)
          : null;
      final user2 = user2Result.isNotEmpty
          ? User.fromJson(user2Result.first)
          : null;

      final chatRoomName = user1 != null && user2 != null
          ? '${user1.firstName} ${user1.lastName} & ${user2.firstName} ${user2.lastName}'
          : 'Direct Chat';

      final chatRoom = ChatRoom(
        id: _uuid.v4(),
        name: chatRoomName,
        description: 'Direct conversation',
        participantIds: [userId1, userId2],
        isActive: true,
      );

      final now = DateTime.now();
      chatRoom.createdAt = now;
      chatRoom.updatedAt = now;

      await db.insert('chat_rooms', chatRoom.toJson());

      debugPrint('✅ Direct chat created: ${chatRoom.id}');
      return chatRoom;
    } catch (e) {
      debugPrint('❌ Error creating direct chat: $e');
      rethrow;
    }
  }

  /// Create group chat
  Future<ChatRoom> createGroupChat({
    required String name,
    required String description,
    required List<String> participantIds,
    required String createdBy,
  }) async {
    try {
      final db = await _databaseService.database;

      final chatRoom = ChatRoom(
        id: _uuid.v4(),
        name: name,
        description: description,
        participantIds: participantIds,
        isActive: true,
      );

      final now = DateTime.now();
      chatRoom.createdAt = now;
      chatRoom.updatedAt = now;

      await db.insert('chat_rooms', chatRoom.toJson());

      // Send welcome message
      final welcomeMessage = Message(
        id: _uuid.v4(),
        content: 'Group chat "$name" created',
        senderId: createdBy,
        chatRoomId: chatRoom.id,
        messageType: MessageType.text,
        createdAt: now,
        updatedAt: now,
      );

      await sendMessage(welcomeMessage);

      debugPrint('✅ Group chat created: ${chatRoom.id}');
      return chatRoom;
    } catch (e) {
      debugPrint('❌ Error creating group chat: $e');
      rethrow;
    }
  }

  /// Get unread message count for user
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final db = await _databaseService.database;

      final result = await db.rawQuery(
        '''
        SELECT COUNT(*) as count FROM messages m
        INNER JOIN chat_rooms cr ON m.chat_room_id = cr.id
        WHERE cr.participant_ids LIKE ? 
        AND m.sender_id != ? 
        AND m.is_read = 0
        AND cr.is_active = 1
      ''',
        ['%$userId%', userId],
      );

      return result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('Error getting unread message count: $e');
      return 0;
    }
  }

  /// Initialize chat tables
  Future<void> initializeChatTables() async {
    try {
      final db = await _databaseService.database;

      // Create chat_rooms table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_rooms (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          participant_ids TEXT NOT NULL,
          last_message_id TEXT,
          last_activity TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT,
          updated_at TEXT,
          last_sync TEXT
        )
      ''');

      // Create messages table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS messages (
          id TEXT PRIMARY KEY,
          content TEXT NOT NULL,
          sender_id TEXT NOT NULL,
          receiver_id TEXT,
          chat_room_id TEXT,
          message_type TEXT DEFAULT 'text',
          file_id TEXT,
          file_name TEXT,
          file_url TEXT,
          is_read INTEGER DEFAULT 0,
          is_delivered INTEGER DEFAULT 0,
          read_at TEXT,
          delivered_at TEXT,
          created_at TEXT,
          updated_at TEXT,
          last_sync TEXT,
          FOREIGN KEY (sender_id) REFERENCES users (id),
          FOREIGN KEY (receiver_id) REFERENCES users (id),
          FOREIGN KEY (chat_room_id) REFERENCES chat_rooms (id)
        )
      ''');

      // Create indexes for better performance
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_chat_room ON messages (chat_room_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages (sender_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_chat_rooms_participants ON chat_rooms (participant_ids)',
      );

      debugPrint('✅ Chat tables initialized');
    } catch (e) {
      debugPrint('❌ Error initializing chat tables: $e');
      rethrow;
    }
  }
}
