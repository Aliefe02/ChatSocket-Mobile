import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'change_password_page.dart';
import 'login_screen.dart';
import 'package:chatsocket/services/websocket_service.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Text controllers for first and last name
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();

  // Default values for user info
  String username = '';
  String email = '';
  String firstName = '';
  String lastName = '';

  @override
  void initState() {
    super.initState();
    _loadUserDetails(); // Load user details when the page is initialized
  }

  // Load user details from SharedPreferences
  _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      username = prefs.getString('username') ?? '';
      email = prefs.getString('email') ?? '';
      firstName = prefs.getString('firstName') ?? '';
      lastName = prefs.getString('lastName') ?? '';

      // Update the controllers after the data is loaded
      firstNameController.text = firstName;
      lastNameController.text = lastName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile & Settings'),
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
              // Profile picture section
              CircleAvatar(
                radius: 60,
                backgroundColor: Color.fromARGB(255, 18, 194, 86),
                child: Icon(Icons.person, color: Colors.white, size: 60),
              ),
              SizedBox(height: 24),

              // Username (non-editable)
              _buildProfileField('Username', username, false),

              // Email (non-editable)
              _buildProfileField('Email', email, false),

              // First Name (editable)
              _buildProfileField(
                'First Name',
                firstName,
                true,
                controller: firstNameController,
              ),

              // Last Name (editable)
              _buildProfileField(
                'Last Name',
                lastName,
                true,
                controller: lastNameController,
              ),

              // Change Password button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChangePasswordPage(),
                      ),
                    );
                  },
                  child: Text(
                    'Change Password',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 18, 194, 86),
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ),

              // Save button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      firstName = firstNameController.text;
                      lastName = lastNameController.text;
                    });
                  },
                  child: Text('Save', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 18, 194, 86),
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Smaller circular logout button
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: 10.0,
        ), // Moves button up slightly
        child: FloatingActionButton(
          onPressed: _logout,
          backgroundColor: Colors.red, // Red circular button
          shape: CircleBorder(),
          child: Icon(
            Icons.exit_to_app,
            color: Colors.white,
            size: 16,
          ), // Smaller icon
          mini: true, // Makes it smaller
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.startFloat, // Bottom left
    );
  }

  // Method to build profile fields
  Widget _buildProfileField(
    String label,
    String value,
    bool editable, {
    TextEditingController? controller,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: TextField(
        controller: controller ?? TextEditingController(text: value),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white),
          filled: true,
          fillColor: Colors.grey[800],
          enabled: editable,
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color.fromARGB(255, 18, 194, 86)),
            borderRadius: BorderRadius.circular(12),
          ),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  // Logout function
  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Clear stored token and user data from shared preferences
    await prefs.clear();

    // Clear in-memory chat data
    WebSocketService.getInstance().clearChats();

    // Close WebSocket connection
    WebSocketService.getInstance().disconnect();

    // Navigate to Login Page and remove all previous routes
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }
}
