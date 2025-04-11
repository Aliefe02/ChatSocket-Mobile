import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatsocket/constants.dart';
import 'package:chatsocket/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class ChangePasswordPage extends StatefulWidget {
  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  // Text controllers for password fields
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController reenterPasswordController =
      TextEditingController();

  // Variables to track the border color and button state
  bool isPasswordValid = true;
  bool isReenterPasswordValid = true;

  // Function to check if passwords match
  void _checkPasswordMatch() async {
    setState(() {
      if (passwordController.text == reenterPasswordController.text) {
        isPasswordValid = true;
        isReenterPasswordValid = true;
      } else {
        isPasswordValid = false;
        isReenterPasswordValid = false;
      }
    });
  }

  Future<void> _changePassword() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString('jwt_token');
    int userId = prefs.getInt('userId') ?? -1;

    // Retrieve the password values
    String newPassword = passwordController.text.trim();
    String confirmPassword = reenterPasswordController.text.trim();

    if (newPassword != confirmPassword) {
      // You can handle mismatched passwords here (e.g., show a message)
      print("Passwords do not match!");
      return;
    }

    final url = Uri.parse("$BASE_URL/api/user/update-password");

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({'password': newPassword}),
    );

    if (response.statusCode == 200) {
      String token = response.body.trim();
      DatabaseHelper.instance.updateUserJwt(token, userId);
      await prefs.setString('jwt_token', token);
      print("new token: $token");
      Navigator.pop(context);
    } else {
      // Handle error (e.g., show a failure message)
      print('Password change failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Change Password'),
        backgroundColor: Color.fromARGB(255, 18, 194, 86),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Password input field
              _buildPasswordField('Password', passwordController),
              SizedBox(height: 16), // Equal space between input fields
              // Re-enter Password input field
              _buildPasswordField(
                'Re-enter Password',
                reenterPasswordController,
              ),
              if (!isReenterPasswordValid)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Passwords do not match',
                    style: TextStyle(color: Colors.red),
                  ),
                ),

              SizedBox(
                height: 16,
              ), // Equal space between input fields and button
              // Change Password button
              ElevatedButton(
                onPressed:
                    isPasswordValid && isReenterPasswordValid
                        ? _changePassword // Call _changePassword if the passwords are valid
                        : null, // Disable the button if the passwords are invalid
                child: Text(
                  'Change Password',
                  style: TextStyle(color: Colors.white), // White text color
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 18, 194, 86),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 12.0,
                  ),
                  minimumSize: Size(double.infinity, 50), // Full width button
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to build password fields
  Widget _buildPasswordField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Consistent padding
      child: Container(
        width: double.infinity, // Make the container as wide as the screen
        child: TextField(
          controller: controller,
          obscureText: true,
          onChanged: (text) {
            // Check if passwords match whenever either password field changes
            _checkPasswordMatch();
          },
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.white),
            filled: true,
            fillColor: Colors.grey[800], // Dark background for the input box
            enabled: true,
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color:
                    isPasswordValid && isReenterPasswordValid
                        ? Color.fromARGB(255, 18, 194, 86) // Green when valid
                        : Colors.red,
              ), // Red when invalid
              borderRadius: BorderRadius.circular(12),
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide(
                color:
                    isPasswordValid && isReenterPasswordValid
                        ? Color.fromARGB(255, 18, 194, 86) // Green when valid
                        : Colors.red,
              ), // Red when invalid
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
