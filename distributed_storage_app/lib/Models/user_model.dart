// lib/Models/user_model.dart
class User {
  final String userId;
  final String username;
  final String email;
  final String authToken;

  User({
    required this.userId,
    required this.username,
    required this.email,
    required this.authToken,
  });

  // Factory constructor to create a User from JSON data
  factory User.fromJson(Map<String, dynamic> json, String token) {
    return User(
      userId: json['id'].toString(),
      username: json['username'],
      email: json['email'] ?? '',
      authToken: token,
    );
  }

  // Convert user to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'email': email,
      
    };
  }
}