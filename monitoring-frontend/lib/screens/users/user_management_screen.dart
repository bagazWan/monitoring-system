import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/search_bar.dart';
import '../../widgets/pagination.dart';
import '../../widgets/data_table.dart';
import '../../widgets/visual_feedback.dart';
import 'user_form_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserService _userService = UserService();
  StreamSubscription<StatusChangeEvent>? _statusSubscription;
  bool _isLoading = true;
  List<User> _users = [];
  int _totalItems = 0;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _initWebSocket();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _statusSubscription?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _currentPage = 1);
      _fetchUsers();
    });
  }

  void _initWebSocket() {
    final wsService = WebSocketService();
    _statusSubscription = wsService.statusChanges.listen((event) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${event.name} is now ${event.newStatus}'),
            backgroundColor: event.newStatus.toLowerCase() == 'online'
                ? Colors.green
                : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await _userService.getUsers(
        page: _currentPage,
        limit: _itemsPerPage,
        search: _searchController.text.trim(),
      );

      page.items.sort((a, b) => a.id.compareTo(b.id));

      if (mounted) {
        setState(() {
          _users = page.items;
          _totalItems = page.total;
          _isLoading = false;
        });

        final totalPages = (_totalItems / _itemsPerPage).ceil().clamp(1, 9999);
        if (_currentPage > totalPages) {
          setState(() {
            _currentPage = totalPages;
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

  int get _totalPages => (_totalItems / _itemsPerPage).ceil().clamp(1, 9999);

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return AsyncErrorWidget(
        error: _error!,
        onRetry: _fetchUsers,
        message: 'Failed to load users',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
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
                      hintText: 'Search by username or name',
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _openUserDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? EmptyStateWidget.searching(
                  isSearching: _searchController.text.isNotEmpty,
                  searchQuery: _searchController.text,
                  label: 'users',
                  defaultIcon: Icons.people_outline,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: CustomDataTable(
                    columns: const [
                      DataColumn(
                          label: Expanded(
                              child: Text("Username",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)))),
                      DataColumn(
                          label: Expanded(
                              child: Text("Full Name",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)))),
                      DataColumn(
                          label: Expanded(
                              child: Text("Email",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)))),
                      DataColumn(
                          label: Expanded(
                              child: Text("Role",
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)))),
                      DataColumn(
                          label: Expanded(
                              child: Text("Actions",
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)))),
                    ],
                    rows: _users.map((user) {
                      return DataRow(cells: [
                        DataCell(Text(user.username,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Text(user.fullName)),
                        DataCell(Text(user.email)),
                        DataCell(Center(child: _buildRoleBadge(user.role))),
                        DataCell(Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _openUserDialog(user: user),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteUser(user.id),
                            ),
                          ],
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: PaginationWidget(
            currentPage: _currentPage,
            totalPages: _totalPages,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              _fetchUsers();
            },
          ),
        ),
      ],
    );
  }

  Future<void> _deleteUser(int userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete user"),
        content: const Text("Are you sure you want to delete this user?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _userService.deleteUser(userId);
    _fetchUsers();
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
}
