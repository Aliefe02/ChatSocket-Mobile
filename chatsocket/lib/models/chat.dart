class Chat {
  final int? id;
  final int userId;
  final String chatUsername;
  final String latestMessage;
  final String publicKey;
  final DateTime? updatedAt;

  Chat({
    this.id,
    required this.userId,
    required this.chatUsername,
    required this.latestMessage,
    required this.publicKey,
    this.updatedAt,
  });

  Map<String, dynamic> toMap({bool includeUpdatedAt = false}) {
    final map = {
      'id': id,
      'user_id': userId,
      'chat_username': chatUsername,
      'latest_message': latestMessage,
      'public_key': publicKey,
    };

    if (includeUpdatedAt && updatedAt != null) {
      map['updated_at'] = updatedAt!.toIso8601String();
    }

    return map;
  }

  static Chat fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'],
      userId: map['user_id'],
      chatUsername: map['chat_username'],
      latestMessage: map['latest_message'],
      publicKey: map['public_key'],
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }
}
