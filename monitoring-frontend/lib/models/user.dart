class User {
  final int userId;
  final String username;
  final String email;
  final String fullName;
  final String role;

  User({
    required this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
  });

  // API response
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'full_name': fullName,
      'role': role,
    };
  }

  // Check permissions
  bool get isAdmin => role == 'admin';
  bool get isTechnician => role == 'teknisi';
  bool get canEdit => isAdmin || isTechnician;
}
