import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatsocket/constants.dart';
import 'package:chatsocket/database/database_helper.dart';
import 'package:chatsocket/models/chat.dart';

typedef MessageCallback = void Function(String sender, String message);

class WebSocketService {
  static WebSocketService? _instance;
  WebSocket? _socket;
  String? _authToken;
  final List<MessageCallback> _listeners = [];
  final List<MessageCallback> _messageListeners = [];
  final List<String> _chats = [];
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
    var data = jsonDecode(rawMessage);
    String sender = data['sender'];
    String msg = data['message'];

    print("[websocket] Received message from $sender: $msg"); // Debugging

    if (!_chats.contains(sender)) {
      createNewChat(sender);
    }

    // Update the latest message in memory
    updateLatestMessage(sender, msg);

    // Notify listeners (to update UI)
    for (var listener in _messageListeners) {
      listener(sender, msg); // This should call _onMessageReceived
    }
  }

  void sendMessage(String message, String recipient) async {
    if (_socket != null) {
      // Send the message to the server
      _socket!.add(jsonEncode({"message": message, "recipient": recipient}));

      // Update the latest message in memory
      updateLatestMessage(recipient, message); // Update UI and memory
    } else {
      print("WebSocket is not connected.");
    }
  }

  void createNewChat(String username) async {
    if (!_chats.contains(username)) {
      _chats.add(username);

      // Insert the new chat into the database and get the chatId
      int chatId = await DatabaseHelper.instance.insertChat(username) ?? -1;

      // Store the chatUsername to chatId mapping
      chatUsernameToChatId[username] = chatId;

      print("New chat created: $username with chatId $chatId"); // Debugging
    }
  }

  void updateLatestMessage(String chatUsername, String latestMessage) {
    _latestMessages[chatUsername] = latestMessage;

    // Notify listeners about the new latest message
    for (var listener in _listeners) {
      listener(chatUsername, latestMessage); // Update UI
    }
  }

  void clearChats() {
    _chats.clear();
    _latestMessages.clear();
  }

  String getLastMessage(String username) {
    return _latestMessages[username] ?? 'No messages yet'; // Default message
  }

  Future<void> loadChatsFromDatabase(int userId) async {
    // Fetch chats from the database
    List<Chat> dbChats =
        await DatabaseHelper.instance.getChatsForLoggedInUser();

    // Iterate through each chat and map chatUsername to chatId
    for (Chat chat in dbChats) {
      if (!_chats.contains(chat.chatUsername)) {
        _chats.add(chat.chatUsername);
        _latestMessages[chat.chatUsername] = chat.latestMessage;

        // Map the chatUsername to chatId
        chatUsernameToChatId[chat.chatUsername] = chat.id ?? -1;

        print(
          "Chat loaded: ${chat.chatUsername} with chatId ${chat.id}",
        ); // Debugging
      }
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

  void disconnect() {
    _socket?.close();
    _socket = null;
    print("WebSocket disconnected.");
  }

  List<String> getChatUsers() {
    return _chats;
  }

  int? getChatIdByUsername(String username) {
    return chatUsernameToChatId[username];
  }
}
