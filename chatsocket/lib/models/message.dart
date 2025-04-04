class Message {
  final int? id;
  final String text;
  final int userId;
  final int chatId;
  final bool type;
  final DateTime? createdAt; // Nullable since the DB auto-generates it

  Message({
    this.id,
    required this.text,
    required this.userId,
    required this.chatId,
    required this.type,
    this.createdAt, // Nullable
  });

  // Convert Message to Map (for storing in SQLite)
  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    final map = {
      'id': id,
      'text': text,
      'user_id': userId,
      'chat_id': chatId,
      'type': type ? 1 : 0,
    };

    // Only include `created_at` if explicitly requested (for reading from DB)
    if (includeCreatedAt && createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }

    return map;
  }

  // Convert Map to Message object (for reading from SQLite)
  static Message fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      text: map['text'],
      userId: map['user_id'],
      chatId: map['chat_id'],
      type: map['type'] == 1,
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'])
              : null, // Handle null case
    );
  }
}
