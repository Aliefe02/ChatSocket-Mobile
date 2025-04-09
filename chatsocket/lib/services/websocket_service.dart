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
    var data = jsonDecode(rawMessage);
    String sender = data['sender'];
    String msg = data['message'];

    print("[websocket] Received message from $sender: $msg"); // Debugging

    if (!_chats.contains(sender)) {
      await createNewChat(sender);
    }

    // Update the latest message in memory
    updateLatestMessage(sender, msg);

    // Notify listeners (to update UI)
    if (_messageListeners.isNotEmpty) {
      for (var listener in _messageListeners) {
        listener(sender, msg); // This should call _onMessageReceived
      }
    } else {
      int userId = await getLoggedInUserId();

      Message receivedMessage = Message(
        userId: userId,
        text: msg,
        type: false, // Received by the user
        chatId: getChatIdByUsername(sender) ?? -1,
      );
      await DatabaseHelper.instance.insertMessage(receivedMessage);
    }
  }

  void sendMessage(String message, String recipient) async {
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
      updateLatestMessage(recipient, message); // Update UI and memory
    } else {
      print("WebSocket is not connected.");
    }
  }

  Future<void> createNewChat(String username) async {
    int userId = await getLoggedInUserId();
    if (!_chats.contains(username)) {
      _chats.add(username);

      // Retrieve the chatId
      int? chatId = await DatabaseHelper.instance.getChatIdByUsername(
        username,
        userId,
      );

      // Use null-aware assignment to insert the chat if chatId is null
      chatId ??= await DatabaseHelper.instance.insertChat(username) ?? -1;
      print(chatId);

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
          print(sender);

          int? chatId = await DatabaseHelper.instance.getChatIdByUsername(
            sender,
            userId,
          );
          print(chatId);

          chatId ??= await DatabaseHelper.instance.insertChat(sender) ?? -1;

          List<Message> messagesToSave = [];

          for (var message in senderMessages) {
            String messageText = message[0];
            String sentAt = message[1];

            DateTime createdAt = DateTime.parse(sentAt);

            Message receivedMessage = Message(
              userId: userId,
              text: messageText,
              type: false,
              createdAt: createdAt,
              chatId: chatId,
            );
            messagesToSave.add(receivedMessage);
          }
          print(chatId);
          print(messagesToSave);

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
