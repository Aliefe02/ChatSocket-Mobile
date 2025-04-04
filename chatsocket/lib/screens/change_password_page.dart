import 'package:flutter/material.dart';

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
  void _checkPasswordMatch() {
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
                        ? () {
                          // Call your password change API here
                          // For now, let's just navigate back to the profile page
                          Navigator.pop(context);
                        }
                        : null,
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
