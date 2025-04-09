import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatsocket/services/websocket_service.dart';
import 'package:chatsocket/models/message.dart';
import 'package:chatsocket/database/database_helper.dart';

class ChatScreen extends StatefulWidget {
  final String username;

  ChatScreen({required this.username});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final WebSocketService _webSocketService = WebSocketService.getInstance();
  List<Message> _messages = [];
  bool _isLoadingMore = false; // To prevent multiple fetches
  int? _oldestMessageId; // Keep track of the oldest loaded message
  final int _pageSize = 20; // Number of messages per load

  @override
  void initState() {
    super.initState();
    _loadMessages();

    _webSocketService.addListener(_onMessageReceived, "chat");

    _scrollController.addListener(() {
      if (_scrollController.position.pixels <=
              _scrollController.position.minScrollExtent &&
          !_isLoadingMore) {
        // Trigger load more messages when you are at the top of the list
        _loadMoreMessages();
      }
    });
  }

  // Load messages from the WebSocket service and database
  Future<void> _loadMessages() async {
    final chatId = _webSocketService.getChatIdByUsername(widget.username);

    if (chatId == null) return; // Exit if no chatId is found

    final dbHelper = DatabaseHelper.instance;

    // Get last messages
    List<Message> messages = await dbHelper.getLastMessagesByChat(
      chatId,
      _pageSize,
    );

    setState(() {
      _messages = messages;
      if (_messages.isNotEmpty) {
        _oldestMessageId = _messages.first.id;
      }
    });

    // Scroll to bottom only if messages exist
    if (_messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  Future<void> _loadMoreMessages() async {
    print("Load more messages is called");
    final chatId = _webSocketService.getChatIdByUsername(widget.username);

    if (chatId == null || _isLoadingMore || _oldestMessageId == null) return;

    setState(() {
      _isLoadingMore = true;
    });
    print("is loading more set to true");

    final dbHelper = DatabaseHelper.instance;

    // Save the current scroll position before inserting messages
    double currentPosition = _scrollController.position.pixels;

    // Load older messages from the database
    List<Message> olderMessages = await dbHelper.getOlderMessagesByChat(
      chatId,
      _oldestMessageId!,
      _pageSize,
    );

    if (olderMessages.isNotEmpty) {
      setState(() {
        // Insert older messages at the top of the list
        _messages.insertAll(0, olderMessages);
        _oldestMessageId = _messages.first.id; // Update the oldest message ID
      });

      // After inserting messages, adjust the scroll position to maintain the previous position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Calculate the height of the newly added messages
        double newPosition =
            currentPosition + _calculateMessagesHeight(olderMessages);

        // Only adjust scroll position if it's valid
        if (newPosition < _scrollController.position.maxScrollExtent) {
          _scrollController.jumpTo(
            newPosition,
          ); // Keep the user in the same position
        }
      });
    }

    setState(() {
      _isLoadingMore = false;
    });
    print("load more messages ended");
  }

  double _calculateMessagesHeight(List<Message> messages) {
    // This is a rough estimation. You can adjust it based on the actual height of your messages
    const double messageHeight = 48; // Approximate height of each message
    return messages.length * messageHeight;
  }

  Future<int> getLoggedInUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id') ?? -1; // Default to -1 if not found
  }

  // Called when a new message is received through WebSocket
  void _onMessageReceived(String sender, String message) async {
    print("[chat_screen] Received message from $sender: $message");
    DateTime now = DateTime.now();
    int userId = await getLoggedInUserId();

    // Create a new Message object for the received message
    Message receivedMessage = Message(
      userId: userId,
      text: message,
      type: false, // Received by the user
      chatId: _webSocketService.getChatIdByUsername(widget.username) ?? -1,
    );

    // Add the received message to the local list
    if (mounted) {
      if (sender == widget.username) {
        setState(() {
          _messages.add(receivedMessage);
        });

        // Scroll to the bottom only if the user is already at the bottom
        if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent) {
          // If the list is already at the bottom, scroll to the bottom
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    }

    await DatabaseHelper.instance.insertMessage(receivedMessage, now);
  }

  // Send a message
  void _sendMessage() async {
    DateTime now = DateTime.now();
    // Marked the function as async
    if (_controller.text.isNotEmpty) {
      String message = _controller.text;

      int userId = await getLoggedInUserId();

      // Create a new Message object for the sent message
      Message newMessage = Message(
        userId: userId,
        text: message,
        type: true,
        chatId: _webSocketService.getChatIdByUsername(widget.username) ?? -1,
      );

      // Add the sent message to the local list
      setState(() {
        _messages.add(newMessage);
      });

      // Send the message through the WebSocket service
      _webSocketService.sendMessage(message, widget.username, now);

      // Clear the input field
      _controller.clear();

      // Insert the message into the database asynchronously
      await DatabaseHelper.instance.insertMessage(newMessage, now);

      // Scroll to the bottom of the chat
      _scrollToBottom();
    }
  }

  // Scroll to the bottom of the chat list
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // Scroll to the bottom of the ListView
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _webSocketService.removeListener(_onMessageReceived, "chat");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat with ${widget.username}')),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Wrap ListView in Scrollbar
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thickness: 4.0, // Set the thickness to make it thin
              radius: Radius.circular(10), // Optional: rounded corners
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  var message = _messages[index];
                  bool isSent = message.type;
                  return Align(
                    alignment:
                        isSent ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 250),
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isSent
                                ? Color.fromARGB(255, 18, 194, 86)
                                : Colors.grey[800],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              bottom: 25.0,
              top: 10.0,
              left: 15.0,
              right: 15.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color:
                              _focusNode.hasFocus
                                  ? Color.fromARGB(255, 18, 194, 86)
                                  : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color: Color.fromARGB(255, 18, 194, 86),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.white, width: 1.5),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical:
                            16, // Adjust the vertical padding to move it up
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 45, // Adjust the size of the circle
                    height: 40, // Adjust the size of the circle
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.fromARGB(255, 18, 194, 86), // Circle color
                    ),
                    child: Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20, // Icon size
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
