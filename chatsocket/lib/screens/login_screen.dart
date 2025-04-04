import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'main_page.dart';
import 'package:chatsocket/constants.dart';
import 'package:chatsocket/models/user.dart';
import 'package:chatsocket/database/database_helper.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _usernameValid = true;
  bool _passwordValid = true;
  String? _errorMessage; // Stores login error message

  Future<void> _login() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();

    // Validate inputs
    setState(() {
      _usernameValid = username.isNotEmpty;
      _passwordValid = password.isNotEmpty;
      _errorMessage = null; // Reset error message on new submission
    });

    if (!_usernameValid || !_passwordValid) {
      return; // Stop execution if validation fails
    }

    // API Request: Login
    var loginUrl = Uri.parse('$BASE_URL/user/login');
    var loginResponse = await http.post(
      loginUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"username": username, "password": password}),
    );

    if (loginResponse.statusCode == 200) {
      // Parse the JWT token from the response
      String token = loginResponse.body.trim();

      // API Request: Get User Details
      var detailsUrl = Uri.parse('$BASE_URL/user/details');
      var detailsResponse = await http.get(
        detailsUrl,
        headers: {'Authorization': 'Bearer $token'}, // Attach JWT token
      );

      if (detailsResponse.statusCode == 200) {
        // Parse user details
        var userData = jsonDecode(detailsResponse.body);
        String firstName = userData['firstName'];
        String lastName = userData['lastName'];
        String email = userData['email'];

        // Check if the user exists in the local database
        User? existingUser = await DatabaseHelper.instance.getUserByUsername(
          username,
        );

        int? userId;
        if (existingUser != null) {
          // Update the existing user's JWT token
          User updatedUser = User(
            id: existingUser.id,
            username: username,
            email: email,
            firstName: firstName,
            lastName: lastName,
            jwtToken: token,
          );
          await DatabaseHelper.instance.updateUser(updatedUser);
          userId = existingUser.id; // Use existing user ID
        } else {
          // Insert new user into SQLite
          User newUser = User(
            username: username,
            email: email,
            firstName: firstName,
            lastName: lastName,
            jwtToken: token,
          );
          userId = await DatabaseHelper.instance.insertUser(newUser);
        }

        // Store the token, username, and user ID in SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('username', username);
        await prefs.setString('email', email);
        await prefs.setString('firstName', firstName);
        await prefs.setString('lastName', lastName);
        await prefs.setInt('user_id', userId ?? -1);

        // Navigate to MainPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainPage(username: username)),
        );
      } else {
        setState(() {
          _errorMessage = "Failed to fetch user details.";
        });
      }
    } else {
      setState(() {
        _errorMessage = "Login failed.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        backgroundColor: Color(0xFF1F1F1F),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),

              // Username TextField
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF121212),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _usernameController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Username',
                    hintStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Color(0xFF121212),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16.0,
                      horizontal: 16.0,
                    ),
                    errorText: _usernameValid ? null : 'Username is required',
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Password TextField
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF121212),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Color(0xFF121212),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16.0,
                      horizontal: 16.0,
                    ),
                    errorText: _passwordValid ? null : 'Password is required',
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Login Button
              ElevatedButton(
                onPressed: _login,
                child: Text('Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(
                    255,
                    18,
                    194,
                    86,
                  ), // Green background
                  foregroundColor: Colors.white, // Text color
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  minimumSize: Size(double.infinity, 56), // Full-width button
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  shadowColor: Colors.black38,
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),

              SizedBox(height: 16),

              // Register Link
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/register');
                },
                child: Text(
                  'Don\'t have an account? Register here',
                  style: TextStyle(color: Color.fromARGB(255, 18, 194, 86)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
