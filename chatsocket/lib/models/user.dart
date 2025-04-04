class User {
  final int? id; // Nullable because it will be assigned after insertion
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String jwtToken; // Store JWT token

  User({
    this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.jwtToken,
  });

  // Convert User to Map (for storing in SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'jwt_token': jwtToken,
    };
  }

  // Convert Map to User object (for reading from SQLite)
  static User fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      firstName: map['first_name'],
      lastName: map['last_name'],
      jwtToken: map['jwt_token'],
    );
  }
}
