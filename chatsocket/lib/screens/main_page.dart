import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatsocket/services/websocket_service.dart';
import 'chat_screen.dart';
import 'profile_page.dart';
import 'package:http/http.dart' as http;
import 'package:chatsocket/database/database_helper.dart';
import 'package:chatsocket/models/chat.dart';
import 'package:chatsocket/models/user.dart';
import 'package:chatsocket/constants.dart';

class MainPage extends StatefulWidget {
  final String username;

  MainPage({required this.username});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String? _authToken = '';
  final WebSocketService _webSocketService = WebSocketService.getInstance();
  bool _showInputBox = false;
  final TextEditingController _usernameController = TextEditingController();
  Color _inputBorderColor = Colors.transparent;

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
    // await _webSocketService.retrieveUnreceivedMessages();
    int userId = await getLoggedInUserId();
    if (userId != -1) {
      await _webSocketService.retrieveUnreceivedMessages(userId);
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
    return prefs.getInt('user_id') ?? -1;
  }

  void _startNewChat() async {
    String newUsername = _usernameController.text.trim();
    if (newUsername.isNotEmpty) {
      if (_authToken == '') {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        _authToken = prefs.getString('jwt_token');
      }
      final url = Uri.parse("$BASE_URL/api/user/exists?username=$newUsername");

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      bool exists = response.statusCode == 200;

      if (exists) {
        setState(() {
          _inputBorderColor = Colors.transparent; // Reset border color if valid
        });

        if (!_webSocketService.getChatUsers().containsKey(newUsername)) {
          _webSocketService.createNewChat(newUsername);
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
      } else {
        setState(() {
          _inputBorderColor = Colors.red; // Show red border on invalid username
        });
      }
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
    print(chats.length);
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
    Map<String, List<String>> chatUsers = _webSocketService.getChatUsers();
    List<String> chatKeys = chatUsers.keys.toList();

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
                          borderSide: BorderSide(
                            color: _inputBorderColor,
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: _inputBorderColor,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: _inputBorderColor,
                            width: 2,
                          ),
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
                itemCount: chatKeys.length,
                itemBuilder: (context, index) {
                  String username = chatKeys[index];
                  List<String>? chatDetails = chatUsers[username];
                  String lastMessage = chatDetails?[1] ?? "";
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
