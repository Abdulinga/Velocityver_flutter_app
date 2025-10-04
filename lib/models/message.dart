import 'base_model.dart';
import 'user.dart';

class Message extends BaseModel {
  String content;
  String senderId;
  String? receiverId; // null for group messages
  String? chatRoomId; // for group chats (lecturers + admins)
  MessageType messageType;
  String? fileId; // if message contains a file
  String? fileName;
  String? fileUrl;
  bool isRead;
  bool isDelivered;
  DateTime? readAt;
  DateTime? deliveredAt;

  // Related objects
  User? sender;
  User? receiver;

  Message({
    super.id,
    required this.content,
    required this.senderId,
    this.receiverId,
    this.chatRoomId,
    this.messageType = MessageType.text,
    this.fileId,
    this.fileName,
    this.fileUrl,
    this.isRead = false,
    this.isDelivered = false,
    this.readAt,
    this.deliveredAt,
    super.createdAt,
    super.updatedAt,
    super.lastSync,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_sync': lastSync,
    };
    json.addAll({
      'content': content,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'chat_room_id': chatRoomId,
      'message_type': messageType.name,
      'file_id': fileId,
      'file_name': fileName,
      'file_url': fileUrl,
      'is_read': isRead ? 1 : 0,
      'is_delivered': isDelivered ? 1 : 0,
      'read_at': readAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
    });
    return json;
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    final message = Message(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      senderId: json['sender_id'] ?? '',
      receiverId: json['receiver_id'],
      chatRoomId: json['chat_room_id'],
      messageType: MessageType.values.firstWhere(
        (type) => type.name == json['message_type'],
        orElse: () => MessageType.text,
      ),
      fileId: json['file_id'],
      fileName: json['file_name'],
      fileUrl: json['file_url'],
      isRead: (json['is_read'] ?? 0) == 1,
      isDelivered: (json['is_delivered'] ?? 0) == 1,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
    );
    message.baseFromJson(json);
    return message;
  }

  bool get isFileMessage => messageType == MessageType.file && fileId != null;
  bool get isGroupMessage => chatRoomId != null;
  bool get isPrivateMessage => receiverId != null && chatRoomId == null;

  String get displayContent {
    switch (messageType) {
      case MessageType.file:
        return fileName != null ? '📎 $fileName' : '📎 File attachment';
      case MessageType.text:
        return content;
    }
  }

  @override
  String toString() {
    return 'Message(id: $id, sender: $senderId, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
  }
}

enum MessageType { text, file }

class ChatRoom extends BaseModel {
  String name;
  String description;
  List<String> participantIds; // user IDs
  String? lastMessageId;
  DateTime? lastActivity;
  bool isActive;

  // Related objects
  List<User> participants = [];
  Message? lastMessage;

  ChatRoom({
    super.id,
    required this.name,
    required this.description,
    required this.participantIds,
    this.lastMessageId,
    this.lastActivity,
    this.isActive = true,
    super.createdAt,
    super.updatedAt,
    super.lastSync,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_sync': lastSync,
    };
    json.addAll({
      'name': name,
      'description': description,
      'participant_ids': participantIds.join(','),
      'last_message_id': lastMessageId,
      'last_activity': lastActivity?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    });
    return json;
  }

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final chatRoom = ChatRoom(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      participantIds: (json['participant_ids'] as String?)?.split(',') ?? [],
      lastMessageId: json['last_message_id'],
      lastActivity: json['last_activity'] != null
          ? DateTime.parse(json['last_activity'])
          : null,
      isActive: (json['is_active'] ?? 1) == 1,
    );
    chatRoom.baseFromJson(json);
    return chatRoom;
  }

  bool hasParticipant(String userId) => participantIds.contains(userId);

  @override
  String toString() {
    return 'ChatRoom(id: $id, name: $name, participants: ${participantIds.length})';
  }
}
