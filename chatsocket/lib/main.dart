import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/main_page.dart';

void main() {
  runApp(ChatSocketApp());
}

class ChatSocketApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChatSocket',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF121212),
        appBarTheme: AppBarTheme(backgroundColor: Color(0xFF1F1F1F)),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/chat': (context) => ChatScreen(username: 'user'),
        '/main': (context) {
          // Retrieve the 'username' argument passed from the LoginScreen
          final String username =
              ModalRoute.of(context)!.settings.arguments as String;
          return MainPage(username: username); // Pass the username to MainPage
        },
      },
    );
  }
}
