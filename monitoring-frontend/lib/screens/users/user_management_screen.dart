import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../widgets/search_bar.dart';
import '../../widgets/pagination.dart';
import 'user_form_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserService _userService = UserService();
  bool _isLoading = true;
  List<User> _users = [];
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(() {
      setState(() {
        _currentPage = 1;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await _userService.getUsers();
      users.sort((a, b) => a.id.compareTo(b.id));
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });

        final totalItems = _filteredUsers.length;
        final totalPages = (totalItems / _itemsPerPage).ceil();

        if (_currentPage > totalPages) {
          setState(() {
            _currentPage = totalPages > 0 ? totalPages : 1;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<User> get _filteredUsers {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _users;

    return _users.where((user) {
      final username = user.username.toLowerCase();
      final fullName = user.fullName.toLowerCase();
      return username.contains(query) || fullName.contains(query);
    }).toList();
  }

  List<User> get _paginatedUsers {
    final filtered = _filteredUsers;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage < filtered.length)
        ? startIndex + _itemsPerPage
        : filtered.length;

    if (startIndex >= filtered.length) return [];
    return filtered.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    return (_filteredUsers.length / _itemsPerPage).ceil();
  }

  Future<void> _openUserDialog({User? user}) async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UserFormDialog(user: user),
    );

    if (result == true) {
      _fetchUsers();
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete User?"),
        content: Text("Are you sure you want to delete ${user.username}?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _userService.deleteUser(user.id);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("User deleted")));
        _fetchUsers();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "User Management",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SearchBarWidget(
                    controller: _searchController,
                    hintText: "Search by username or name",
                    onClear: () => setState(() {
                      _searchController.clear();
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => _openUserDialog(),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text("Add User"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              Center(child: Text("Error: $_error"))
            else if (_filteredUsers.isEmpty)
              _buildEmptyState()
            else ...[
              _buildUserTable(),
              const SizedBox(height: 16),
              if (_filteredUsers.isNotEmpty)
                PaginationWidget(
                  currentPage: _currentPage,
                  totalPages: _totalPages > 0 ? _totalPages : 1,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildUserTable() {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                  showCheckboxColumn: false,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 48,
                  columns: const [
                    DataColumn(
                      label: Expanded(
                          child: Text("Username",
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ),
                    DataColumn(
                      label: Expanded(
                          child: Text("Full Name",
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ),
                    DataColumn(
                      label: Expanded(
                          child: Text("Email",
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ),
                    DataColumn(
                      label: Expanded(
                          child: Text("Role",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ),
                    DataColumn(
                      label: Expanded(
                          child: Text("Actions",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ),
                  ],
                  rows: _paginatedUsers.map((user) {
                    return DataRow(cells: [
                      DataCell(Text(user.username,
                          style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text(user.fullName)),
                      DataCell(Text(user.email)),
                      DataCell(Center(child: _buildRoleBadge(user.role))),
                      DataCell(Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  size: 18, color: Colors.blue),
                              onPressed: () => _openUserDialog(user: user),
                              tooltip: "Edit",
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  size: 18, color: Colors.red),
                              onPressed: () => _deleteUser(user),
                              tooltip: "Delete",
                            ),
                          ],
                        ),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role.toLowerCase()) {
      case 'admin':
        color = Colors.blue;
        break;
      case 'teknisi':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        role.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.people_outline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            isSearching
                ? "No user found matching \"${_searchController.text}\""
                : "No users found",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
