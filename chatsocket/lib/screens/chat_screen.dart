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
  bool _isLoadingMore = false;
  int? _oldestMessageId;
  bool _isAtBottom = true; // Track if the user is at the bottom
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadMessages();

    _webSocketService.addListener(_onMessageReceived, "chat");

    _scrollController.addListener(() {
      if (_scrollController.position.pixels <=
              _scrollController.position.minScrollExtent &&
          !_isLoadingMore) {
        _loadMoreMessages();
      }

      // Detect if the user is at the bottom
      bool isAtBottom =
          _scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent;
      if (isAtBottom != _isAtBottom) {
        setState(() {
          _isAtBottom = isAtBottom;
        });
      }
    });
  }

  Future<void> _loadMessages() async {
    final chatId = _webSocketService.getChatIdByUsername(widget.username);

    if (chatId == -1) return;

    final dbHelper = DatabaseHelper.instance;
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

    if (_messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  Future<void> _loadMoreMessages() async {
    final chatId = _webSocketService.getChatIdByUsername(widget.username);

    if (chatId == -1 || _isLoadingMore || _oldestMessageId == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    double currentPosition = _scrollController.position.pixels;

    final dbHelper = DatabaseHelper.instance;

    List<Message> olderMessages = await dbHelper.getOlderMessagesByChat(
      chatId,
      _oldestMessageId!,
      _pageSize,
    );

    if (olderMessages.isNotEmpty) {
      setState(() {
        _messages.insertAll(0, olderMessages);
        _oldestMessageId = _messages.first.id;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        double newPosition =
            currentPosition + _calculateMessagesHeight(olderMessages);
        if (newPosition < _scrollController.position.maxScrollExtent) {
          _scrollController.jumpTo(newPosition);
        }
      });
    }

    setState(() {
      _isLoadingMore = false;
    });
  }

  double _calculateMessagesHeight(List<Message> messages) {
    const double messageHeight = 48;
    return messages.length * messageHeight;
  }

  Future<int> getLoggedInUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id') ?? -1;
  }

  void _onMessageReceived(String sender, String message) async {
    DateTime now = DateTime.now();
    int userId = await getLoggedInUserId();

    Message receivedMessage = Message(
      read: false,
      userId: userId,
      text: message,
      type: false,
      chatId: _webSocketService.getChatIdByUsername(widget.username),
    );

    if (mounted) {
      if (sender == widget.username) {
        setState(() {
          _messages.add(receivedMessage);
        });
        receivedMessage.read = true;

        if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    }

    await DatabaseHelper.instance.insertMessage(receivedMessage, now);
  }

  void _sendMessage() async {
    DateTime now = DateTime.now();
    if (_controller.text.isNotEmpty) {
      String message = _controller.text;
      int userId = await getLoggedInUserId();

      Message newMessage = Message(
        read: true,
        userId: userId,
        text: message,
        type: true,
        chatId: _webSocketService.getChatIdByUsername(widget.username),
      );

      setState(() {
        _messages.add(newMessage);
      });

      _webSocketService.sendMessage(message, widget.username, now);

      _controller.clear();
      await DatabaseHelper.instance.insertMessage(newMessage, now);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
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
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thickness: 4.0,
                  radius: Radius.circular(10),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      var message = _messages[index];
                      bool isSent = message.type;
                      return Align(
                        alignment:
                            isSent
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: 250),
                          margin: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
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
                            borderSide: BorderSide(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 45,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.fromARGB(255, 18, 194, 86),
                        ),
                        child: Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Scroll-to-bottom FAB
          if (!_isAtBottom)
            Positioned(
              right: 10,
              bottom: 120, // Adjust to appear above input area
              child: FloatingActionButton(
                onPressed: _scrollToBottom,
                backgroundColor: Colors.white,
                mini: true,
                child: Icon(Icons.arrow_downward, color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }
}
