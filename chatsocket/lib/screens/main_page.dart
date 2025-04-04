import 'package:chatsocket/models/chat.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatsocket/services/websocket_service.dart';
import 'chat_screen.dart';
import 'profile_page.dart';
import 'package:chatsocket/database/database_helper.dart';
// import 'package:chatsocket/models/message.dart';
import 'package:chatsocket/models/user.dart';

class MainPage extends StatefulWidget {
  final String username;

  MainPage({required this.username});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final WebSocketService _webSocketService = WebSocketService.getInstance();
  bool _showInputBox = false;
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _webSocketService.connect();
    _webSocketService.addListener(_updateChats, "main");
    _loadAndPrintUsers();
    _loadAndPrintChats();
    _loadChats();
  }

  Future<void> _loadChats() async {
    int userId = await getLoggedInUserId();
    if (userId != -1) {
      await _webSocketService.loadChatsFromDatabase(userId);
      setState(() {});
    }
  }

  void _updateChats(String sender, String message) {
    if (mounted) {
      setState(() {
        // Update the UI with new messages or chat state if necessary
      });
    }
  }

  Future<int> getLoggedInUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id') ?? -1; // Default to -1 if not found
  }

  void _startNewChat() {
    String newUsername = _usernameController.text.trim();
    if (newUsername.isNotEmpty) {
      if (!_webSocketService.getChatUsers().contains(newUsername)) {
        _webSocketService.createNewChat(
          newUsername,
        ); // Create a new chat if it doesn't exist
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(username: newUsername),
        ),
      );
      _usernameController.clear();
      setState(() {
        _showInputBox = false;
      });
    }
  }

  Future<void> _loadAndPrintUsers() async {
    // Get the users from the database
    List<User> users = await DatabaseHelper.instance.getUsers();

    // Print user details to the console
    for (var user in users) {
      print(
        'id: ${user.id}, User: ${user.username}, Email: ${user.email}, name: ${user.firstName}, surname: ${user.lastName}, jwtToken: ${user.jwtToken}',
      );
    }
  }

  Future<void> _loadAndPrintChats() async {
    // Get the users from the database
    List<Chat> chats = await DatabaseHelper.instance.getChatsForLoggedInUser();

    // Print user details to the console
    for (var chat in chats) {
      print(
        'id: ${chat.id}, User: ${chat.chatUsername}, latest message: ${chat.latestMessage}',
      );
    }
  }

  @override
  void dispose() {
    _webSocketService.removeListener(_updateChats, "main");
    _webSocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> chatUsers = _webSocketService.getChatUsers();

    return Scaffold(
      appBar: AppBar(title: Text('ChatSocket'), elevation: 0),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hello ${widget.username}',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 18, 194, 86),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.add, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _showInputBox = !_showInputBox;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 18, 194, 86),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.account_circle, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfilePage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_showInputBox)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: "Enter username...",
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 20),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _startNewChat,
                    backgroundColor: Color.fromARGB(255, 18, 194, 86),
                    child: Icon(Icons.check, color: Colors.white),
                  ),
                ],
              ),
            ),
          // Wrap the ListView.builder with Scrollbar widget
          Expanded(
            child: Scrollbar(
              controller: ScrollController(),
              thickness: 4.0, // Set thickness for a thinner scrollbar
              radius: Radius.circular(
                10,
              ), // Optional: rounded corners for the scrollbar
              child: ListView.builder(
                itemCount: chatUsers.length,
                itemBuilder: (context, index) {
                  String username = chatUsers[index];
                  String lastMessage = _webSocketService.getLastMessage(
                    username,
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 12.0, // Increased vertical space between chats
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2),
                            blurRadius: 6,
                            spreadRadius: 5,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                      child: ListTile(
                        title: Text(
                          username,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          lastMessage,
                          style: TextStyle(color: Colors.white70),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ChatScreen(username: username),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
