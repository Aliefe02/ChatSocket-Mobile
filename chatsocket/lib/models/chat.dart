class Chat {
  final int? id;
  final int userId;
  final String chatUsername;
  final String latestMessage;
  final DateTime? updatedAt; // Nullable since the DB auto-generates it

  Chat({
    this.id,
    required this.userId,
    required this.chatUsername,
    required this.latestMessage,
    this.updatedAt, // Nullable
  });

  // Convert Chat to Map (for storing in SQLite)
  Map<String, dynamic> toMap({bool includeUpdatedAt = false}) {
    final map = {
      'id': id,
      'user_id': userId,
      'chat_username': chatUsername,
      'latest_message': latestMessage,
    };

    // Include `updated_at` only if explicitly requested (for reading from DB)
    if (includeUpdatedAt && updatedAt != null) {
      map['updated_at'] = updatedAt!.toIso8601String();
    }

    return map;
  }

  // Convert Map to Chat object (for reading from SQLite)
  static Chat fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'],
      userId: map['user_id'],
      chatUsername: map['chat_username'],
      latestMessage: map['latest_message'],
      updatedAt:
          map['updated_at'] != null
              ? DateTime.parse(map['updated_at'])
              : null, // Handle null case
    );
  }
}
