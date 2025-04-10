class User {
  final int? id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String jwtToken;
  final String publicKey;
  final String privateKey;

  User({
    this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.jwtToken,
    required this.publicKey,
    required this.privateKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'jwt_token': jwtToken,
      'public_key': publicKey,
      'private_key': privateKey,
    };
  }

  static User fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      firstName: map['first_name'],
      lastName: map['last_name'],
      jwtToken: map['jwt_token'],
      publicKey: map['public_key'],
      privateKey: map['private_key'],
    );
  }
}
