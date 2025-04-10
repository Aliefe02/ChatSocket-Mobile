import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatsocket/constants.dart';
import 'main_page.dart';
import 'package:chatsocket/models/user.dart';
import 'package:chatsocket/database/database_helper.dart';
import 'package:chatsocket/services/encryption_service.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  // Field validation states
  bool _usernameValid = true;
  bool _passwordValid = true;
  bool _emailValid = true;
  bool _firstNameValid = true;
  bool _lastNameValid = true;

  String? _errorMessage; // Stores registration error message

  Future<void> _register() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();
    String email = _emailController.text.trim();
    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();

    // Validate inputs
    setState(() {
      _usernameValid = username.isNotEmpty;
      _passwordValid = password.isNotEmpty;
      _emailValid = email.isNotEmpty;
      _firstNameValid = firstName.isNotEmpty;
      _lastNameValid = lastName.isNotEmpty;
      _errorMessage = null; // Reset error message on new submission
    });

    if (!_usernameValid ||
        !_passwordValid ||
        !_emailValid ||
        !_firstNameValid ||
        !_lastNameValid) {
      return; // Stop execution if validation fails
    }

    // API Request
    var url = Uri.parse('$BASE_URL/api/user/register');
    var response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "username": username,
        "email": email,
        "password": password,
        "firstName": firstName,
        "lastName": lastName,
      }),
    );

    if (response.statusCode == 201) {
      String token = response.body.trim();

      // 1. Generate RSA key pair
      // final keyMap = await EncryptionService().createKeys();

      // 2. Insert user into SQLite database
      User user = User(
        username: username,
        email: email,
        firstName: firstName,
        lastName: lastName,
        jwtToken: token,
        publicKey: "",
        privateKey: "",
        // publicKey: keyMap['publicKey']!,
        // privateKey: keyMap['privateKey']!,
      );
      int userId = await DatabaseHelper.instance.insertUser(user);

      // 3. Save token and user info to SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('username', username);
      await prefs.setString('email', email);
      await prefs.setString('firstName', firstName);
      await prefs.setString('lastName', lastName);
      await prefs.setInt('user_id', userId);

      // 4. Navigate to MainPage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainPage(username: username)),
      );
    } else {
      setState(() {
        _errorMessage = "Registration failed: ${response.body}";
      });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required bool isValid,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
        border: Border.all(color: isValid ? Colors.transparent : Colors.red),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Color(0xFF121212),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            vertical: 16.0,
            horizontal: 16.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register'),
        backgroundColor: Color(0xFF1F1F1F),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildTextField(
                controller: _usernameController,
                hintText: 'Username',
                isValid: _usernameValid,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                hintText: 'Password',
                isValid: _passwordValid,
                isPassword: true,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                hintText: 'Email',
                isValid: _emailValid,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _firstNameController,
                hintText: 'First Name',
                isValid: _firstNameValid,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _lastNameController,
                hintText: 'Last Name',
                isValid: _lastNameValid,
              ),
              SizedBox(height: 16),

              // Error message (if registration fails)
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Register Button
              ElevatedButton(
                onPressed: _register,
                child: Text('Register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 18, 194, 86),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  minimumSize: Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  shadowColor: Colors.black38,
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 16),

              // Login Link
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Text(
                  'Already have an account? Login here',
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
