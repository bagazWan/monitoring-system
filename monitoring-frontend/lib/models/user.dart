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

  bool get isAdmin => role == 'admin';
  bool get isTechnician => role == 'teknisi';
  bool get canEdit => isAdmin || isTechnician;
}

class UserPage {
  final List<User> items;
  final int total;
  final int page;
  final int pageSize;

  UserPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory UserPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List? ?? [];
    return UserPage(
      items: raw.map((e) => User.fromJson(e)).toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 10,
    );
  }
}
