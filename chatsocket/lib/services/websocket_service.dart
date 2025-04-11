import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatsocket/constants.dart';
import 'package:chatsocket/database/database_helper.dart';
import 'package:chatsocket/models/chat.dart';
import 'package:chatsocket/models/message.dart';

typedef MessageCallback = void Function(String sender, String message);

class WebSocketService {
  static WebSocketService? _instance;
  WebSocket? _socket;
  String? _authToken;
  final List<MessageCallback> _listeners = [];
  final List<MessageCallback> _messageListeners = [];
  Map<String, List<String>> _chats = {};
  final Map<String, String> _latestMessages = {};
  final Map<String, int> chatUsernameToChatId = {};

  WebSocketService._privateConstructor();

  static WebSocketService getInstance() {
    _instance ??= WebSocketService._privateConstructor();
    return _instance!;
  }

  Future<void> connect() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('jwt_token');

    if (_authToken == null) {
      print("No auth token found, WebSocket connection aborted.");
      return;
    }

    try {
      // retrieveUnreceivedMessages();
      Uri uri = Uri.parse("$WS_URL/ws/chat?token=$_authToken");
      _socket = await WebSocket.connect(uri.toString());

      print("WebSocket connected successfully.");

      _socket!.listen(
        (message) {
          print("Received: $message");
          _handleIncomingMessage(message);
        },
        onError: (error) {
          print("WebSocket error: $error");
        },
        onDone: () {
          print("WebSocket connection closed.");
        },
      );
    } catch (e) {
      print("WebSocket connection error: $e");
    }
  }

  Future<int> getLoggedInUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id') ?? -1; // Default to -1 if not found
  }

  void _handleIncomingMessage(String rawMessage) async {
    DateTime now = DateTime.now();
    var data = jsonDecode(rawMessage);
    String sender = data['sender'];
    String msg = data['message'];

    print("[websocket] Received message from $sender: $msg"); // Debugging

    if (!_chats.containsKey(sender)) {
      String? publicKey = await _getUserPublicKey(sender);
      if (publicKey != null) {
        await createNewChat(sender, publicKey);
      } else {
        // Handle case
      }
    }

    // Update the latest message in memory
    updateLatestMessage(sender, msg, now);

    // Notify listeners (to update UI)
    if (_messageListeners.isNotEmpty) {
      for (var listener in _messageListeners) {
        listener(sender, msg); // This should call _onMessageReceived
      }
    } else {
      int userId = await getLoggedInUserId();

      Message receivedMessage = Message(
        read: false,
        userId: userId,
        text: msg,
        type: false, // Received by the user
        chatId: getChatIdByUsername(sender),
      );
      await DatabaseHelper.instance.insertMessage(receivedMessage, now);
    }
  }

  void sendMessage(String message, String recipient, DateTime sentAt) async {
    if (_socket != null) {
      // Send the message to the server
      _socket!.add(
        jsonEncode({
          "target": "sendMessage",
          "message": message,
          "recipient": recipient,
        }),
      );

      // Update the latest message in memory
      updateLatestMessage(recipient, message, sentAt); // Update UI and memory
    } else {
      print("WebSocket is not connected.");
    }
  }

  Future<void> createNewChat(String username, String publicKey) async {
    int userId = await getLoggedInUserId();
    print("logged in user id: $userId");

    // Check if the chat already exists in _chats
    if (!_chats.containsKey(username)) {
      // If the chat doesn't exist, retrieve it from the database or create a new one
      Chat? chat = await DatabaseHelper.instance.getChatByUsername(
        username,
        userId,
      );

      // If the chat is null (not found), create it and retrieve the Chat object
      chat ??= await DatabaseHelper.instance.insertChat(username, publicKey);

      // Add the chat to _chats if it's not already added
      if (chat != null) {
        _chats[username] = [
          chat.id.toString(), // chat ID
          chat.latestMessage, // latest message
          "0", // unread message count (default to 0)
          chat.updatedAt.toString(), // last updated datetime
        ];
        print("New chat created for $username with chatId ${chat.id}");
      }
    } else {
      print("Chat for $username already exists in _chats");
    }
  }

  void updateLatestMessage(
    String chatUsername,
    String latestMessage,
    DateTime updatedAt,
  ) {
    _chats[chatUsername]?[1] = latestMessage;
    _chats[chatUsername]?[3] = updatedAt.toString();

    sortChatsByUpdatedAt();

    // Notify listeners about the new latest message
    for (var listener in _listeners) {
      listener(chatUsername, latestMessage); // Update UI
    }
  }

  void clearChats() {
    _chats.clear();
    _latestMessages.clear();
  }

  Future<void> loadChatsFromDatabase(int userId) async {
    // Fetch chats from the database
    List<Chat> dbChats =
        await DatabaseHelper.instance.getChatsForLoggedInUser();

    // Iterate through each chat and map chatUsername to chatId
    for (Chat chat in dbChats) {
      if (!_chats.containsKey(chat.chatUsername)) {
        _chats[chat.chatUsername] = [
          chat.id.toString(), // chat ID
          chat.latestMessage, // latest message
          "0", // unread message count (default to 0)
          chat.updatedAt.toString(), // last updated datetime
        ];
        print(
          "Chat loaded: ${chat.chatUsername} with chatId ${chat.id}",
        ); // Debugging
      }
    }
  }

  Future<void> retrieveUnreceivedMessages(int userId) async {
    print("Retrieving messages");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('jwt_token');

    final url = Uri.parse("$BASE_URL/api/message/unreceived-messages");

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = jsonDecode(response.body);

        final result = parsed.map((key, value) {
          final List<List<String>> messages =
              (value as List)
                  .map<List<String>>((item) => List<String>.from(item))
                  .toList();
          return MapEntry(key, messages);
        });

        for (var sender in result.keys) {
          List<List<String>> senderMessages = result[sender]!;

          Chat? chat = await DatabaseHelper.instance.getChatByUsername(
            sender,
            userId,
          );

          if (chat == null) {
            String? publicKey = await _getUserPublicKey(sender);
            if (publicKey != null) {
              chat = await DatabaseHelper.instance.insertChat(
                sender,
                publicKey,
              );
            } else {
              // Handle case
            }
          }

          int chatId = chat?.id ?? -1;

          List<Message> messagesToSave = [];

          for (var message in senderMessages) {
            String messageText = message[0];
            String sentAt = message[1];

            DateTime createdAt = DateTime.parse(sentAt);

            Message receivedMessage = Message(
              read: false,
              userId: userId,
              text: messageText,
              type: false,
              createdAt: createdAt,
              chatId: chatId,
            );
            messagesToSave.add(receivedMessage);
          }

          await DatabaseHelper.instance.insertMessagesBulk(messagesToSave);
        }
        loadChatsFromDatabase(userId);
        return;
      } else {
        throw Exception(
          "Failed to load unreceived messages. Status code: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("Error retrieving unreceived messages: $e");
      rethrow;
    }
  }

  void addListener(MessageCallback callback, String location) {
    if (location == "main") {
      _listeners.add(callback);
    } else if (location == "chat") {
      _messageListeners.add(callback);
    }
  }

  void removeListener(MessageCallback callback, String location) {
    if (location == "main") {
      _listeners.remove(callback);
    } else if (location == "chat") {
      _messageListeners.remove(callback);
    }
  }

  void sortChatsByUpdatedAt() {
    // Convert _chats map to a list of Map entries
    var sortedChats = _chats.entries.toList();

    // Sort the list by the `updatedAt` value (String) in descending order
    sortedChats.sort((a, b) {
      // Convert the updatedAt strings to DateTime and compare them
      DateTime aDate = DateTime.parse(a.value[3]);
      DateTime bDate = DateTime.parse(b.value[3]);
      return bDate.compareTo(aDate); // Sorting in descending order
    });

    // Optionally, convert it back to a Map if you want
    _chats = Map.fromEntries(sortedChats);
  }

  Future<String?> _getUserPublicKey(username) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('jwt_token');

    final url = Uri.parse("$BASE_URL/api/user/exists?username=$username");

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['publicKey'];
    }
    return null;
  }

  void disconnect() {
    _socket?.close();
    _socket = null;
    print("WebSocket disconnected.");
  }

  Map<String, List<String>> getChatUsers() {
    sortChatsByUpdatedAt();
    return _chats;
  }

  int getChatIdByUsername(String username) {
    return int.parse(_chats[username]?[0] ?? "-1");
  }

  void deleteChatByUsername(String username) {
    _chats.remove(username);
  }

  String getLastMessage(String username) {
    return _chats[username]?[1] ?? "No messages yet";
  }
}
