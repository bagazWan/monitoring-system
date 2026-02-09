class User {
  final int id;
  final String username;
  final String email;
  final String fullName;
  final String role;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
  });

  // API response
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'],
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
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
