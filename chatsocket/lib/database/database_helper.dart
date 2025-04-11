import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatsocket/models/user.dart';
import 'package:chatsocket/models/message.dart';
import 'package:chatsocket/models/chat.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  DatabaseHelper._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'chat_app.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            email TEXT,
            first_name TEXT,
            last_name TEXT,
            jwt_token TEXT,
            public_key TEXT,
            private_key TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE chats(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            chat_username TEXT NOT NULL,
            latest_message TEXT DEFAULT 'No messages yet',
            public_key TEXT NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
          );
        ''');

        await db.execute('''
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            user_id INTEGER NOT NULL,
            chat_id INTEGER NOT NULL,
            type INTEGER NOT NULL DEFAULT 0,  -- 0 for received, 1 for sent
            read INTEGER NOT NULL DEFAULT 0,  -- 0 for false, 1 for true
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY(chat_id) REFERENCES chats(id) ON DELETE CASCADE
          );
        ''');

        // Trigger to auto-update `updated_at` when `latest_message` changes
        await db.execute('''
          CREATE TRIGGER update_chat_timestamp
          AFTER UPDATE OF latest_message ON chats
          BEGIN
            UPDATE chats SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
          END;
        ''');
      },
    );
  }

  // Retrieve the logged-in user ID from SharedPreferences
  Future<int> getLoggedInUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id') ?? -1; // Default to -1 if not found
  }

  // Insert a User
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Fetch all users
  Future<List<User>> getUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return maps.map((map) => User.fromMap(map)).toList();
  }

  // Get user by username
  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  // Insert a new Chat (Automatically uses logged-in user)
  Future<Chat?> insertChat(String chatUsername, String publicKey) async {
    print("Save new chat called");
    final db = await database;
    int userId = await getLoggedInUserId();
    print("db logged in user id $userId");
    if (userId == -1) return null; // User ID not found, don't insert
    print("insert chat user id: $userId");

    // Insert the new chat into the 'chats' table and get the inserted chatId
    int chatId = await db.insert('chats', {
      'user_id': userId,
      'chat_username': chatUsername,
      'latest_message': 'No messages yet',
      'public_key': publicKey,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Retrieve the newly inserted chat from the database using its chatId
    Chat chat = await getChatById(chatId);

    return chat; // Return the complete Chat object
  }

  Future<Chat> getChatById(int chatId) async {
    final db = await database;

    // Query the 'chats' table to retrieve the chat by its ID
    List<Map<String, dynamic>> results = await db.query(
      'chats',
      where: 'id = ?',
      whereArgs: [chatId],
    );

    if (results.isNotEmpty) {
      // Assuming the Chat object is constructed using these fields
      print("getchatbyid results: $results");
      return Chat(
        id: results[0]['id'],
        userId: results[0]['user_id'],
        chatUsername: results[0]['chat_username'],
        latestMessage: results[0]['latest_message'],
        updatedAt: DateTime.tryParse(
          results[0]['updated_at'],
        ), // ✅ Convert string to DateTime
        publicKey: results[0]['public_key'],
      );
    } else {
      throw Exception("Chat not found");
    }
  }

  // Get all chats for the logged-in user
  Future<List<Chat>> getChatsForLoggedInUser() async {
    final db = await database;
    int userId = await getLoggedInUserId();
    if (userId == -1) return []; // No user logged in
    print("logged in user id ${userId}");

    final List<Map<String, dynamic>> maps = await db.query(
      'chats',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC', // Most recent chats first
    );
    return maps.map((map) => Chat.fromMap(map)).toList();
  }

  // Insert a Message (Uses logged-in user ID)
  // Insert a Message (Uses logged-in user ID)
  Future<int> insertMessage(Message message, DateTime createdAt) async {
    print("Save message on db called");
    final db = await database;
    int userId = await getLoggedInUserId();
    if (userId == -1) return 0; // No user logged in

    // Fetch chat details to get the sender
    List<Map<String, dynamic>> chatData = await db.query(
      'chats',
      columns: ['chat_username'],
      where: 'id = ?',
      whereArgs: [message.chatId],
    );

    if (chatData.isEmpty) {
      print("Chat not found for message insertion.");
      return 0;
    }

    String chatSender = chatData.first['chat_username'];
    print("Sender: $chatSender"); // Debugging print

    int messageId = await db.insert('messages', {
      'text': message.text,
      'user_id': userId,
      'chat_id': message.chatId,
      'type': message.type ? 1 : 0, // Insert the type field
      'created_at': createdAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    print("Message inserted with ID: $messageId");

    // Update latest message in Chat (Trigger will update `updated_at`)
    int updateCount = await db.update(
      'chats',
      {
        'latest_message':
            message.text.length > 16
                ? '${message.text.substring(0, 16)}...'
                : message.text,
      },
      where: 'id = ?',
      whereArgs: [message.chatId],
    );

    print("Rows updated in chats table: $updateCount"); // Debugging print

    return messageId;
  }

  // Update User
  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'username = ?',
      whereArgs: [user.username],
    );
  }

  // Get all messages for a chat (For logged-in user)
  Future<List<Message>> getMessagesByChat(int chatId) async {
    final db = await database;
    int userId = await getLoggedInUserId();
    if (userId == -1) return []; // No user logged in

    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'chat_id = ? AND user_id = ?',
      whereArgs: [chatId, userId],
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<int?> getChatIdByUsername(String chatUsername, int userId) async {
    final db =
        await database; // Assuming you have a method to get the database instance

    // Query the database to find the chatId by username
    final List<Map<String, dynamic>> result = await db.query(
      'chats', // Assuming 'chats' is the table name
      where:
          'chat_username = ? AND user_id = ?', // The column name for the username
      whereArgs: [chatUsername, userId],
    );

    if (result.isNotEmpty) {
      return result.first['id'] as int?;
    } else {
      return null; // Return null if no matching chat found
    }
  }

  Future<Chat?> getChatByUsername(String chatUsername, int userId) async {
    final db =
        await database; // Assuming you have a method to get the database instance

    // Query the database to find the chatId by username
    final List<Map<String, dynamic>> result = await db.query(
      'chats', // Assuming 'chats' is the table name
      where:
          'chat_username = ? AND user_id = ?', // The column name for the username
      whereArgs: [chatUsername, userId],
    );

    if (result.isNotEmpty) {
      return Chat.fromMap(result.first);
    } else {
      return null; // Return null if no matching chat found
    }
  }

  // Get the last 20 messages for a chat (initial load)
  Future<List<Message>> getLastMessagesByChat(int chatId, int limit) async {
    final db = await database;
    int userId = await getLoggedInUserId();
    if (userId == -1) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'chat_id = ? AND user_id = ?',
      whereArgs: [chatId, userId],
      orderBy: 'created_at DESC', // Newest first
      limit: limit,
    );

    return maps.map((map) => Message.fromMap(map)).toList().reversed.toList();
  }

  // Get older messages before a specific message ID (pagination)
  Future<List<Message>> getOlderMessagesByChat(
    int chatId,
    int lastMessageId,
    int limit,
  ) async {
    final db = await database;
    int userId = await getLoggedInUserId();
    if (userId == -1) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'chat_id = ? AND user_id = ? AND id < ?',
      whereArgs: [chatId, userId, lastMessageId],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((map) => Message.fromMap(map)).toList().reversed.toList();
  }

  Future<void> insertMessagesBulk(List<Message> messages) async {
    final db = await database;

    // Begin a transaction for bulk insert
    await db.transaction((txn) async {
      // Create a batch insert
      Batch batch = txn.batch();

      // Loop through all messages
      for (var i = 0; i < messages.length; i++) {
        var message = messages[i];

        // Add message to batch insert
        batch.insert(
          'messages',
          message.toMap(includeCreatedAt: true), // Ensure to include createdAt
          conflictAlgorithm:
              ConflictAlgorithm.replace, // Handle duplicates if any
        );

        // Check if this is the last message in the list
        if (i == messages.length - 1) {
          // Fetch chat details to get the sender
          List<Map<String, dynamic>> chatData = await txn.query(
            'chats',
            columns: [
              'chat_username',
            ], // Assuming `chat_username` stores the sender
            where: 'id = ?',
            whereArgs: [message.chatId],
          );

          if (chatData.isNotEmpty) {
            String chatSender = chatData.first['chat_username'];
            print("Sender: $chatSender"); // Debugging print

            // Update the `latest_message` for the chat with the last message
            await txn.update(
              'chats',
              {
                'latest_message':
                    message.text.length > 16
                        ? '${message.text.substring(0, 16)}...'
                        : message.text,
              },
              where: 'id = ?',
              whereArgs: [message.chatId],
            );
          }
        }
      }

      // Commit the batch
      await batch.commit(noResult: true);
    });
  }

  Future<void> updateUserJwt(String token, int userId) async {
    final db = await database;

    // Update the JWT field for the user with the given userId
    await db.update(
      'users', // Name of your users table
      {'jwt': token}, // Setting the 'jwt' field to the new token
      where: 'id = ?', // Condition to find the user by userId
      whereArgs: [userId], // The value for the userId parameter
    );
  }

  Future<void> deleteChatById(int chatId) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('chats', where: 'id = ?', whereArgs: [chatId]);
    });

    print("Chat with ID $chatId and its messages deleted.");
  }
}
